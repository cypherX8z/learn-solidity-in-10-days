// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @title StorageLab
/// @notice 把 Solidity 常规语法与具体的 EVM storage、ABI 行为联系起来。
///
/// 业务场景：owner 维护一份外部账户到业务余额的登记表。
/// - 只有 owner 可以写入，任何人都可以读取公开账本。
/// - setBalance 是覆盖旧值，不是充值或扣款；事件同时记录新旧值用于链下审计。
/// - sequence 是全局变更版本号，每成功更新一个账户就加一。
/// - 单次批量最多处理 50 个账户，避免交易因规模失控而耗尽 gas。
contract StorageLab {
    // error 以带类型的 ABI 数据描述失败场景。
    error InvalidOwner();
    error NotOwner(address caller);
    error LengthMismatch();
    error BatchTooLarge(uint256 supplied, uint256 maximum);

    // indexed account 会进入事件 topic；两个 amount 参数保留在事件 data 中。
    event BalanceSet(address indexed account, uint256 previousAmount, uint256 newAmount);

    // 以下三个声明依次使用 storage slot 0、1、2；mapping 的值存放在哈希槽中。
    uint256 public sequence;
    address public owner;
    mapping(address account => uint256 amount) public balances;

    // constant 嵌入字节码，不占用 storage slot。
    uint256 public constant MAX_BATCH_SIZE = 50;

    /// @param owner_ 初始状态下唯一允许更新余额的账户。
    constructor(address owner_) {
        if (owner_ == address(0)) revert InvalidOwner();
        owner = owner_;
    }

    // msg.sender 是当前直接调用者，既可能是 EOA，也可能是另一个合约。
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    /// @notice owner 覆盖一个账户的登记余额。
    function setBalance(address account, uint256 amount) external onlyOwner {
        _setBalance(account, amount);
    }

    /// @notice owner 在同一交易内批量覆盖多个账户余额。
    /// @dev accounts[i] 必须对应 amounts[i]；任意一项失败会回滚整批操作。
    function batchSetBalances(address[] calldata accounts, uint256[] calldata amounts)
        external
        onlyOwner
    {
        // 缓存 calldata 数组长度，避免每轮循环重复读取。
        uint256 length = accounts.length;
        if (length != amounts.length) revert LengthMismatch();

        // 写 storage 的循环必须限制规模，因为每笔交易都有 gas 上限。
        if (length > MAX_BATCH_SIZE) revert BatchTooLarge(length, MAX_BATCH_SIZE);

        for (uint256 i; i < length; ++i) {
            _setBalance(accounts[i], amounts[i]);
        }
    }

    // private 只限制 Solidity 层面的访问，不代表数据在公开链上保密。
    function _setBalance(address account, uint256 amount) private {
        uint256 previousAmount = balances[account];
        balances[account] = amount;

        // Solidity 0.8+ 在 uint256 加法溢出时会自动 revert。
        ++sequence;
        emit BalanceSet(account, previousAmount, amount);
    }
}
