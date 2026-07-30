# 贡献指南

感谢你参与改进 Solidity Foundry 十天实战。本仓库面向学习场景，修改应同时保持业务语义、
技术准确性和可运行性。

## 开发环境

- Foundry 1.7.1 或兼容的新版本
- Solidity 0.8.36
- Git submodule

首次检出后执行：

```bash
git submodule update --init --recursive
forge test --force
```

## 修改原则

- 合约顶部说明业务角色、状态流转、资金归属、不变量和信任边界。
- 关键实现说明对应的 Solidity/EVM 机制，不逐行复述代码。
- 测试名称和注释表达业务场景、操作和预期结果。
- Day 5、Day 7 的故意漏洞必须保留，并明确标记为仅供本地实验。
- 不提交私钥、助记词、真实 RPC 凭证、构建产物或本地广播记录。
- 外部依赖必须固定版本；更新依赖时说明行为变化并运行全量回归。

## 提交前检查

```bash
forge fmt --check
forge lint
forge build --sizes
forge test --force
```

Pull Request 应说明修改动机、影响的课程天数、业务行为变化和验证结果。若修改了状态机或资产
逻辑，请同步更新对应 lesson、测试和不变量。

安全问题请遵循 [SECURITY.md](SECURITY.md)，不要在公开 Pull Request 中附带可直接利用的细节。
