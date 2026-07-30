// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {LabAsset, TrainingVault} from "../../src/day08/TrainingVault.sol";
import {Test} from "forge-std/Test.sol";

contract TrainingVaultTest is Test {
    LabAsset private asset;
    TrainingVault private vault;
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private yieldSource = makeAddr("yieldSource");

    function setUp() public {
        asset = new LabAsset();
        vault = new TrainingVault(asset);
    }

    /// @notice 首存场景：空金库中存入 LAB，应获得近似一比一的初始份额。
    function test_FirstDepositMintsOneToOneShares() public {
        _mintAndApprove(alice, 100 ether);

        vm.prank(alice);
        // deposit 的第一个参数是资产数量，第二个参数是份额接收者。
        uint256 shares = vault.deposit(100 ether, alice);

        assertEq(shares, 100 ether);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), 100 ether);
    }

    /// @notice 收益归属：金库新增资产应由现有份额持有人按比例享有。
    function test_ExistingSharesAccrueDonatedYield() public {
        _mintAndApprove(alice, 100 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(100 ether, alice);

        // 直接给金库转入资产会提高每份 share 对应的资产价值。
        asset.mint(yieldSource, 20 ether);
        vm.prank(yieldSource);
        assertTrue(asset.transfer(address(vault), 20 ether));

        // preview 函数只计算预期结果，不修改状态。
        uint256 expectedAssets = vault.previewRedeem(shares);
        assertGt(expectedAssets, 100 ether);

        vm.prank(alice);
        uint256 redeemedAssets = vault.redeem(shares, alice, alice);

        assertEq(redeemedAssets, expectedAssets);
        assertEq(asset.balanceOf(alice), expectedAssets);
    }

    /// @notice 公平定价：已有收益后，新存款人不能按旧汇率获得过多份额。
    function test_LateDepositorReceivesFewerSharesAfterYield() public {
        _mintAndApprove(alice, 100 ether);
        vm.prank(alice);
        vault.deposit(100 ether, alice);

        asset.mint(yieldSource, 20 ether);
        vm.prank(yieldSource);
        assertTrue(asset.transfer(address(vault), 20 ether));

        _mintAndApprove(bob, 100 ether);
        // 金库已有收益后，100 LAB 对应的份额会少于初始的 100 tvLAB。
        uint256 expectedShares = vault.previewDeposit(100 ether);
        vm.prank(bob);
        uint256 actualShares = vault.deposit(100 ether, bob);

        assertEq(actualShares, expectedShares);
        assertLt(actualShares, 100 ether);
    }

    /// @notice 空仓往返：任意有效首存金额立即全部赎回后，用户资产不应损失。
    function testFuzz_EmptyVaultRoundTrip(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 1_000_000 ether);
        _mintAndApprove(alice, amount);

        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        uint256 redeemedAssets = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(redeemedAssets, amount);
        assertEq(asset.balanceOf(alice), amount);
    }

    function _mintAndApprove(address account, uint256 amount) private {
        asset.mint(account, amount);
        // ERC20 的 transferFrom 模式要求资产持有人先授权金库支出。
        vm.prank(account);
        asset.approve(address(vault), amount);
    }
}
