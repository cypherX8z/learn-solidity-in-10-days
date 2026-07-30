// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @title EtherVault
/// @notice 一个最小化的 ETH 金库，用来学习 payable、receive 和底层 call。
/// @dev 这里的 balances 是内部账本，合约真实余额则是 address(this).balance。
///
/// 业务场景：用户自助存取 ETH 的托管账户。
/// - 存款永远记到实际付款人 msg.sender 名下，不支持代他人充值。
/// - 用户只能提取自己的已记账余额，没有管理员代扣或冻结功能。
/// - 每次成功存取都必须同步更新个人余额和 accountedAssets 总负债。
/// - 核心偿付能力不变量：address(this).balance >= accountedAssets。
/// - 强制转入的未记账 ETH 不属于任何用户；本示例故意不提供管理或提取规则。
contract EtherVault {
    // 自定义错误比 revert("字符串") 更节省部署和执行 gas，并且可以携带结构化参数。
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 requested);
    error TransferFailed();

    // indexed 参数会进入日志 topic，链下程序可以按 account 高效过滤。
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    // public mapping 会由编译器自动生成 balances(address) getter。
    mapping(address account => uint256 amount) public balances;
    // 记录通过 deposit/receive 入账的 ETH，不一定等于合约真实余额。
    // 例如其他合约可通过 selfdestruct 强制向本合约发送 ETH。
    uint256 public accountedAssets;

    /// @notice 调用函数并随交易发送 ETH。
    /// @dev payable 表示该函数允许 msg.value 大于零。
    /// 业务规则：零金额不构成有效存款，成功后资金立即计入调用者可提余额。
    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice 提取调用者账本中的部分 ETH。
    /// @dev 业务规则：提取金额必须大于零且不能超过调用者余额。
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(available, amount);

        // Checks-Effects-Interactions：先检查，再更新状态，最后调用外部地址。
        // 外部调用可能触发接收方代码，因此状态必须先更新以降低重入风险。
        balances[msg.sender] = available - amount;
        accountedAssets -= amount;

        // call 是目前发送 ETH 的常用方式；返回 false 时需要显式回滚。
        // 若此处 revert，上面的状态修改也会被 EVM 原子性地恢复。
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice 直接向合约地址发送 ETH 且 calldata 为空时，EVM 会进入 receive。
    /// @dev 业务效果与 deposit 完全相同，付款人获得等额可提余额。
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    // private 函数只能在当前合约内部调用；它复用了两种入金入口的逻辑。
    function _deposit(address account, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();
        balances[account] += amount;
        accountedAssets += amount;
        emit Deposited(account, amount);
    }
}
