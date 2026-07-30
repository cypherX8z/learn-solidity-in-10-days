# 安全策略

## 项目定位

本仓库是教学项目，未经审计，不得承载真实资产或直接部署到生产网络。

`src/day05/ReentrancyLab.sol` 和 `src/day07/DelegatecallLab.sol` 包含故意设计的漏洞，用于复现
重入攻击和 storage collision。这些已标注问题属于课程内容，不作为安全缺陷受理。

## 报告非预期问题

若发现其他可导致资产损失、权限绕过、签名重放或依赖供应链风险的问题，请优先使用 GitHub
Security Advisories 的私密报告功能。请提供：

- 受影响文件和版本；
- 业务影响与攻击前提；
- 最小复现步骤或 Foundry 测试；
- 建议的修复方向。

在修复发布前，请不要在公开 Issue、Discussion 或 Pull Request 中披露可直接利用的细节。
