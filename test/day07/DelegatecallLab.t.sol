// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {CollisionProxy, CounterLogic, IsolatedSlotProxy} from "../../src/day07/DelegatecallLab.sol";
import {Test} from "forge-std/Test.sol";

contract DelegatecallLabTest is Test {
    // 与代理源码相同的 EIP-1967 slot，用于直接读取 storage 验证布局。
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    CounterLogic private logic;
    address private alice = makeAddr("alice");

    function setUp() public {
        logic = new CounterLogic();
    }

    /// @notice 正常代理：业务数据写入代理，同时保留真实用户作为 lastCaller。
    function test_DelegatecallUsesProxyStorageAndPreservesCaller() public {
        IsolatedSlotProxy proxy = new IsolatedSlotProxy(address(logic));
        // 地址仍是 proxy，但用逻辑合约类型转换后，Solidity 会按 CounterLogic ABI 编码调用。
        CounterLogic proxiedCounter = CounterLogic(address(proxy));

        vm.prank(alice);
        proxiedCounter.setValue(42);

        assertEq(proxiedCounter.value(), 42);
        assertEq(proxiedCounter.lastCaller(), alice);
        assertEq(proxy.implementation(), address(logic));
        // vm.load 可直接读取任意合约的原始 storage slot。
        assertEq(
            address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))), address(logic)
        );
    }

    /// @notice 故障场景：业务写操作覆盖实现地址后，代理失去正常服务能力。
    function test_CollisionOverwritesImplementationAddress() public {
        CollisionProxy proxy = new CollisionProxy(address(logic));
        CounterLogic proxiedCounter = CounterLogic(address(proxy));

        // setValue 写逻辑上的 slot 0，实际覆盖代理 slot 0 中的 implementation。
        proxiedCounter.setValue(123);

        assertEq(proxy.implementation(), address(123));

        (bool success, bytes memory returnData) =
            address(proxy).staticcall(abi.encodeWithSignature("value()"));
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    /// @notice 部署约束：代理不能把没有代码的 EOA 设为业务实现。
    function test_RevertWhenImplementationHasNoCode() public {
        vm.expectRevert(IsolatedSlotProxy.InvalidImplementation.selector);
        new IsolatedSlotProxy(address(123));
    }
}
