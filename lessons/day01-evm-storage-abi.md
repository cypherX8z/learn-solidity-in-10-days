# Day 01: Solidity 基本语法、Storage 与 ABI

第一天分为两段。先把 Solidity 当作一门新的静态语言学习，再把这些语法映射到 EVM。
资深后端经验可以加快状态机、测试和工程部分，但不能替代 Solidity 的执行语义。

## 今日目标

- 看懂一个 Solidity 源文件的完整结构。
- 掌握常用类型、状态变量、函数、可见性和数据位置。
- 理解 constructor、modifier、custom error、event 和 `msg.sender`。
- 区分 storage、memory、calldata。
- 在语法基础上理解 storage slot、function selector 和 ABI calldata。

## 学习顺序

1. 阅读带详细注释的 `src/day01/SyntaxBasics.sol`。
2. 阅读 `test/day01/SyntaxBasics.t.sol`，熟悉 Foundry 测试语法。
3. 完成语法检查点后，再阅读 `src/day01/StorageLab.sol`。
4. 最后运行 storage 和 ABI 实验。

## 1. Solidity 文件结构

最小合约如下：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

contract Counter {
    uint256 public value;

    function increment() external {
        value += 1;
    }
}
```

### SPDX

`SPDX-License-Identifier` 声明源码许可证。它不是 Solidity 语法，但编译器和验证工具会读取它。

### pragma

```solidity
pragma solidity ^0.8.36;
```

表示源码接受 `>= 0.8.36` 且 `< 0.9.0` 的编译器。实际项目仍应在工具配置中固定精确版本；
本仓库由 `foundry.toml` 固定为 0.8.36。

### contract

`contract` 类似 class，但部署后拥有独立地址、持久化 storage 和公开可调用的 ABI。
代码默认不可替换，除非系统显式引入代理升级机制。

## 2. 常用类型

| Solidity | 说明 | 后端类比 |
| --- | --- | --- |
| `bool` | `true/false` | boolean |
| `uint256` | 256 位无符号整数 | unsigned big integer with fixed width |
| `int256` | 256 位有符号整数 | signed fixed-width integer |
| `address` | 20-byte EVM 地址 | account/service identity |
| `address payable` | 允许发送 ETH 的地址类型 | address with payment capability |
| `bytes32` | 固定 32 bytes | hash/id/raw word |
| `bytes` | 动态字节序列 | byte array |
| `string` | UTF-8 字节序列，不提供完整 Unicode 字符操作 | string payload |
| `T[]` | 动态数组 | list |
| `mapping(K => V)` | 非枚举 key-value storage | map without key iteration |
| `struct` | 字段集合 | record/DTO |
| `enum` | 有限状态集合 | enum |

`uint` 是 `uint256` 的别名。智能合约通常使用整数表达金额，例如 1 ETH 是
`1_000_000_000_000_000_000 wei`。Solidity 没有适合财务计算的运行时浮点数。

所有变量都有默认值，没有 Java 风格的 `null`：数字为 0、地址为零地址、bool 为 false、
动态数组和 bytes/string 初始为空。

## 3. 状态变量与局部变量

```solidity
uint256 public profileCount; // state variable

