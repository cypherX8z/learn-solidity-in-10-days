# Day 09: Anvil、Cast 与部署脚本

## 今日目标

- 在本地节点完成部署、读调用、写交易和事件检查。
- 区分 simulation、broadcast 和 verification。
- 不把私钥写入源码、`.env` 或命令历史。

## 1. 启动本地链

终端 A：

```bash
anvil
```

记录 Anvil 输出的第一个公开账户地址。终端 B：

```bash
export LOCAL_RPC_URL=http://127.0.0.1:8545
export ADMIN=<ANVIL_FIRST_ACCOUNT_ADDRESS>
cast chain-id --rpc-url "$LOCAL_RPC_URL"
cast balance "$ADMIN" --ether --rpc-url "$LOCAL_RPC_URL"
```

## 2. 部署

脚本使用 Anvil 的 unlocked account，不需要在命令行出现私钥：

```bash
forge script script/DeployTrainingSystem.s.sol:DeployTrainingSystem \
  --sig 'run(address)' "$ADMIN" \
  --rpc-url "$LOCAL_RPC_URL" \
  --sender "$ADMIN" \
  --unlocked \
  --broadcast \
  --force \
  -vvvv
```

`--force` 会重建普通 bytecode，避免刚运行过 coverage 后复用插桩 artifact。

从输出中记录 `TrainingToken` 和 `TrainingVault` 地址：

```bash
export TOKEN=<TRAINING_TOKEN_ADDRESS>
export VAULT=<TRAINING_VAULT_ADDRESS>
```

## 3. 使用 Cast 交互

```bash
cast call "$TOKEN" 'name()(string)' --rpc-url "$LOCAL_RPC_URL"

cast send "$TOKEN" 'mint(address,uint256)' "$ADMIN" 100000000000000000000 \
  --from "$ADMIN" --unlocked --rpc-url "$LOCAL_RPC_URL"

cast send "$TOKEN" 'approve(address,uint256)' "$VAULT" 100000000000000000000 \
  --from "$ADMIN" --unlocked --rpc-url "$LOCAL_RPC_URL"

cast send "$VAULT" 'deposit(uint256,address)' 100000000000000000000 "$ADMIN" \
  --from "$ADMIN" --unlocked --rpc-url "$LOCAL_RPC_URL"

cast call "$VAULT" 'balanceOf(address)(uint256)' "$ADMIN" \
  --rpc-url "$LOCAL_RPC_URL"
```

## 动手任务

1. 使用 `cast receipt` 检查部署和 deposit 的 logs。
2. 使用 `cast storage` 与 `forge inspect ... storageLayout` 对照 Token storage。
3. 停止并重启 Anvil，解释地址中为什么不再有代码。
4. 使用 `anvil --dump-state`/`--load-state` 保存并恢复本地状态。
5. 为脚本写 deployment smoke test，验证 role、cap、asset 和 vault 关联。

## 测试网前检查

- 使用 Foundry keystore 或硬件钱包，不传裸 `--private-key`。
- 先不带 `--broadcast` 完成 simulation。
- 固定 chain ID、compiler、EVM version、constructor 参数和依赖版本。
- 保存 broadcast artifact，验证源码后再转移任何权限。

## 完成标准

- 能从空 Anvil 节点重复完成部署与交互。
- 能解释 `eth_call` 与发送交易的状态差异。
- shell history、Git 和 `.env` 中不存在私钥。
