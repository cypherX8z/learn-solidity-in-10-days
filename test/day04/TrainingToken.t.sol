// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {TrainingToken} from "../../src/day04/TrainingToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Test} from "forge-std/Test.sol";

contract TrainingTokenTest is Test {
    TrainingToken private token;
    address private admin = makeAddr("admin");
    address private minter = makeAddr("minter");
    address private alice = makeAddr("alice");
    uint256 private constant CAP = 1_000_000 ether;

    function setUp() public {
        token = new TrainingToken(admin, CAP);
    }

    /// @notice 初始治理：部署参数指定的管理员同时获得治理和铸币权限。
    function test_AdministratorStartsWithRequiredRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertEq(token.cap(), CAP);
    }

    /// @notice 权限委派：管理员授予 minter 后，minter 可为用户发行代币。
    function test_AdministratorCanDelegateMinting() public {
        bytes32 minterRole = token.MINTER_ROLE();
        // AccessControl 的管理员可以把某个角色授予其他地址。
        vm.prank(admin);
        token.grantRole(minterRole, minter);

        vm.prank(minter);
        token.mint(alice, 100 ether);

        assertEq(token.balanceOf(alice), 100 ether);
    }

    /// @notice 越权约束：未获 MINTER_ROLE 的持有人不能自行增发。
    function test_RevertWhenCallerCannotMint() public {
        // OpenZeppelin 自定义错误来自父合约，可通过接口取得 selector。
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.MINTER_ROLE()
            )
        );
        vm.prank(alice);
        token.mint(alice, 1 ether);
    }

    /// @notice 供应约束：任何一次铸币都不能使 totalSupply 超过 cap。
    function test_RevertWhenCapWouldBeExceeded() public {
        // startPrank 会持续修改 msg.sender，直到 stopPrank。
        vm.startPrank(admin);
        token.mint(alice, CAP);

        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        token.mint(alice, 1);
        vm.stopPrank();
    }

    /// @notice ERC-20 守恒：发行后完整转账只改变持有人，不改变 totalSupply。
    function testFuzz_MintAndTransfer(uint96 rawAmount) public {
        // uint96 限制 fuzzer 输入上界，bound 再保证金额非零且不超过 cap。
        uint256 amount = bound(uint256(rawAmount), 1, CAP);

        vm.prank(admin);
        token.mint(admin, amount);

        vm.prank(admin);
        assertTrue(token.transfer(alice, amount));

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }
}
