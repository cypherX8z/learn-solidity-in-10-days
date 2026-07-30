// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {DeadlineEscrow} from "../../src/day03/DeadlineEscrow.sol";
import {Test} from "forge-std/Test.sol";

contract DeadlineEscrowTest is Test {
    event Released(address indexed seller, uint256 amount, address indexed authorizedBy);
    event Refunded(address indexed buyer, uint256 amount, address indexed authorizedBy);

    DeadlineEscrow private escrow;
    address private buyer = makeAddr("buyer");
    address private seller = makeAddr("seller");
    address private arbiter = makeAddr("arbiter");
    uint256 private constant PRICE = 5 ether;
    uint256 private deadline;

    function setUp() public {
        // 固定测试时间，使 deadline 不依赖执行测试时的真实时间。
        vm.warp(1_000_000);
        deadline = block.timestamp + 7 days;
        escrow = new DeadlineEscrow(buyer, seller, arbiter, PRICE, deadline);
        vm.deal(buyer, PRICE);
    }

    /// @notice 正常交易：买方全额托管并验收后，卖方收到全部价款且项目终结。
    function test_BuyerFundsAndReleasesToSeller() public {
        _fund();
        uint256 sellerBalanceBefore = seller.balance;

        vm.expectEmit(true, true, false, true, address(escrow));
        emit Released(seller, PRICE, buyer);
        // vm.prank 只修改下一次调用的 msg.sender。
        vm.prank(buyer);
        escrow.release();

        assertEq(uint256(escrow.state()), uint256(DeadlineEscrow.State.Released));
        assertEq(seller.balance, sellerBalanceBefore + PRICE);
        assertEq(address(escrow).balance, 0);
    }

    /// @notice 超期退出：交易未完成且已过期时，买方可收回全部托管款。
    function test_BuyerRefundsAfterDeadline() public {
        _fund();
        // 把 EVM 时间推进到截止时间后的第 1 秒。
        vm.warp(deadline + 1);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit Refunded(buyer, PRICE, buyer);
        vm.prank(buyer);
        escrow.refundAfterDeadline();

        assertEq(uint256(escrow.state()), uint256(DeadlineEscrow.State.Refunded));
        assertEq(buyer.balance, PRICE);
    }

    /// @notice 仲裁场景：仲裁人支持买方时，托管款退回买方。
    function test_ArbiterCanResolveForBuyer() public {
        _fund();

        vm.prank(arbiter);
        escrow.resolve(false);

        assertEq(uint256(escrow.state()), uint256(DeadlineEscrow.State.Refunded));
        assertEq(buyer.balance, PRICE);
    }

    /// @notice 角色约束：卖方不能冒充买方为托管订单出资。
    function test_RevertWhenNonBuyerFunds() public {
        vm.expectRevert(abi.encodeWithSelector(DeadlineEscrow.Unauthorized.selector, seller));
        vm.prank(seller);
        escrow.fund();
    }

    /// @notice 金额约束：托管只接受精确价款，不接受少付或部分付款。
    function test_RevertWhenFundingAmountIsIncorrect() public {
        vm.expectRevert(
            abi.encodeWithSelector(DeadlineEscrow.IncorrectFunding.selector, PRICE, PRICE - 1)
        );
        vm.prank(buyer);
        escrow.fund{value: PRICE - 1}();
    }

    /// @notice 终态约束：已经释放的价款不能通过后续仲裁再次退款。
    function test_RevertWhenSettlingTwice() public {
        _fund();
        vm.prank(buyer);
        escrow.release();

        // 第二次结算应被状态机拒绝，并返回 expected/actual 两个枚举值。
        vm.expectRevert(
            abi.encodeWithSelector(
                DeadlineEscrow.InvalidState.selector,
                DeadlineEscrow.State.Funded,
                DeadlineEscrow.State.Released
            )
        );
        vm.prank(arbiter);
        escrow.resolve(false);
    }

    function _fund() private {
        vm.prank(buyer);
        escrow.fund{value: PRICE}();
    }
}
