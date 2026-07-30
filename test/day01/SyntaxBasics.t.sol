// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {SyntaxBasics} from "../../src/day01/SyntaxBasics.sol";
import {Test} from "forge-std/Test.sol";

contract SyntaxBasicsTest is Test {
    event ProfileCreated(address indexed account, string nickname);
    event ScoreAdded(address indexed account, uint256 points, uint256 newScore);

    SyntaxBasics private basics;
    address private administrator = makeAddr("administrator");
    address private alice = makeAddr("alice");

    // Foundry 会在每个测试前调用 setUp，因此各测试不会共享修改后的状态。
    function setUp() public {
        basics = new SyntaxBasics(administrator);
    }

    /// @notice 业务验收：新用户完成注册后，档案、会员目录和总数必须同步更新。
    function test_CreateProfilePersistsStructAndEmitsEvent() public {
        vm.expectEmit(true, false, false, true, address(basics));
        emit ProfileCreated(alice, "alice");

        // prank 只把下一次外部调用的 msg.sender 修改为指定地址。
        vm.prank(alice);
        basics.createProfile("alice");

        SyntaxBasics.Profile memory profile = basics.profileOf(alice);
        assertEq(profile.nickname, "alice");
        assertEq(uint256(profile.membership), uint256(SyntaxBasics.Membership.Active));
        assertEq(profile.score, 0);
        assertEq(basics.profileCount(), 1);
        assertEq(basics.memberAt(0), alice);
    }

    /// @notice 业务约束：一个钱包地址不能重复创建会员档案。
    function test_RevertWhenProfileAlreadyExists() public {
        vm.startPrank(alice);
        basics.createProfile("alice");

        vm.expectRevert(abi.encodeWithSelector(SyntaxBasics.ProfileAlreadyExists.selector, alice));
        basics.createProfile("alice-again");
        vm.stopPrank();
    }

    /// @notice 权限场景：平台管理员可以给已注册会员增加积分。
    function test_AdministratorAddsScore() public {
        vm.prank(alice);
        basics.createProfile("alice");

        vm.expectEmit(true, false, false, true, address(basics));
        emit ScoreAdded(alice, 10, 10);
        vm.prank(administrator);
        basics.addScore(alice, 10);

        assertEq(basics.profileOf(alice).score, 10);
    }

    /// @notice 越权场景：普通会员不能自行增加积分。
    function test_RevertWhenNonAdministratorAddsScore() public {
        vm.prank(alice);
        basics.createProfile("alice");

        vm.expectRevert(abi.encodeWithSelector(SyntaxBasics.Unauthorized.selector, alice));
        vm.prank(alice);
        basics.addScore(alice, 10);
    }

    /// @notice 业务场景：会员可以修改自己的昵称，其他档案字段保持不变。
    function test_RenameUpdatesDynamicStorageValue() public {
        vm.startPrank(alice);
        basics.createProfile("alice");
        basics.rename("alice-v2");
        vm.stopPrank();

        assertEq(basics.profileOf(alice).nickname, "alice-v2");
    }

    /// @notice 数学性质：积分预览对有效输入始终等于两项之和。
    function testFuzz_PreviewScore(uint128 currentScore, uint128 points) public view {
        uint256 expected = uint256(currentScore) + uint256(points);
        assertEq(basics.previewScore(currentScore, points), expected);
    }
}
