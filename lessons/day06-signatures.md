# Day 06: EIP-712 与签名授权

## 今日目标

- 区分交易签名、任意消息签名和 typed-data 签名。
- 使用 domain separator 将签名绑定到 chain、contract、name 和 version。
- 使用 recipient、nonce、amount、deadline 限定授权边界。

## 阅读代码

- `src/day06/SignedClaims.sol`
- `test/day06/SignedClaims.t.sol`
- `lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol`
- `lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol`

```bash
forge test --match-path 'test/day06/*' -vvv
forge test --match-test test_RevertWhenSignatureComesFromAnotherChain -vvvv
```

签名不是权限本身，它只是对一组字节的授权证明。安全性取决于这组字节是否包含完整上下文。

```text
Claim(recipient, amount, nonce, deadline)
  + EIP712Domain(name, version, chainId, verifyingContract)
```

## 动手任务

1. 删除 `nonce` 后写出 replay exploit，再恢复 nonce。
2. 删除 domain 中的 chain/contract 绑定，演示跨部署重放。
3. 增加 signer 主动取消某个 recipient nonce 的机制。
4. 将 ETH claim 改为 `SafeERC20` 支付，覆盖 fee-on-transfer Token 的决策。
5. 让 ERC-1271 合约钱包也能作为 signer，使用 `SignatureChecker`。

## 评审问题

- 谁可以提交签名？relayer 是否应该影响授权结果？
- nonce 是全局、按用户还是 bitmap？并发签名会如何互相失效？
- deadline 使用秒还是区块？允许多大时间偏差？
- signer 轮换后，旧签名如何处理？

## 完成标准

- 能手工列出 digest 的每一层 hash。
- replay、过期、错误 signer、错误 chain 均有独立测试。
- 私钥只存在于 Foundry 测试上下文，不写入仓库配置。
