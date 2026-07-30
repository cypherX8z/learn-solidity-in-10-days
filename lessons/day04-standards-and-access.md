# Day 04: 标准合约与权限

## 今日目标

- 阅读 ERC-20 接口和 OpenZeppelin 实现，而不是手写生产 Token。
- 理解 role admin、授权委派、撤销和最小权限原则。
- 识别 supply cap 与 mint 权限之间的独立约束。

## 阅读代码

- `src/day04/TrainingToken.sol`
- `test/day04/TrainingToken.t.sol`
- `lib/openzeppelin-contracts/contracts/access/AccessControl.sol`
- `lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol`

```bash
forge test --match-path 'test/day04/*' -vvv
forge inspect TrainingToken methodIdentifiers
forge inspect TrainingToken storageLayout
```

## 动手任务

1. 将默认管理员和初始 minter 拆成两个构造参数。
2. 增加独立的 `BURNER_ROLE`，只允许销毁调用者自己的 Token 是否还需要 role？先写出决策理由。
3. 演练 grant、revoke、renounce 三条权限路径并验证事件。
4. 增加 `ERC20Pausable`，明确谁能暂停、谁能恢复，以及暂停覆盖哪些操作。
5. 阅读 OpenZeppelin changelog，记录升级依赖版本前需要检查的行为变化。

## 安全提醒

- `DEFAULT_ADMIN_ROLE` 默认也是自己的管理员，泄露后可授予任意 role。
- cap 只限制总供应量，不限制单次 mint，也不等价于发行计划。
- 标准兼容不代表业务安全；权限、预言机和经济模型仍需独立评审。

## 完成标准

- 能解释 `onlyRole` 的完整检查路径和错误数据。
- 能列出管理员私钥失陷后的影响面。
- 不通过复制标准源码来“定制”生产合约。
