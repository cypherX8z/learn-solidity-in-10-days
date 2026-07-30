// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @notice 逻辑合约：代码在这里，但通过代理调用时数据写入代理的 storage。
/// @dev 业务视角：代理模式让用户持续访问同一地址，同时由该地址转发到业务逻辑代码。
contract CounterLogic {
    // 逻辑合约预期 value 在 slot 0、lastCaller 在 slot 1。
    uint256 public value;
    address public lastCaller;

    function setValue(uint256 newValue) external {
        value = newValue;
        lastCaller = msg.sender;
    }
}

/// @notice 故意存在 storage collision 的错误代理，仅供学习。
/// @dev implementation 与 CounterLogic.value 都占用 slot 0。
///
/// 业务风险：用户调用看似普通的 setValue，就会破坏代理的实现地址，导致后续业务调用
/// 被转发到错误地址。一次布局错误即可同时造成数据损坏和服务不可用。
contract CollisionProxy {
    address public implementation;

    constructor(address implementation_) {
        implementation = implementation_;
    }

    /// @notice 未匹配任何函数选择器时，把调用委托给 implementation。
    fallback() external payable {
        _delegate(implementation);
    }

    /// @notice calldata 为空的纯 ETH 转账会进入 receive，并继续委托。
    receive() external payable {
        _delegate(implementation);
    }

    // delegatecall 的关键语义：执行 implementation 的代码，但保留代理的
    // address(this)、storage、msg.sender 和 msg.value。
    function _delegate(address implementation_) private {
        assembly {
            // 把完整 calldata 复制到 memory[0..calldatasize)。
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            // 把实现合约返回的数据复制回来，并原样 return 或 revert。
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @notice 把实现地址放入 EIP-1967 约定的独立槽位，避免与业务状态碰撞。
/// @dev 这是教学用最小代理，没有升级权限、初始化保护等生产功能。
///
/// 业务边界：隔离存储槽只解决“地址放在哪里”，并没有定义谁能升级、何时升级、
/// 新实现是否兼容以及用户如何获知变更；这些都属于真实可升级系统的治理规则。
contract IsolatedSlotProxy {
    error InvalidImplementation();

    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    // 该伪随机高位槽几乎不可能与按顺序分配的普通状态变量重合。
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address implementation_) {
        // address.code.length 用于拒绝 EOA 和尚未部署代码的地址。
        if (implementation_.code.length == 0) revert InvalidImplementation();
        assembly {
            // assembly 可直接读写任意 storage slot；使用时必须格外谨慎。
            sstore(IMPLEMENTATION_SLOT, implementation_)
        }
    }

    /// @notice 从 EIP-1967 槽读取当前实现地址。
    function implementation() public view returns (address implementation_) {
        assembly {
            implementation_ := sload(IMPLEMENTATION_SLOT)
        }
    }

    fallback() external payable {
        _delegate(implementation());
    }

    receive() external payable {
        _delegate(implementation());
    }

    function _delegate(address implementation_) private {
        assembly {
            // 这是 Solidity 代理常见的“透明转发”模板：复制输入、delegatecall、复制输出。
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
