# Day 05: 重入攻击实验

## 今日目标

- 亲手运行一次可获利的重入攻击。
- 从调用栈而不是从代码行理解重入。
- 比较 CEI、ReentrancyGuard 和 pull-payment 的适用边界。

## 阅读代码

- `src/day05/ReentrancyLab.sol`
- `test/day05/ReentrancyLab.t.sol`

`VulnerableBank` 和 `ReentrancyAttacker` 是故意不安全的教学代码，禁止部署。

```bash
forge test \
  --match-test test_AttackerDrainsVulnerableBank \
  -vvvv
```

在 trace 中找到以下循环：

```text
Bank.withdraw -> Attacker.receive -> Bank.withdraw -> ...
```

Bank 在每次外部调用前仍看到攻击者的旧余额，因此同一份债权被重复支付。

## 动手任务

1. 只调整一行状态更新顺序，使攻击失败，并解释事务为什么整体回滚。
2. 用 OpenZeppelin `ReentrancyGuard` 实现第三个版本，比较 gas 和可组合性。
3. 设计两个函数共享同一余额的 cross-function reentrancy 示例。
4. 让攻击者捕获内层失败，使安全 Bank 仍能正常退回攻击者自己的本金。
5. 写出不依赖具体攻击步骤的 solvency invariant。

## 审计清单

- 所有 ETH/ERC-20/ERC-721 回调点在哪里？
- 外部调用前哪些状态仍可被重复消费？
- read-only reentrancy 是否能观察到临时不一致状态？
- guard 是覆盖单函数，还是覆盖整个共享状态域？

## 完成标准

- 能逐层解释攻击 trace 中每次余额为何仍非零。
- 能说明为什么“只给可信合约调用”不是充分防御。
- 修复后攻击测试失败，同时正常提现测试继续通过。
