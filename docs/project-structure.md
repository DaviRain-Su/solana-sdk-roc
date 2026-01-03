# Roc on Solana 项目结构

本文档概述了 Roc-Solana 平台项目的目录结构和文件组织，遵循 AGENTS.md 规范。

## 项目概述

Roc-Solana 平台使开发者能够使用 Roc 函数式编程语言编写 Solana 智能合约，利用 Zig SDK 处理底层操作。

## 目录结构

```
my-roc-solana-project/
├── build.zig              # 主要构建脚本（Zig 构建系统）
├── build.zig.zon          # Zig 包依赖项
├── README.md              # 用户文档和入门指南
├── AGENTS.md              # AI 代理规范（继承）
├── ROADMAP.md             # 项目路线图和里程碑
├── CHANGELOG.md           # 版本历史和变更
├── docs/                  # 详细文档
│   ├── architecture.md    # 三层架构说明
│   ├── project-structure.md # 此文件
│   ├── build-integration.md # 构建过程文档
│   ├── challenges-solutions.md # 已知问题和解决方案
│   └── design/            # 设计文档
│       └── platform-design.md
├── src/                   # Zig 源码（宿主层）
│   ├── main.zig           # 入口点和协调逻辑
│   ├── allocator.zig      # 内存管理胶水
│   ├── effects.zig        # 效果处理器（log、transfer 等）
│   └── types.zig          # Zig 端类型定义
├── platform/              # Roc 平台定义
│   ├── main.roc           # 平台接口声明
│   ├── types.roc          # Roc 类型定义（Pubkey、Account 等）
│   └── effects.roc        # 效果声明
├── examples/              # 示例合约
│   ├── hello-world/       # 基本日志示例
│   │   ├── app.roc        # 合约逻辑
│   │   └── build.zig      # 示例特定构建
│   ├── token-swap/        # 代币交换合约
│   └── ...
├── stories/               # 开发故事（per AGENTS.md）
│   ├── v0.1.0-core-platform.md    # 核心平台实现
│   ├── v0.2.0-basic-contracts.md  # 基本合约示例
│   └── v0.3.0-advanced-features.md # CPI、PDA 等
├── tests/                 # 测试套件
│   ├── zig-tests/         # Zig 单元测试
│   ├── roc-tests/         # Roc 逻辑测试
│   └── integration/       # 完整合约测试
├── vendor/                # 外部依赖项
│   └── solana-program-sdk-zig/  # Zig SDK 子模块

├── .gitignore
├── .gitmodules            # Zig SDK 子模块
└── .gitattributes         # Git 属性
```

## 文件用途

### 构建系统
- `build.zig`：主要的构建编排。处理 Roc 编译、Zig 编译和链接。
- `build.zig.zon`：Zig 包的依赖管理。

### 文档（docs/）
- `architecture.md`：三层架构的详细说明。
- `project-structure.md`：目录布局和组织（此文件）。
- `build-integration.md`：Roc 和 Zig 编译集成的方式。
- `challenges-solutions.md`：已知技术挑战和解决方法。

### 源码（src/）
- `main.zig`：Solana 入口点和主协调逻辑。
- `allocator.zig`：实现 Roc 的内存分配接口，使用 Zig SDK。
- `effects.zig`：处理 Roc 效果，通过调用 Zig SDK 函数。
- `types.zig`：Zig 端类型定义，与 Roc 布局匹配。

### 平台层（platform/）
- `main.roc`：定义平台接口并导出可用函数。
- `types.roc`：Roc 类型定义，镜像 Solana 数据结构。
- `effects.roc`：副作用的效果声明（日志、转账等）。

### 示例（examples/）
每个示例都是一个自包含的 Roc 合约，演示特定功能。

### 故事（stories/）
遵循 AGENTS.md 规范，每个版本都有一个故事文件跟踪实现状态。

### 测试（tests/）
- `zig-tests/`：Zig 胶水代码的单元测试。
- `roc-tests/`：Roc 平台函数的测试。
- `integration/`：端到端测试，部署到 Solana devnet。

## 开发工作流

1. **文档先行**：更新 ROADMAP.md 并创建/更新故事文件。
2. **平台开发**：在 platform/ 中实现类型和效果。
3. **胶水代码**：在 src/ 中编写相应的 Zig 实现。
4. **示例**：在 examples/ 中创建示例合约。
5. **测试**：添加测试并验证 `zig build test` 通过。
6. **文档更新**：更新 CHANGELOG.md 和 docs/。

## 构建过程

构建过程涉及：
1. 将 Roc 平台和应用代码编译为 LLVM 位码。
2. 使用 SDK 集成编译 Zig 宿主代码。
3. 将 Roc 和 Zig 链接成 Solana 兼容的 BPF 共享库。
4. 可选：部署到 devnet 进行测试。

有关详细构建说明，请参见 `docs/build-integration.md`。

## 依赖项

- Roc 编译器（具有 LLVM 后端支持）
- Zig 0.15+（具有 BPF 目标支持）
- solana-program-sdk-zig（作为 git 子模块）

## 版本控制

- 对外部依赖使用 git 子模块（Zig SDK）。
- 发布时遵循语义化版本控制。
- 标记与故事完成对应的发布版本。