function example(uint256 input) external {
    uint256 doubled = input * 2; // local variable
    profileCount = doubled;
}
```

- 状态变量位于合约 storage，跨交易持久化，写入成本高。
- 局部变量只存在于当前调用的 stack/memory/calldata 中。
- `public` 状态变量由编译器自动生成只读 getter，不代表任何人能直接修改它。
- `private` 只限制其他 Solidity 合约的语言级访问，不会隐藏链上数据。

### constant 与 immutable

```solidity
uint256 public constant LIMIT = 50;
address public immutable administrator;
```

- `constant` 在编译期确定，不占普通 storage slot。
- `immutable` 在 constructor 中赋值一次，随后嵌入部署后的 bytecode。

## 4. 函数声明

通用形式：

```solidity
function name(parameters)
    visibility
    mutability
    modifiers
    returns (returnTypes)
{
    // body
}
```

### 可见性

| 关键字 | 可调用范围 |
| --- | --- |
| `external` | 主要供合约外部调用；内部直接 `f()` 不可用 |
| `public` | 外部和合约内部均可调用 |
| `internal` | 当前合约和子合约可调用 |
| `private` | 仅当前合约可调用 |

`private` 不是安全边界。真正的运行时权限检查通常基于 `msg.sender`、签名或 role。

### 状态可变性

| 关键字 | 含义 |
| --- | --- |
| `view` | 不修改状态 |
| `pure` | 不读取也不修改状态或区块上下文 |
| `payable` | 允许调用时附带 ETH |
| 无关键字 | 可能修改状态，但不能接收 ETH |

RPC 使用 `eth_call` 执行 view/pure getter 时不会创建交易。若另一个合约在交易中调用 view，
执行仍然消耗交易 gas。

## 5. Storage、Memory 与 Calldata

引用类型需要说明数据位置：

| 位置 | 生命周期 | 是否可修改 | 常见用途 |
| --- | --- | --- | --- |
| `storage` | 永久 | 可修改 | 状态变量或状态引用 |
| `memory` | 当前调用 | 可修改 | 临时副本、返回值 |
| `calldata` | 当前外部调用 | 只读 | external 函数参数 |

```solidity
function rename(string calldata newName) external {
    Profile storage profile = profiles[msg.sender];
    string memory oldName = profile.nickname;
    profile.nickname = newName;
}
```

- `profile` 是 storage 引用，修改它会修改永久状态。
- `oldName` 是从 storage 复制到 memory 的临时值。
- `newName` 直接引用只读 calldata，避免不必要复制。
- `uint256`、`address` 等 value type 不需要标注数据位置。

## 6. Struct、Enum、Array 与 Mapping

```solidity
enum Membership { None, Active, Suspended }

struct Profile {
    string nickname;
    Membership membership;
    uint256 score;
}

mapping(address => Profile) private profiles;
address[] private members;
```

mapping 不保存 key 列表，无法询问“有哪些用户”。需要枚举时必须额外维护数组或集合，
并考虑数组无限增长带来的 gas/DoS 风险。

动态数组支持 `push`、`pop` 和下标访问。越界访问会自动 revert。

## 7. Constructor、Modifier 与调用者

constructor 只在部署时运行一次：

```solidity
constructor(address administrator_) {
    administrator = administrator_;
}
```

modifier 用于复用前置或后置逻辑：

```solidity
modifier onlyAdministrator() {
    if (msg.sender != administrator) revert Unauthorized(msg.sender);
    _;
}
```

`_` 是被修饰函数正文的执行位置。`msg.sender` 是当前调用的直接调用者，既可能是 EOA，
也可能是另一个合约；它不一定是最初发起交易的人。

## 8. 错误、回滚与事件

### Custom error

```solidity
error Unauthorized(address caller);

