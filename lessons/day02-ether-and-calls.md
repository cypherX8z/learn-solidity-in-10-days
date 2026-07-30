# Day 02: ETH、外部调用与 CEI

## 今日目标

- 理解 `msg.sender`、`msg.value`、合约余额和内部账本的区别。
- 掌握 Checks-Effects-Interactions，以及外部调用失败时的回滚行为。
- 为资产合约定义 accounting invariant。

## 阅读代码

- `src/day02/EtherVault.sol`
- `test/day02/EtherVault.t.sol`

```bash
forge test --match-path 'test/day02/*' -vvv
forge test --match-test test_FailedTransferRestoresAccounting -vvvv
```

`address(vault).balance` 是 EVM 余额，`accountedAssets` 是业务账本。当前设计的核心不变量是：

```text
address(vault).balance >= accountedAssets
```

这里使用 `>=`，因为 ETH 可以在不执行 `deposit` 的情况下被强制送入合约，业务逻辑不能依赖二者永远相等。

## 动手任务

1. 增加 `withdrawTo(address payable recipient, uint256 amount)`，禁止零地址。
2. 为收款方拒绝 ETH、收款方重入、余额不足分别写测试。
3. 比较 `call`、`send` 和 `transfer`，记录为什么现代代码通常使用 `call`。
4. 用 custom error 传递 `available/requested`，观察 revert data。

## 评审问题

- 状态是在外部调用前还是后更新？
- 外部调用失败时，已经扣减的账本是否恢复？
- 合约收到未记账 ETH 后，谁有权处理它？
- 账户数量增长是否会导致某个函数最终无法执行？

## 完成标准

- 能画出一次提现的完整 call tree。
- 能写出至少三个金库不变量。
- 能解释 CEI 能处理什么，不能处理哪些跨函数或跨合约重入。
