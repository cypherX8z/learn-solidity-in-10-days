// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/// @title IMilestoneEscrow
/// @notice Day 10 综合项目的行为契约；你需要根据该接口完成实现。
/// @dev 接口定义外部可观察的 ABI，但不规定内部 storage 布局和算法。
///
/// 业务场景：客户 client 委托承包方 contractor 分阶段交付项目，并引入 arbiter 仲裁争议。
/// - client 创建项目、一次性托管全部里程碑预算，并逐项批准合格交付。
/// - contractor 只能领取已经批准且尚未结算的里程碑款项。
/// - client 或 contractor 可对未结算项目发起争议，arbiter 决定支付或退款。
/// - 过期、未批准且未争议的里程碑可退还 client。
/// - 每个里程碑最多结算一次；所有已释放和已退款金额不得超过总托管金额。
/// - 三个角色必须互不相同且非零，避免业务职责由同一地址自批、自领或自裁。
///
/// 设计检查点：接口保留了 Active、Completed、Refunded，但没有替实现者决定“部分支付、
/// 部分退款”时使用哪个终态。实现前必须明确状态迁移表，并在威胁模型和测试中固定语义。
interface IMilestoneEscrow {
    // 整个托管项目的生命周期状态。里程碑还需要各自的 approved/paid/disputed 状态。
    enum Status {
        // 已创建但尚未收到完整托管款。
        Created,
        // client 已一次性完成全额托管。
        Funded,
        // 至少一个里程碑进入审批、领取或争议流程；精确定义由实现给出。
        Active,
        // 所有里程碑均已结算，且实现定义该结果为完成。
        Completed,
        // 所有里程碑均已结算，且实现定义该结果为退款结束。
        Refunded,
        // 存在等待 arbiter 处理的争议；需决定多里程碑并行争议如何映射到全局状态。
        Disputed
    }

    error Unauthorized(address caller);
    error InvalidState(Status current);
    error InvalidMilestone(uint256 index);
    error IncorrectFunding(uint256 expected, uint256 supplied);
    error DeadlineNotReached(uint256 deadline);
    error TransferFailed();

    // 事件是系统提供给前端、索引器和监控服务的链上审计日志。
    event Funded(address indexed client, uint256 amount);
    event MilestoneApproved(uint256 indexed index, uint256 amount);
    event MilestoneClaimed(uint256 indexed index, address indexed contractor, uint256 amount);
    event DisputeOpened(uint256 indexed index, address indexed openedBy);
    event DisputeResolved(uint256 indexed index, bool releasedToContractor);
    event Refunded(address indexed client, uint256 amount);

    // 写操作：会改变业务状态，调用方需发送交易并支付 gas。

    /// @notice client 一次性存入全部里程碑金额之和。
    /// @dev 仅可在 Created 状态成功一次，msg.value 必须与预算精确相等。
    function fund() external payable;

    /// @notice client 确认某项交付合格，使 contractor 获得领取资格。
    /// @dev 已结算或处于争议中的里程碑不得再批准。
    function approveMilestone(uint256 index) external;

    /// @notice contractor 领取一项已批准里程碑的款项。
    /// @dev 必须先标记已支付再转账，保证同一里程碑最多付款一次。
    function claimMilestone(uint256 index) external;

    /// @notice client 或 contractor 对尚未结算的里程碑发起争议。
    /// @dev 发起争议后，普通批准、领取和过期退款路径都应被冻结。
    function openDispute(uint256 index) external;

    /// @notice arbiter 裁决争议款支付给 contractor，或退还给 client。
    /// @dev releaseToContractor=true 表示支付，否则退款；一项争议只能裁决一次。
    function resolveDispute(uint256 index, bool releaseToContractor) external;

    /// @notice client 收回所有已到期、未批准且未争议的可退款金额。
    /// @dev 接口没有 index 参数，因此实现需明确是批量扫描还是采用其他可扩展记账方式。
    function refundExpired() external;

    // 读操作：为前端、索引器和审计工具提供项目级业务快照。
    function client() external view returns (address);
    function contractor() external view returns (address);
    function arbiter() external view returns (address);
    function status() external view returns (Status);
    function totalDeposited() external view returns (uint256);
    function totalReleased() external view returns (uint256);
    function totalRefunded() external view returns (uint256);
    function milestoneCount() external view returns (uint256);

    /// @notice 返回单个里程碑的金额、截止时间和审批、支付、争议标记。
    /// @dev 前端需要组合全局 status 与这些局部字段，判断当前允许展示哪些操作。
    function milestone(uint256 index)
        external
        view
        returns (uint256 amount, uint256 deadline, bool approved, bool paid, bool disputed);
}
