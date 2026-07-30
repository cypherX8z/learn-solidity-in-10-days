// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {SignedClaims} from "../../src/day06/SignedClaims.sol";
import {Test} from "forge-std/Test.sol";

contract SignedClaimsTest is Test {
    event Claimed(address indexed recipient, uint256 amount, uint256 indexed nonce);

    SignedClaims private claims;
    uint256 private signerKey = 0xA11CE;
    address private recipient = makeAddr("recipient");
    address private relayer = makeAddr("relayer");

    function setUp() public {
        vm.warp(1_000_000);
        // vm.addr 根据私钥推导地址；测试中切勿使用真实资金私钥。
        claims = new SignedClaims(vm.addr(signerKey));
        vm.deal(address(claims), 100 ether);
    }

    /// @notice 代付场景：relayer 可提交授权，但 ETH 只能支付给签名指定的 recipient。
    function test_RelayerSubmitsValidClaim() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(recipient, 2 ether, 0, deadline, signerKey);

        vm.expectEmit(true, true, false, true, address(claims));
        emit Claimed(recipient, 2 ether, 0);
        // relayer 与 recipient 可以不同：签名授权的是收款内容，而不是交易发送者。
        vm.prank(relayer);
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);

        assertEq(recipient.balance, 2 ether);
        assertEq(claims.nonces(recipient), 1);
    }

    /// @notice 防重放：一份已兑现授权不能再次领取平台资金。
    function test_RevertWhenSignatureIsReplayed() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(recipient, 2 ether, 0, deadline, signerKey);
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);

        // 第一次领取把 nonce 从 0 增至 1，同一签名再次提交会被拒绝。
        vm.expectRevert(abi.encodeWithSelector(SignedClaims.InvalidNonce.selector, 1, 0));
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);
    }

    /// @notice 审批边界：非平台 signer 生成的授权无效。
    function test_RevertWhenSignerIsWrong() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(recipient, 2 ether, 0, deadline, 0xB0B);

        vm.expectRevert(SignedClaims.InvalidSigner.selector);
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);
    }

    /// @notice 跨链边界：为原 chainId 签发的授权不能在另一条链兑现。
    function test_RevertWhenSignatureComesFromAnotherChain() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(recipient, 2 ether, 0, deadline, signerKey);
        // EIP-712 域包含 chainId，切换链后相同签名恢复出的地址不再匹配。
        vm.chainId(block.chainid + 1);

        vm.expectRevert(SignedClaims.InvalidSigner.selector);
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);
    }

    /// @notice 时效边界：超过审批有效期的奖励不再允许领取。
    function test_RevertWhenClaimExpired() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _sign(recipient, 2 ether, 0, deadline, signerKey);
        vm.warp(deadline + 1);

        vm.expectRevert(abi.encodeWithSelector(SignedClaims.ClaimExpired.selector, deadline));
        claims.claim(payable(recipient), 2 ether, 0, deadline, signature);
    }

    /// @notice 金额性质：对任意有资金覆盖的有效奖励，收款人应收到精确授权金额。
    function testFuzz_ValidClaim(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 100 ether);
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(recipient, amount, 0, deadline, signerKey);

        claims.claim(payable(recipient), amount, 0, deadline, signature);

        assertEq(recipient.balance, amount);
    }

    function _sign(
        address account,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) private view returns (bytes memory) {
        bytes32 digest = claims.hashClaim(account, amount, nonce, deadline);
        // vm.sign 返回 v/r/s；常见的 65 字节签名顺序是 r || s || v。
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
