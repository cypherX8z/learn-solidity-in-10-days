// SPDX-License-Identifier: MIT
// SPDX 用于声明源码许可证；缺少这一行时，编译工具通常会发出警告。

// pragma 声明允许编译该文件的编译器版本范围。
// ^0.8.36 表示 >= 0.8.36 且 < 0.9.0；foundry.toml 进一步锁定实际版本。
pragma solidity ^0.8.36;

/// @title SyntaxBasics
/// @notice 专门用于学习 Solidity 基础语法的详细注释示例。
/// @dev 生产合约的注释通常会比本教学示例精简。
///
/// 业务场景：一个最小化的链上会员档案系统。
/// - 普通用户为自己的地址创建档案、修改昵称；一个地址只能有一份档案。
/// - administrator 代表平台运营方，负责调整会员状态和积分。
/// - Membership.None 同时承担“尚未注册”的业务含义；当前 setMembership 未禁止写回 None，
///   这是一个有意保留的“业务规则与代码不一致”检查点，应在练习中补上约束。
/// - members 数组是可枚举的会员目录，必须与 profileCount、profiles 同步更新。
contract SyntaxBasics {
    // enum 表示有限集合中的一个值；以下三个成员的底层整数依次是 0、1、2。
    enum Membership {
        None,
        Active,
        Suspended
    }

    // struct 把相关字段组合成一个类型，类似后端开发中的 DTO、record 或数据类。
    struct Profile {
        string nickname;
        uint64 createdAt;
        Membership membership;
        uint256 score;
    }

    // 自定义错误比 revert("长字符串") 更节省 gas，也能携带结构化参数。
    error InvalidAdministrator();
    error Unauthorized(address caller);
    error InvalidNickname();
    error ProfileAlreadyExists(address account);
    error ProfileNotFound(address account);

    // event 是供链下程序消费的只追加 EVM 日志，并不属于合约 storage。
    // indexed 参数会进入 topic，RPC 客户端和索引器可以按它高效过滤。
    event ProfileCreated(address indexed account, string nickname);
    event NicknameChanged(address indexed account, string previousNickname, string newNickname);
    event ScoreAdded(address indexed account, uint256 points, uint256 newScore);
    event MembershipChanged(address indexed account, Membership membership);

    // constant 的值会嵌入字节码，不占用 storage slot。
    uint256 public constant MAX_NICKNAME_BYTES = 32;

    // immutable 只能在声明处或构造函数中赋值，之后嵌入运行时字节码。
    address public immutable administrator;

    // 普通状态变量保存在合约 storage 中，跨交易持久存在。
    uint256 public profileCount;

    // mapping 提供键值查询，但不会保存或暴露一份可枚举的 key 列表。
    mapping(address account => Profile profile) private profiles;

    // 由于 mapping 无法枚举，这里额外维护一个数组记录成员地址。
    address[] private members;

    // constructor 只在部署合约时执行一次。
    constructor(address administrator_) {
        if (administrator_ == address(0)) revert InvalidAdministrator();
        administrator = administrator_;
    }

    // modifier 包裹函数体；下划线 _ 表示原函数体在此处执行。
    modifier onlyAdministrator() {
        if (msg.sender != administrator) revert Unauthorized(msg.sender);
        _;
    }

    // external 表示该函数主要从合约外部调用。
    // calldata 是交易输入的只读、非持久化视图，适合外部函数的动态参数。
    /// @notice 用户为自己的钱包地址创建会员档案。
    /// @dev 业务规则：昵称非空且不超过 32 字节，每个地址只能注册一次。
    function createProfile(string calldata nickname) external {
        _validateNickname(nickname);
        if (hasProfile(msg.sender)) revert ProfileAlreadyExists(msg.sender);

        // storage 引用指向持久状态；通过它写入的数据会在调用结束后保留。
        Profile storage profile = profiles[msg.sender];
        profile.nickname = nickname;
        profile.createdAt = uint64(block.timestamp);
        profile.membership = Membership.Active;

        members.push(msg.sender);
        ++profileCount;

        emit ProfileCreated(msg.sender, nickname);
    }

    /// @notice 档案所有者修改自己的昵称，平台管理员不能代改。
    function rename(string calldata newNickname) external {
        _validateNickname(newNickname);
        _requireProfile(msg.sender);

        Profile storage profile = profiles[msg.sender];

        // memory 只在本次调用期间存在，并且可以修改。
        // 把动态 string 从 storage 复制到 memory 会消耗额外 gas。
        string memory previousNickname = profile.nickname;
        profile.nickname = newNickname;

        emit NicknameChanged(msg.sender, previousNickname, newNickname);
    }

    /// @notice 平台运营方给指定会员增加积分。
    /// @dev 本例积分只增不减；真实业务还需定义积分来源、有效期和撤销机制。
    function addScore(address account, uint256 points) external onlyAdministrator {
        _requireProfile(account);

        // Solidity 0.8+ 默认检查整数溢出，发生溢出时会 revert。
        profiles[account].score += points;
        emit ScoreAdded(account, points, profiles[account].score);
    }

    /// @notice 平台运营方调整会员状态，例如暂停违规账户。
    /// @dev 当前调用方可传 Membership.None，使已有档案在查询时表现为“未注册”；这是待修复项。
    function setMembership(address account, Membership membership) external onlyAdministrator {
        _requireProfile(account);
        profiles[account].membership = membership;
        emit MembershipChanged(account, membership);
    }

    // public 函数既可从外部调用，也可被当前合约的其他函数直接调用。
    // view 承诺不修改状态；但若在交易中调用，读取 storage 仍会消耗 gas。
    function hasProfile(address account) public view returns (bool) {
        return profiles[account].membership != Membership.None;
    }

    // 返回 struct 会创建 memory 副本；链下可用 eth_call 读取，无需发送交易。
    function profileOf(address account) external view returns (Profile memory) {
        _requireProfile(account);
        return profiles[account];
    }

    function memberAt(uint256 index) external view returns (address) {
        // Solidity 自动检查数组下标，越界时会 revert。
        return members[index];
    }

    // pure 表示函数既不读取 storage，也不读取 msg.sender 等区块链上下文。
    function previewScore(uint256 currentScore, uint256 points) external pure returns (uint256) {
        return currentScore + points;
    }

    // private 辅助函数只能在当前合约内部调用。
    function _validateNickname(string calldata nickname) private pure {
        uint256 length = bytes(nickname).length;
        if (length == 0 || length > MAX_NICKNAME_BYTES) revert InvalidNickname();
    }

    function _requireProfile(address account) private view {
        if (!hasProfile(account)) revert ProfileNotFound(account);
    }
}
