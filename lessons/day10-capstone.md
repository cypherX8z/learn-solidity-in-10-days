# Day 10: MilestoneEscrow 毕业项目

第 10 天刻意只提供 `src/day10/IMilestoneEscrow.sol`，不提供实现。目标是独立完成设计、
威胁建模、实现、测试和本地部署，而不是照抄答案。

## 业务需求

- client、contractor、arbiter 三个角色必须互不相同且非零地址。
- 构造时传入 2-10 个 milestone；每项包含 amount 和 deadline。
- client 必须一次性存入所有 milestone 金额之和。
- client 批准 milestone 后，contractor 才能 claim，且每项最多支付一次。
- client 或 contractor 可以对未支付 milestone 发起 dispute。
- arbiter 可以决定支付 contractor 或将该项退回 client。
- 到期且未批准、未争议的金额可以由 client refund。
- 所有资产转移遵循 CEI；终态不能被重新打开。

你可以扩展接口，但需要在 README/威胁模型中记录理由。

## 必须定义的不变量

```text
totalReleased <= totalDeposited
totalRefunded <= totalDeposited
totalReleased + totalRefunded <= totalDeposited
contract balance + totalReleased + totalRefunded >= totalDeposited
每个 milestone 最多支付或退款一次
Completed/Refunded 终态不可逆
```

最后一个 solvency 关系使用 `>=` 处理强制转入的 ETH。实现时根据你的记账模型进一步收紧。

## 最低测试矩阵

### Unit

- 构造参数与 milestone 总额校验
- 正常 fund -> approve -> claim
- 每个函数的越权调用
- 重复批准、重复 claim、错误 index
- deadline 边界：`deadline - 1`、`deadline`、`deadline + 1`
- dispute 双向裁决
- 收款方拒绝 ETH 时的状态回滚

### Fuzz

- milestone 数量、金额、deadline
- 任意顺序批准，但只能按你的业务规则结算
- 所有金额计算不溢出，零金额策略明确

### Invariant

- Handler 至少模拟 client、contractor、arbiter 和一个攻击账户。
- 随机执行 approve、claim、dispute、resolve、refund 和时间推进。
- 每轮验证上面的 accounting 与 terminal-state invariants。

### Attack

- contractor 收款回调重入 claim
- arbiter 权限伪造
- 重复 dispute/resolve
- 强制转入 ETH 后的 accounting
- 超大 milestone 数量造成 gas DoS

## 交付物

```text
src/day10/MilestoneEscrow.sol
test/day10/MilestoneEscrow.t.sol
test/day10/MilestoneEscrow.invariant.t.sol
script/DeployMilestoneEscrow.s.sol
lessons/day10-threat-model.md
```

## 验收命令

```bash
forge fmt --check
forge build --sizes
forge test --match-path 'test/day10/*' -vvvv
forge test
forge coverage --report summary
```

## 完成标准

- 所有状态转换能由图或表完整描述。
- 测试验证系统性质，而不只是逐函数 happy path。
- 部署脚本拒绝无效配置，部署后 smoke test 权限和总额。
- 使用 [威胁模型模板](threat-model-template.md)记录剩余风险。