if (msg.sender != administrator) {
    revert Unauthorized(msg.sender);
}
```

custom error 会产生带 selector 和参数的结构化 revert data，比长字符串省 gas。

- `revert`/`require` 用于输入、权限和业务条件。
- `assert` 用于理论上永远成立的内部不变量，失败产生 Panic。
- revert 会撤销当前调用帧及其子调用的状态；父调用若使用低级调用捕获失败，可以继续执行。

### Event

```solidity
event ProfileCreated(address indexed account, string nickname);
emit ProfileCreated(msg.sender, nickname);
```

event 是交易 receipt 中的 log，适合索引器和后端消费。历史 event 不能被合约当作 storage 查询。
`indexed` 字段进入 topic，最多用于三个自定义参数。

## 9. 算术与控制流

`if`、`for`、`while`、`return` 与常见语言相似。Solidity 0.8+ 默认检查整数溢出和下溢：

```solidity
score += points; // overflow => revert
```

`unchecked { ... }` 可以关闭检查，但只能在已经证明边界安全时使用。链上循环必须考虑 gas；
不要遍历可由用户无限扩大的 storage 数组。

## 10. Foundry 基础测试语法

阅读 `test/day01/SyntaxBasics.t.sol`，重点理解：

| Foundry API | 用途 |
| --- | --- |
| `setUp()` | 每个测试前重新建立状态 |
| `makeAddr("alice")` | 生成带标签的测试地址 |
| `vm.prank(alice)` | 下一次外部调用使用 alice 作为 msg.sender |
| `vm.startPrank/stopPrank` | 一段调用持续模拟同一调用者 |
| `vm.expectRevert` | 断言下一次调用按预期回滚 |
| `vm.expectEmit` | 断言事件 |
| `assertEq` | 断言结果 |
| `testFuzz_...` | 参数由 Foundry 自动生成并重复执行 |

运行语法测试：

```bash
forge test --match-path 'test/day01/SyntaxBasics.t.sol' -vvv
```

## 11. 从语法进入 EVM Storage

`StorageLab` 的布局是：

| Slot | 内容 |
| --- | --- |
| 0 | `sequence`，完整 32 bytes |
| 1 | `owner`，占低 20 bytes |
| 2 | `balances` mapping 的基准 slot |

mapping 的数据不直接存放在 slot 2。`balances[key]` 的位置是：

```solidity
keccak256(abi.encode(key, uint256(2)))
```

```bash
forge inspect StorageLab storageLayout
forge test --match-test test_StorageLayoutForValueAndMapping -vvvv
```

## 12. Function Selector 与 Calldata

ABI 使用规范函数签名的 keccak256 前 4 bytes 作为 selector：

```text
setBalance(address,uint256) -> 0xe30443bc
```

```bash
cast sig 'setBalance(address,uint256)'
cast calldata 'setBalance(address,uint256)' \
  0x000000000000000000000000000000000000a11c 77
```

calldata 由 `4-byte selector + ABI encoded arguments` 组成。上述调用是 68 bytes：

```text
e30443bc                                                         selector
000000000000000000000000000000000000000000000000000000000000a11c address
000000000000000000000000000000000000000000000000000000000000004d uint256(77)
```

## 今日练习

### A. 语法练习

为 `SyntaxBasics` 增加 `suspendMyProfile()`：

- 只有已经创建 profile 的调用者可以执行。
- 将 membership 从 Active 改为 Suspended。
- 重复 suspend 必须使用 custom error 回滚。
- 发出 `MembershipChanged`。
- 添加成功和失败测试。

### B. Storage/权限练习

为 `StorageLab` 增加两阶段 owner 转移：

- `address public pendingOwner`
- `proposeOwner(address newOwner)` 只能由 owner 调用。
- `acceptOwnership()` 只能由 pendingOwner 调用。
- 接受后清空 pendingOwner，并发出事件。
- 读取新增变量的 raw storage slot；因为它追加在 mapping 后，应位于 slot 3。

### C. 思考题

1. `address` 只占 20 bytes。若 `uint96 quota` 紧跟在 owner 后、mapping 前声明，它位于哪个 slot？
2. 为什么 `private mapping` 的内容仍能被链外读取？
3. 为什么 `vm.prank` 可能被函数参数中的一次外部 getter 调用提前消耗？
4. event 能否作为合约业务逻辑的唯一数据源？
5. external view 函数“免费”这个说法在什么上下文成立？

## 完成标准

- 能解释 `SyntaxBasics.sol` 中每个关键字的作用。
- 能区分 state variable、storage reference、memory copy 和 calldata view。
- 能为权限错误写精确的 custom error 测试。
- 能算出 mapping entry 的 slot。
- 能从 calldata 拆出 selector 和参数。
