// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @notice ERC-4626 练习使用的底层资产，任何人都能铸币。
/// @dev 无权限 mint 是刻意设计的测试便利功能，生产环境绝不能照搬。
/// 业务定位：LAB 仅是本地实验资产，不代表有价值或存在发行约束。
contract LabAsset is ERC20 {
    // ERC20 父构造函数设置代币名称和符号；默认 decimals 为 18。
    constructor() ERC20("Lab Asset", "LAB") {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}

/// @title TrainingVault
/// @notice 最小 ERC-4626 金库：用户存入 LAB，获得代表份额的 tvLAB。
/// @dev ERC-4626 负责 deposit/mint/withdraw/redeem 及资产与份额换算。
///
/// 业务场景：多个存款人按份额共同持有金库中的底层资产及其收益。
/// - assets 是用户投入或取出的 LAB；shares 是用户对金库资产的比例化权利。
/// - 首次存款接近 1:1 铸造份额，之后汇率由 totalAssets/totalSupply 决定。
/// - 外部直接捐赠 LAB 会提高已有份额价值，晚到的存款人会获得更少份额。
/// - 赎回会销毁 shares 并返还按当前汇率计算的 assets。
/// - 本例没有策略、手续费、收益来源或滑点保护，不能直接作为生产金库。
contract TrainingVault is ERC4626 {
    // 同时初始化“份额代币”的 ERC20 元数据，以及金库的底层 asset。
    constructor(IERC20 asset_) ERC20("Training Vault Share", "tvLAB") ERC4626(asset_) {}
}
