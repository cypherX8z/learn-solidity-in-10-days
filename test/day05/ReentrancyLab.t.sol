// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ReentrancyAttacker, SafeBank, VulnerableBank} from "../../src/day05/ReentrancyLab.sol";
import {Test} from "forge-std/Test.sol";

contract ReentrancyLabTest is Test {
    address private victim = makeAddr("victim");
    address private attackerOperator = makeAddr("attackerOperator");

    /// @notice 攻击验收：重复兑现同一债权会抽干银行，并让受害者留下无法偿付的账面余额。
    function test_AttackerDrainsVulnerableBank() public {
        VulnerableBank bank = new VulnerableBank();
        _seed(address(bank));
        ReentrancyAttacker attacker = new ReentrancyAttacker(bank);

        vm.deal(attackerOperator, 1 ether);
        vm.prank(attackerOperator);
        // 攻击者用 1 ETH 建立合法余额，再通过 receive 重复提款 11 次。
        attacker.attack{value: 1 ether}();

        assertEq(address(bank).balance, 0);
        assertEq(address(attacker).balance, 11 ether);
        // 银行实际 ETH 已归零，但受害者的内部账本仍显示 10 ETH，形成坏账。
        assertEq(bank.balances(victim), 10 ether);
    }

    /// @notice 修复验收：先消灭债权可阻止同一攻击，受害者资产和账面余额保持完整。
    function test_ChecksEffectsInteractionsStopsSameAttack() public {
        SafeBank bank = new SafeBank();
        _seed(address(bank));
        ReentrancyAttacker attacker = new ReentrancyAttacker(bank);

        vm.deal(attackerOperator, 1 ether);
        // 重入的第二次 withdraw 因余额已清零而 revert，最终外部 call 返回 false。
        vm.expectRevert(SafeBank.TransferFailed.selector);
        vm.prank(attackerOperator);
        attacker.attack{value: 1 ether}();

        assertEq(address(bank).balance, 10 ether);
        assertEq(address(attacker).balance, 0);
        assertEq(bank.balances(victim), 10 ether);
    }

    function _seed(address bank) private {
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        // 仅知道地址时，可以手工编码函数选择器发起底层调用。
        (bool success,) = bank.call{value: 10 ether}(abi.encodeWithSignature("deposit()"));
        assertTrue(success);
    }
}
