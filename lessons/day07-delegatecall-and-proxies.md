# Day 07: Delegatecall 与代理存储

## 今日目标

- 理解 delegatecall 使用谁的 code、storage、address、caller 和 value。
- 复现 storage collision，并理解 EIP-1967 slot 的用途。
- 建立“可升级性会扩大安全和运维边界”的认识。

## 阅读代码

- `src/day07/DelegatecallLab.sol`
- `test/day07/DelegatecallLab.t.sol`

```bash
forge test --match-path 'test/day07/*' -vvvv
forge inspect CounterLogic storageLayout
cast keccak 'eip1967.proxy.implementation'
```

`CollisionProxy.implementation` 和 `CounterLogic.value` 都占用 slot 0。通过代理调用
`setValue(123)` 时，逻辑代码写的是代理的 slot 0，因此 implementation 被改成 `address(123)`。

## 动手任务

1. 使用 `vm.load` 对比代理 slot 0 和 implementation slot。
2. 给 `CounterLogic` 增加一个 packed struct，预测升级前后的 layout。
3. 写一个 V2，在 slot 0 前插入变量，复现升级后的数据错读。
4. 为安全代理增加 admin 与 upgrade 函数，然后列出你刚引入的所有新风险。
5. 阅读 OpenZeppelin ERC1967Proxy/UUPSUpgradeable，比较参考实验缺少哪些检查。

## 安全提醒

本实验的两个代理都不是生产实现。EIP-1967 只隔离了特定 slot，并没有自动提供初始化保护、
升级授权、实现兼容验证、rollback、timelock 或治理流程。

## 完成标准

- 能准确说明 delegatecall 中 `address(this)` 和 `msg.sender` 的值。
- 能从 storage layout 判断一次升级是否兼容。
- 不手写生产代理，使用经过验证的实现和升级检查工具。
