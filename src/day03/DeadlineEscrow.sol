// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @title DeadlineEscrow
/// @notice 一个带截止时间和仲裁人的托管合约，用来学习状态机与时间相关测试。
/// @dev 状态只允许 Created -> Funded -> Released/Refunded，不存在反向迁移。
///
/// 业务场景：买卖双方进行一次固定价格交易，由独立仲裁人处理争议。
/// - buyer 必须在 deadline 前一次性支付 price，不接受分期或超额付款。
/// - buyer 验收后主动 release，全部价款支付给 seller。
/// - 到期后 buyer 可退款；arbiter 则可在 Funded 状态随时裁决任一方向。
/// - seller 无权自行提款，避免其绕过买方验收或仲裁。
/// - price 只能结算一次，Released/Refunded 都是不可逆终态。
contract DeadlineEscrow {
    // enum 在 ABI 中表现为 uint8；第一个成员 Created 的底层值为 0，也是默认值。
    enum State {
        Created,
        Funded,
        Released,
        Refunded
    }

    error InvalidConfiguration();
    error Unauthorized(address caller);
    error InvalidState(State expected, State actual);
    error FundingWindowClosed(uint256 deadline);
    error DeadlineNotReached(uint256 deadline);
    error IncorrectFunding(uint256 expected, uint256 supplied);
    error TransferFailed();

    event Funded(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount, address indexed authorizedBy);
    event Refunded(address indexed buyer, uint256 amount, address indexed authorizedBy);

    // immutable 只能在声明处或构造函数中赋值，部署后不可再变更。
    // 它的读取成本通常低于普通 storage 变量。
    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public immutable price;
    uint256 public immutable deadline;
    State public state;

    /// @notice 部署时一次性确定参与者、价格和截止时间。
    /// @dev 三个参与者必须是互不相同的非零地址，价格必须大于零。
    constructor(
        address buyer_,
        address seller_,
        address arbiter_,
        uint256 price_,
        uint256 deadline_
    ) {
        // 区块时间戳可能被出块者小幅调整；本例按“天”计时，可以接受这种误差。
        // forge-lint: disable-next-line(block-timestamp)
        bool deadlineInvalid = deadline_ <= block.timestamp;
        if (
            buyer_ == address(0) || seller_ == address(0) || arbiter_ == address(0)
                || buyer_ == seller_ || buyer_ == arbiter_ || seller_ == arbiter_ || price_ == 0
                || deadlineInvalid
        ) {
            revert InvalidConfiguration();
        }

        buyer = buyer_;
        seller = seller_;
        arbiter = arbiter_;
        price = price_;
        deadline = deadline_;
    }

    /// @notice 仅买方可在截止时间前一次性存入约定价格。
    /// @dev 业务状态从 Created 迁移到 Funded。
    function fund() external payable {
        if (msg.sender != buyer) revert Unauthorized(msg.sender);
        _requireState(State.Created);
        // 区块时间戳只适合粗粒度期限，不应作为高精度时钟或随机数来源。
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > deadline) revert FundingWindowClosed(deadline);
        if (msg.value != price) revert IncorrectFunding(price, msg.value);

        state = State.Funded;
        emit Funded(msg.sender, msg.value);
    }

    /// @notice 买方确认交付后，把托管款释放给卖方。
    /// @dev 业务状态从 Funded 迁移到 Released；本设计允许截止时间后继续验收。
    function release() external {
        if (msg.sender != buyer) revert Unauthorized(msg.sender);
        _settle(true);
    }

    /// @notice 截止时间过后，买方可主动取回托管款。
    /// @dev 业务状态从 Funded 迁移到 Refunded。
    function refundAfterDeadline() external {
        if (msg.sender != buyer) revert Unauthorized(msg.sender);
        // 测试中会用 vm.warp 修改 block.timestamp 来覆盖这个分支。
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp <= deadline) revert DeadlineNotReached(deadline);
        _settle(false);
    }

    /// @notice 仲裁人可以决定把钱给卖方还是退给买方。
    /// @dev releaseToSeller=true 表示支持卖方，否则支持买方；只能裁决一次。
    function resolve(bool releaseToSeller) external {
        if (msg.sender != arbiter) revert Unauthorized(msg.sender);
        _settle(releaseToSeller);
    }

    // 将两个结算入口汇聚到同一实现，避免状态迁移和转账逻辑重复。
    function _settle(bool releaseToSeller) private {
        _requireState(State.Funded);

        // 先确定终态并写入 storage，再向收款人执行外部调用。
        address payable recipient;
        if (releaseToSeller) {
            state = State.Released;
            recipient = payable(seller);
        } else {
            state = State.Refunded;
            recipient = payable(buyer);
        }

        // 转账失败会回滚整个交易，包括刚写入的 state。
        (bool success,) = recipient.call{value: price}("");
        if (!success) revert TransferFailed();

        if (releaseToSeller) {
            emit Released(seller, price, msg.sender);
        } else {
            emit Refunded(buyer, price, msg.sender);
        }
    }

    // 状态校验集中在一个辅助函数中，让错误参数始终保持一致。
    function _requireState(State expected) private view {
        if (state != expected) revert InvalidState(expected, state);
    }
}
