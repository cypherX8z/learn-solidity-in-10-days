# Solidity Foundry 十天实战

[![CI](https://github.com/cypherX8z/solidity-foundry-10-day-lab/actions/workflows/test.yml/badge.svg)](https://github.com/cypherX8z/solidity-foundry-10-day-lab/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

一个面向资深后端开发者的 Solidity、EVM 与 Foundry 中文实战课程。通过 10 天递进式实验，
建立智能合约执行模型、业务建模能力、资产安全意识、测试方法和可部署的工程工作流。

所有核心示例均包含中文业务注释和技术注释，可以直接运行、修改和观察调用 trace。

## 环境基线

- Foundry 1.7.1
- Solidity 0.8.36
- EVM target: Prague
- OpenZeppelin Contracts 5.6.1
- 每天建议投入 2-4 小时

## 快速验证

```bash
forge --version
forge fmt --check
forge lint
forge build
forge test --force -vv
```

首次克隆仓库时需要恢复依赖：

```bash
git submodule update --init --recursive
forge install
```

## 课程地图

| 天数 | 主题 | 核心产物 |
| --- | --- | --- |
| 01 | [Solidity 语法、storage 与 ABI](lessons/day01-evm-storage-abi.md) | 类型、数据位置、slot、calldata |
| 02 | [ETH、外部调用与 CEI](lessons/day02-ether-and-calls.md) | 可记账 EtherVault |
| 03 | [状态机与 Foundry 测试](lessons/day03-testing-and-state-machines.md) | Escrow、Fuzz、Invariant |
| 04 | [标准合约与权限](lessons/day04-standards-and-access.md) | ERC-20、AccessControl、cap |
| 05 | [重入攻击实验](lessons/day05-reentrancy.md) | 可复现攻击与安全版本 |
| 06 | [EIP-712 与签名授权](lessons/day06-signatures.md) | nonce、deadline、domain separation |
| 07 | [delegatecall 与代理存储](lessons/day07-delegatecall-and-proxies.md) | storage collision 实验 |
| 08 | [ERC-4626 与 DeFi 份额数学](lessons/day08-erc4626.md) | 资产、份额、舍入与 donation |
| 09 | [Anvil、Cast 与部署脚本](lessons/day09-deployment.md) | 完整本地部署和交互 |
| 10 | [毕业项目](lessons/day10-capstone.md) | MilestoneEscrow 实现与威胁模型 |

## 仓库结构

```text
src/day01..day08/   可运行的递进式参考实现
src/day10/          毕业项目接口，刻意不提供实现
test/day01..day08/  单元、Fuzz、Invariant 和攻击测试
script/             本地部署脚本
lessons/            每天的目标、任务和完成标准
lib/                固定版本的外部依赖
```

Day 5 和 Day 7 包含故意不安全的合约，只能用于本地攻击实验。不要部署或复用这些实现。

## 代码注释约定

本仓库的示例代码同时保留两类中文注释：

- **业务注释**：说明参与者、业务目标、调用资格、前置条件、状态流转、资金归属、
  核心不变量和信任边界。
- **技术注释**：说明 Solidity 语法、EVM 行为、storage 布局、ABI、gas 和安全机制。
- 测试中的注释描述业务场景及验收结果，而不只是复述某一行代码。
- 如果业务规则与当前教学实现不一致，必须明确标为待修复项，不能用注释假装已经实现。

## 每日工作流

1. 先读当天 lesson，只浏览对应的 `src/dayXX`，暂时不看测试。
2. 写下资产、角色、状态转换、外部调用和至少三个不变量。
3. 自己补测试，再与仓库中的参考测试比较。
4. 使用 `-vvvv` 阅读一次成功路径和一次失败路径的调用 trace。
5. 完成 lesson 中的改造任务，保证全量测试仍通过。
6. 将结论记录到 [学习记录模板](lessons/notes-template.md)。

常用的定向命令：

```bash
forge test --match-path 'test/day02/*' -vvv
forge test --match-test 'test_AttackerDrainsVulnerableBank' -vvvv
forge test --match-contract 'EtherVaultInvariantTest' -vv
forge test --watch
forge coverage --report lcov
forge snapshot
```

## 工程规则

- 编译器警告必须被理解，不能为了安静而随意屏蔽。
- 每个状态修改函数都回答：谁能调用、改了什么、调用了谁、失败后状态如何。
- 每个资产合约都定义 accounting invariant，并用 Fuzz 或 Invariant 验证。
- 标准协议优先使用固定版本的 OpenZeppelin，不复制粘贴网络代码。
- 私钥不进入源码、命令历史、`.env` 或 Git；本地实验使用 Anvil unlocked account。
- 未经审计的学习合约不连接主网、不承载真实资产。

安全评审时使用 [威胁模型模板](lessons/threat-model-template.md)。

## 开源与贡献

本项目采用 [MIT License](LICENSE) 开源。欢迎通过 Issue 或 Pull Request 修正文档、补充测试、
改进示例和提出新的安全实验，提交前请阅读 [贡献指南](CONTRIBUTING.md)。

Day 5 和 Day 7 中的漏洞是课程设计的一部分。发现非预期安全问题时，请按
[安全策略](SECURITY.md)进行报告，不要在公开 Issue 中直接披露可利用细节。

## 参考资料

- [Solidity documentation](https://docs.soliditylang.org/en/v0.8.36/)
- [Foundry documentation](https://getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/)
- [Ethereum execution specs](https://github.com/ethereum/execution-specs)
