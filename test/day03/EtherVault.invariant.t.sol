// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {EtherVault} from "../../src/day02/EtherVault.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

/// @notice Handler 把任意模糊输入转换成有效操作，供 invariant runner 反复调用。
contract EtherVaultHandler is Test {
    EtherVault public immutable vault;
    uint256 public expectedAccountedAssets;

    // 限定三个参与者，便于生成多用户交错的存取款序列。
    address[3] private actors = [address(0xA11CE), address(0xB0B), address(0xCA401)];

    constructor(EtherVault vault_) {
        vault = vault_;
    }

    function deposit(uint256 actorSeed, uint96 rawAmount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 amount = bound(uint256(rawAmount), 1, 10 ether);
        vm.deal(actor, amount);

        vm.prank(actor);
        vault.deposit{value: amount}();
        expectedAccountedAssets += amount;
    }

    function withdraw(uint256 actorSeed, uint96 rawAmount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 available = vault.balances(actor);
        if (available == 0) return;

        uint256 amount = bound(uint256(rawAmount), 1, available);
        vm.prank(actor);
        vault.withdraw(amount);
        expectedAccountedAssets -= amount;
    }
}

contract EtherVaultInvariantTest is StdInvariant, Test {
    EtherVault private vault;
    EtherVaultHandler private handler;

    function setUp() public {
        vault = new EtherVault();
        handler = new EtherVaultHandler(vault);
        // 告诉 Foundry：随机操作序列应调用 handler 的外部函数。
        targetContract(address(handler));
    }

    /// @notice 无论操作顺序如何，合约账本都应等于测试模型账本。
    function invariant_AccountingMatchesSuccessfulOperations() public view {
        assertEq(vault.accountedAssets(), handler.expectedAccountedAssets());
    }

    /// @notice 金库真实 ETH 至少要覆盖已记账负债。
    function invariant_ContractCoversAllAccountedAssets() public view {
        assertGe(address(vault).balance, vault.accountedAssets());
    }
}
