# Day 03: 状态机与 Foundry 测试

## 今日目标

- 使用 `prank`、`deal`、`warp`、`expectEmit` 和 `expectRevert`。
- 将业务生命周期建模为显式状态机。
- 区分 example-based、Fuzz 和 Invariant 测试。

## 阅读代码

- `src/day03/DeadlineEscrow.sol`
- `test/day03/DeadlineEscrow.t.sol`
- `test/day03/EtherVault.invariant.t.sol`

```bash
forge test --match-path 'test/day03/DeadlineEscrow.t.sol' -vvv
forge test --match-contract EtherVaultInvariantTest -vv
```

注意 `vm.prank` 只影响下一次外部调用。如果函数参数中先执行了另一个合约 getter，prank
会被该 getter 消耗。需要提前读取参数，或使用 `startPrank/stopPrank`。

## 测试选择

| 测试 | 擅长发现的问题 |
| --- | --- |
| Unit | 已知分支、权限、事件、精确错误 |
| Fuzz | 单次调用的输入边界与算术性质 |
| Invariant | 多账户、多步骤、长状态序列中的系统性质 |
| Fork | 与已部署协议和真实链状态的兼容性 |

## 动手任务

1. 给 Escrow 增加“未出资且过期后取消”的终态。
2. Fuzz `price` 和 `deadline`，避免测试只覆盖整齐的 ether 数值。
3. 给 EtherVault Handler 增加直接转账路径。
4. 增加 invariant：三个已知 actor 的账本余额之和等于 `accountedAssets`。
5. 临时交换 Escrow 的 effect/interaction 顺序，观察哪些测试能发现风险。

## 完成标准

- 每个状态转换都有成功、越权、错误状态三类测试。
- Invariant campaign 不产生无意义的大量 revert。
- 失败时能使用 `-vvvv` 定位到具体 call 和 storage change。
