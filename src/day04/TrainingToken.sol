// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/// @title TrainingToken
/// @notice 基于 OpenZeppelin 组合 ERC20、供应上限和角色权限的训练代币。
/// @dev 生产项目应优先复用经过审计的标准实现，而不是自行重写 ERC20。
///
/// 业务场景：平台发行总量受限、可委派铸币权限的业务代币。
/// - administrator 是权限治理方，可授予或撤销 MINTER_ROLE。
/// - minter 是发行执行方，只能铸币，不能自动获得管理员权限。
/// - holder 按标准 ERC20 规则持有、转账和授权第三方支出。
/// - cap 是任一时刻 totalSupply 的硬上限，但不代表累计发行计划或单账户限额。
/// - 管理员私钥失陷可导致未发行额度被恶意铸造，生产系统应使用多签和延迟治理。
contract TrainingToken is ERC20Capped, AccessControl {
    error InvalidAdministrator();

    // 角色使用 bytes32 标识。固定字符串的 keccak256 是常见且可复现的生成方式。
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice 部署代币，并把管理员角色和铸币角色授予 administrator。
    /// @dev ERC20(...) 与 ERC20Capped(...) 分别调用两个父合约的构造函数。
    constructor(address administrator, uint256 cap_)
        ERC20("Training Token", "TRN")
        ERC20Capped(cap_)
    {
        if (administrator == address(0)) {
            revert InvalidAdministrator();
        }
        // DEFAULT_ADMIN_ROLE 可以授予和撤销其他角色，因此权限最高。
        _grantRole(DEFAULT_ADMIN_ROLE, administrator);
        _grantRole(MINTER_ROLE, administrator);
    }

    /// @notice 只有 MINTER_ROLE 成员可以增发，且总量不能超过 cap。
    /// @dev onlyRole 来自 AccessControl；_mint 的上限检查由 ERC20Capped 覆盖实现。
    /// 业务效果：recipient 余额与 totalSupply 同时增加 amount，并产生标准 Transfer 事件。
    function mint(address recipient, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(recipient, amount);
    }
}
