# Roc on Solana 平台

使用 [Roc](https://www.roc-lang.org/) 编写 Solana 智能合约，这是一种快速、友好的函数式语言。该平台通过 Roc 的创新 Perceus 算法实现函数式编程，同时在 Solana 上保持高性能。

## 🚀 Roc on Solana 是什么？

Roc 是一种编译到机器码的函数式编程语言，具有：

- **Perceus 算法**：引用计数加就地更新，实现 GC 免费性能
- **平台架构**：解耦语言核心，允许自定义后端
- **强类型系统**：编译时保证，具有优秀的人机工程学

与 Solana 的高性能运行时结合，Roc 为智能合约开发提供了一个引人注目的 Rust 替代方案。

## 🏗️ 架构

该平台使用三层架构：

1. **Zig SDK 层**：[solana-program-sdk-zig](https://github.com/DaviRain-Su/solana-program-sdk-zig) 处理低级 Solana 操作
2. **宿主胶水层**：Zig 代码在 Roc 和 Solana 数据格式之间转换
3. **Roc 平台层**：纯函数式接口用于合约开发

```
Roc 合约（函数式）
    ↓ 效果
宿主胶水（转换）
    ↓ SDK 调用
Zig SDK（Solana 核心）
```

## 📋 先决条件

- [Zig](https://ziglang.org/) 0.15.x
- [Roc](https://www.roc-lang.org/) 编译器，具有 LLVM 后端
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools) 用于部署

## 🏁 快速开始

### 1. 克隆和设置

```bash
git clone https://github.com/your-org/roc-solana-platform
cd roc-solana-platform

# 初始化 Zig SDK 子模块
git submodule update --init --recursive
```

### 2. 构建 Hello World 示例

```bash
cd examples/hello-world
zig build
```

### 3. 部署到 Devnet

```bash
solana config set --url devnet
solana program deploy zig-out/lib/your_contract.so
```

## 📖 示例合约

以下是一个简单的代币转账合约，用 Roc 编写：

```elm
app "token-transfer"
    packages { sol: "platform/main.roc" }
    imports [ sol.{ Context, Account, log, transfer } ]
    provides [ main ] to sol

main : Context -> Result {} [Error Str]
main = \ctx ->
    when ctx.accounts is
        [sender, receiver, ..] ->
            if sender.is_signer then
                transfer sender.key receiver.key 1000
                log "Transfer successful"
                Ok {}
            else
                Err "Sender must be signer"
        _ -> Err "Expected at least 2 accounts"
```

与等效的 Rust/Anchor 代码相比，Roc 更简洁易读！

## 🔧 开发

### 项目结构

```
my-roc-solana-project/
├── platform/          # Roc 平台定义
├── src/              # Zig 宿主胶水代码
├── examples/         # 示例合约
├── docs/             # 文档
└── stories/          # 开发路线图
```

### 构建合约

1. **编写合约** 在 `app.roc` 中
2. **定义平台接口** 在 `platform/main.roc` 中
3. **实现胶水代码** 在 `src/effects.zig` 中
4. **使用 Zig 构建**：`zig build`

### 测试

```bash
# 运行 Zig 测试
zig build test

# 运行集成测试（需要 Solana）
zig build test-integration
```

## 🎯 主要特性

- **函数式编程**：纯函数，默认不变性
- **类型安全**：编译时保证防止运行时错误
- **性能**：零成本抽象，直接内存控制
- **开发者体验**：优秀错误消息，快速编译
- **互操作性**：无缝调用现有 Solana 程序

## 📚 文档

- [架构概述](docs/architecture.md)
- [项目结构](docs/project-structure.md)
- [构建集成](docs/build-integration.md)
- [挑战与解决方案](docs/challenges-solutions.md)

## 🗺️ 路线图

参见 [ROADMAP.md](ROADMAP.md) 了解计划特性和里程碑。

### 当前状态

- ✅ 基本平台架构
- ✅ 内存管理集成
- ✅ 简单日志效果
- 🚧 代币转账操作
- 📋 跨程序调用
- 📋 程序派生地址

## 🤝 贡献

此项目遵循 [AGENTS.md](AGENTS.md) 中的 AI 辅助开发规范。

1. 检查 [ROADMAP.md](ROADMAP.md) 和 [stories/](stories/) 中的当前任务
2. 遵循开发工作流：文档 → 代码 → 测试 → 文档
3. 确保所有测试通过：`zig build test`

## 📄 许可证

MIT 许可证 - 参见 [LICENSE](LICENSE) 获取详情。

## 🙏 致谢

- [Roc 语言](https://www.roc-lang.org/) 为出色的函数式编程体验
- [Solana](https://solana.com/) 为高性能区块链平台
- [solana-program-sdk-zig](https://github.com/DaviRain-Su/solana-program-sdk-zig) 为 Zig SDK 基础
- [Zig](https://ziglang.org/) 为系统编程语言

## ⚠️ 免责声明

这是实验性软件。使用需自担风险。智能合约处理真实价值 - 彻底测试和审计至关重要。

---

**"如果 Roc 能在 Solana 上运行，那将是区块链函数式编程的游戏规则改变者。"**

开始使用 Roc 构建智能合约的未来！🚀