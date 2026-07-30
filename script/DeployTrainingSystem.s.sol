// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {TrainingToken} from "../src/day04/TrainingToken.sol";
import {TrainingVault} from "../src/day08/TrainingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console2} from "forge-std/Script.sol";

/// @notice Day 09 部署脚本：一次部署训练代币和以该代币为底层资产的金库。
/// @dev Script 不是链上业务合约；Forge 在本地执行 run，并广播其中记录的交易。
///
/// 部署后的业务关系：
/// - administrator 管理 TRN 的角色与发行权限，不必等于实际广播部署交易的账户。
/// - TrainingVault 把新部署的 TRN 固定为底层资产，用户存入 TRN 后获得份额代币。
/// - 脚本只创建合约，不负责首批铸币、角色移交、验证源码或生产治理配置。
contract DeployTrainingSystem is Script {
    error InvalidAdministrator();

    /// @param administrator 获得 TrainingToken 管理员与铸币角色的地址。
    function run(address administrator)
        external
        returns (TrainingToken token, TrainingVault vault)
    {
        if (administrator == address(0)) {
            revert InvalidAdministrator();
        }

        // startBroadcast/stopBroadcast 之间的合约创建和调用会被 Forge 作为交易广播。
        vm.startBroadcast();
        token = new TrainingToken(administrator, 1_000_000 ether);
        vault = new TrainingVault(IERC20(address(token)));
        vm.stopBroadcast();

        // console2 只用于脚本/测试日志，不应作为生产合约业务逻辑的一部分。
        console2.log("TrainingToken", address(token));
        console2.log("TrainingVault", address(vault));
        console2.log("Administrator", administrator);
    }
}
