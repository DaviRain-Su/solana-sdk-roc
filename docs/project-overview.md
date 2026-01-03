# Roc on Solana Platform - 项目概览

## 愿景

创建一个基于 Roc 语言的 Solana 智能合约开发平台，让开发者能够使用纯函数式编程范式编写高性能的 Solana 程序。

## 为什么是 Roc？

### 技术优势

1. **Perceus 内存管理**
   - 基于引用计数的自动内存管理
   - 智能的就地更新优化（In-place mutation）
   - 无 GC 停顿，完美匹配 Solana 的计算单元限制

2. **Platform 架构**
   - 语言核心与平台实现完全解耦
   - 可以通过 Zig 编写 Solana Platform
   - 无需修改 Roc 编译器

3. **开发体验**
   - 纯函数式，代码清晰易懂
   - 强大的类型系统和模式匹配
   - 管道操作符 `|>` 使逻辑流程一目了然

### 对比其他语言

| 特性 | Rust | Roc | Move | Solidity |
|------|------|-----|------|----------|
| 内存管理 | 手动(Borrow Checker) | 自动(Perceus) | 自动(GC) | 自动(GC) |
| 开发难度 | 高 | 中 | 中 | 低 |
| 性能 | 极高 | 高 | 中 | 低 |
| 函数式支持 | 部分 | 完全 | 部分 | 否 |
| Solana 支持 | 原生 | 开发中 | 否 | 否 |

## 项目架构

```
┌─────────────────────────────────────────┐
│         Roc 智能合约代码                 │
│      （纯函数式业务逻辑）               │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        Roc Platform 接口定义             │
│    （类型定义、Effect 声明）            │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Zig Host 层                     │
│    （内存管理、数据转换、系统调用）      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      Zig Solana SDK                      │
│   （DaviRain-Su/solana-sdk-zig）        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        Solana Runtime (BPF)              │
└─────────────────────────────────────────┘
```

## 核心组件

### 1. Roc Platform (`platform/`)
- 定义 Solana 数据类型（Pubkey, Account, Instruction）
- 声明 Effect 接口（log, invoke, transfer）
- 提供函数式 API

### 2. Zig Host (`host.zig`)
- 实现 Roc 内存分配接口
- 数据格式转换（Roc ↔ Zig）
- 封装 SDK 调用

### 3. 构建系统 (`build.zig`)
- 编译 Roc 代码到对象文件
- 链接 Zig Host 和 Roc 对象
- 生成 Solana BPF 程序

## 开发示例

```elm
# token_swap.roc
app "token-swap"
    packages { sol: "platform/main.roc" }
    imports [ sol.Account, sol.Token, sol.log ]
    provides [ main ] to sol

swap : Account, U64 -> Result Account [InsufficientFunds]
swap = \account, amount ->
    if account.balance >= amount then
        account
        |> Account.decrementBalance amount
        |> Ok
    else
        Err InsufficientFunds

main : Context -> Result {} [SwapError Str]
main = \ctx ->
    when ctx.instruction is
        Swap { amount } ->
            ctx.accounts.user
            |> swap amount
            |> Result.map \newAccount ->
                sol.saveAccount! ctx.accounts.user newAccount
                log! "Swap completed: {} tokens", amount
                
        _ -> Err (SwapError "Unknown instruction")
```

## 项目优势

1. **开发效率**：函数式编程范式大幅简化复杂逻辑
2. **性能保证**：Perceus 确保零拷贝优化
3. **类型安全**：编译时捕获大部分错误
4. **生态兼容**：完全兼容现有 Solana 生态系统

## 目标用户

- 熟悉函数式编程的开发者
- 追求代码质量的团队
- 需要高性能的 DeFi 项目
- 教育机构（Roc 比 Rust 更易学）

## 项目状态

🚧 **开发中** - 核心功能实现中，欢迎贡献！

### 已完成
- [x] 技术可行性验证
- [x] 架构设计
- [x] 依赖 SDK 选型（solana-sdk-zig）

### 进行中
- [ ] Zig Host 基础实现
- [ ] Roc Platform 类型定义
- [ ] 构建系统集成

### 计划中
- [ ] 示例程序
- [ ] 开发工具
- [ ] 文档完善