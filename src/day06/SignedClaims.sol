// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title SignedClaims
/// @notice 授权者在链下签名，任意 relayer 可在链上代为提交并领取 ETH。
/// @dev EIP-712 把结构化消息绑定到合约地址和 chainId，降低跨域重放风险。
///
/// 业务场景：平台离线审批补贴/奖励，收款人或代提交者在链上兑现。
/// - signer 是业务审批方，其签名明确授权 recipient、amount、nonce、deadline。
/// - recipient 是唯一收款方；relayer 只负责代付 gas，不能更改收款地址或金额。
/// - 每个 recipient 的 nonce 独立递增，每份授权最多成功兑现一次。
/// - 合约必须预先拥有足够 ETH；有效签名不等于平台一定具备偿付资金。
/// - signer 私钥是核心信任边界，泄露后攻击者可签发任意未过期奖励。
contract SignedClaims is EIP712 {
    error InvalidSigner();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidNonce(uint256 expected, uint256 supplied);
    error ClaimExpired(uint256 deadline);
    error TransferFailed();

    event Claimed(address indexed recipient, uint256 amount, uint256 indexed nonce);

    // typehash 精确描述被签名结构；字段名称、类型或顺序变化都会产生不同哈希。
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256("Claim(address recipient,uint256 amount,uint256 nonce,uint256 deadline)");

    address public immutable signer;
    // 每个收款人维护独立 nonce；成功领取后递增，使同一签名不能重复使用。
    mapping(address recipient => uint256 nonce) public nonces;

    /// @notice 初始化 EIP-712 域名、版本和唯一合法签名者。
    constructor(address signer_) EIP712("SignedClaims", "1") {
        if (signer_ == address(0)) revert InvalidSigner();
        signer = signer_;
    }

    /// @notice 验证结构化签名并向 recipient 支付 ETH。
    /// @param signature 65 字节 ECDSA 签名，通常编码为 r || s || v。
    /// @dev 任何地址都可提交，但只有签名中指定的 recipient 收款。
    function claim(
        address payable recipient,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        // 本例的过期窗口较粗，可以接受区块时间戳的小幅漂移。
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > deadline) revert ClaimExpired(deadline);

        uint256 expectedNonce = nonces[recipient];
        if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

        // recover 从摘要和签名恢复地址，再与受信 signer 比较。
        bytes32 digest = hashClaim(recipient, amount, nonce, deadline);
        if (ECDSA.recover(digest, signature) != signer) revert InvalidSigner();

        // 先消耗 nonce，再执行外部转账，遵循 Checks-Effects-Interactions。
        nonces[recipient] = expectedNonce + 1;

        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Claimed(recipient, amount, nonce);
    }

    /// @notice 计算钱包应签署、合约应恢复的 EIP-712 最终摘要。
    function hashClaim(address recipient, uint256 amount, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        // abi.encode 使用标准 32 字节槽编码，适合 EIP-712；这里不能换成 encodePacked。
        bytes32 structHash =
            keccak256(abi.encode(CLAIM_TYPEHASH, recipient, amount, nonce, deadline));
        // _hashTypedDataV4 加入域分隔符，域中包含 chainId 和 verifyingContract。
        return _hashTypedDataV4(structHash);
    }

    /// @notice 允许合约接收 ETH，作为后续 claim 的资金来源。
    receive() external payable {}
}
