// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {EtherVault} from "../../src/day02/EtherVault.sol";
import {Test} from "forge-std/Test.sol";

/// @notice 模拟拒绝接收 ETH 的合约，用于覆盖底层 call 返回 false 的路径。
contract RejectingDepositor {
    EtherVault private immutable vault;

    constructor(EtherVault vault_) {
        vault = vault_;
    }

    function withdraw(uint256 amount) external {
        vault.withdraw(amount);
    }

    receive() external payable {
        revert("reject ether");
    }
}

contract EtherVaultTest is Test {
    // 测试中重复声明事件，便于用 vm.expectEmit 校验目标合约发出的日志。
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    EtherVault private vault;
    address private alice = makeAddr("alice");

    function setUp() public {
        vault = new EtherVault();
        // vm.deal 直接设置地址的 ETH 余额，仅影响本地测试状态。
        vm.deal(alice, 100 ether);
    }

    /// @notice 业务验收：用户存入 3 ETH、提取 1 ETH 后，资产和负债都应剩余 2 ETH。
    function test_DepositAndWithdraw() public {
        // 四个 bool 依次控制 topic1、topic2、topic3、data 是否需要匹配。
        vm.expectEmit(true, false, false, true, address(vault));
        emit Deposited(alice, 3 ether);
        vm.prank(alice);
        vault.deposit{value: 3 ether}();

        assertEq(vault.balances(alice), 3 ether);
        assertEq(vault.accountedAssets(), 3 ether);

        vm.expectEmit(true, false, false, true, address(vault));
        emit Withdrawn(alice, 1 ether);
        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(vault.balances(alice), 2 ether);
        assertEq(vault.accountedAssets(), 2 ether);
        assertEq(address(vault).balance, 2 ether);
    }

    /// @notice 入口兼容：直接转账与调用 deposit 具有相同入账效果。
    function test_PlainEtherTransferIsCredited() public {
        // 空 calldata 的底层 call 会命中 EtherVault.receive()。
        vm.prank(alice);
        (bool success,) = address(vault).call{value: 2 ether}("");

        assertTrue(success);
        assertEq(vault.balances(alice), 2 ether);
    }

    /// @notice 偿付约束：用户不能提取超过自己账面余额的资金。
    function test_RevertWhenBalanceIsInsufficient() public {
        vm.expectRevert(abi.encodeWithSelector(EtherVault.InsufficientBalance.selector, 0, 1 ether));
        vm.prank(alice);
        vault.withdraw(1 ether);
    }

    /// @notice 原子性要求：收款失败时，本次提款的所有账务修改必须恢复。
    function test_FailedTransferRestoresAccounting() public {
        RejectingDepositor rejector = new RejectingDepositor(vault);
        vm.deal(address(rejector), 1 ether);

        vm.prank(address(rejector));
        vault.deposit{value: 1 ether}();

        // 整笔调用回滚，所以 withdraw 中提前扣减的账本也会恢复。
        vm.expectRevert(EtherVault.TransferFailed.selector);
        rejector.withdraw(1 ether);

        assertEq(vault.balances(address(rejector)), 1 ether);
        assertEq(vault.accountedAssets(), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    /// @notice 资金守恒：任意有效金额完整存入再取出后，用户和总账均归零。
    function testFuzz_DepositThenWithdraw(uint96 rawAmount) public {
        // Foundry 为 rawAmount 生成大量输入；bound 将其限制在有效资金范围。
        uint256 amount = bound(uint256(rawAmount), 1, 100 ether);
        vm.deal(alice, amount);

        vm.startPrank(alice);
        vault.deposit{value: amount}();
        vault.withdraw(amount);
        vm.stopPrank();

        assertEq(vault.balances(alice), 0);
        assertEq(vault.accountedAssets(), 0);
        assertEq(address(vault).balance, 0);
    }
}
