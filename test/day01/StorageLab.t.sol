// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {StorageLab} from "../../src/day01/StorageLab.sol";
import {Test} from "forge-std/Test.sol";

contract StorageLabTest is Test {
    event BalanceSet(address indexed account, uint256 previousAmount, uint256 newAmount);

    StorageLab private lab;
    address private owner = makeAddr("owner");
    address private alice = makeAddr("alice");

    function setUp() public {
        lab = new StorageLab(owner);
    }

    /// @notice 业务验收：单笔覆盖余额后，账本、版本号和审计事件必须一致。
    function test_SetBalanceUpdatesStateAndEmitsEvent() public {
        vm.expectEmit(true, false, false, true, address(lab));
        emit BalanceSet(alice, 0, 42);

        vm.prank(owner);
        lab.setBalance(alice, 42);

        assertEq(lab.balances(alice), 42);
        assertEq(lab.sequence(), 1);
    }

    /// @notice 权限约束：非 owner 不能修改任何账户的登记余额。
    function test_RevertWhenCallerIsNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(StorageLab.NotOwner.selector, alice));
        vm.prank(alice);
        lab.setBalance(alice, 42);
    }

    /// @notice 批处理场景：同一交易可原子更新多个账户，版本号按更新项递增。
    function test_BatchSetBalances() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = makeAddr("bob");

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        vm.prank(owner);
        lab.batchSetBalances(accounts, amounts);

        assertEq(lab.balances(accounts[0]), 10);
        assertEq(lab.balances(accounts[1]), 20);
        assertEq(lab.sequence(), 2);
    }

    /// @notice 输入约束：账户和金额无法逐项对应时，整批业务请求必须拒绝。
    function test_RevertWhenBatchLengthsDiffer() public {
        address[] memory accounts = new address[](1);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(StorageLab.LengthMismatch.selector);
        vm.prank(owner);
        lab.batchSetBalances(accounts, amounts);
    }

    /// @notice 技术验收：业务字段必须落在预期槽位，mapping 值可由规则定位。
    function test_StorageLayoutForValueAndMapping() public {
        vm.prank(owner);
        lab.setBalance(alice, 123);

        // vm.load 可以直接读取合约的原始 storage slot；slot 0 保存 sequence。
        assertEq(uint256(vm.load(address(lab), bytes32(uint256(0)))), 1);

        // address 只占 20 字节，从 bytes32 槽值转换时保留低 160 位。
        bytes32 rawOwner = vm.load(address(lab), bytes32(uint256(1)));
        assertEq(address(uint160(uint256(rawOwner))), owner);

        // mapping 的值位于 keccak256(abi.encode(key, mappingSlot))。
        bytes32 balanceSlot = keccak256(abi.encode(alice, uint256(2)));
        assertEq(uint256(vm.load(address(lab), balanceSlot)), 123);
    }

    /// @notice 集成验收：链下系统按 ABI 编码的请求能调用正确业务函数。
    function test_AbiEncodedCallUsesExpectedSelector() public {
        bytes memory callData = abi.encodeCall(StorageLab.setBalance, (alice, 77));
        // ABI 编码的函数调用总是以 4 字节 selector 开头。
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(bytes4(callData), StorageLab.setBalance.selector);

        vm.prank(owner);
        (bool success,) = address(lab).call(callData);

        assertTrue(success);
        assertEq(lab.balances(alice), 77);
    }

    /// @notice 输入性质：owner 可把任意 uint256 值作为新的登记余额。
    function testFuzz_SetBalance(uint256 amount) public {
        vm.prank(owner);
        lab.setBalance(alice, amount);

        assertEq(lab.balances(alice), amount);
    }
}
