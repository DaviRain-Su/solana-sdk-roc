# Roc on Solana 平台

使用 Zig 在 Solana 区块链上编写智能合约，为未来 Roc 语言集成做准备。

## 项目状态

**当前版本**: v0.1.0 ✅

- ✅ Zig 宿主实现 (使用 solana-program-sdk-zig)
- ✅ SBF 字节码生成和链接 (使用 solana-zig-bootstrap)
- ✅ 部署到本地测试网
- ✅ 程序成功调用并输出日志
- ⏳ Roc 语言集成

## 快速开始

### 前置条件

```bash
# solana-zig-bootstrap (已包含在 solana-zig/ 目录)
# 这是支持 SBF 目标的修改版 Zig 0.15.2
# 来源: https://github.com/joncinque/solana-zig-bootstrap

# Solana CLI
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
```

### 构建和部署

**重要**: 必须使用 `./solana-zig/zig` 而不是系统 zig！

```bash
# 运行测试
./solana-zig/zig build test

# 构建 Solana 程序
./solana-zig/zig build solana

# 或者直接 (默认构建 solana)
./solana-zig/zig build

# 启动本地验证器 (另一个终端)
solana-test-validator

# 部署
solana config set --url localhost
solana airdrop 2
solana program deploy zig-out/lib/roc-hello.so
```

### 验证结果

程序调用后输出：
```
Program log: Hello Roc on Solana!
Program consumed 105 of 200000 compute units
Program success
```

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│              solana-zig-bootstrap (./solana-zig/zig)            │
│                  Zig 0.15.2 + 原生 SBF 目标                      │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────┐
│         src/host.zig                │ ← Zig 宿主
│   entrypoint → sol_log              │
│   roc_alloc, roc_panic, etc.        │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│    vendor/solana-program-sdk-zig    │ ← Solana SDK
│   (allocator, log, syscalls)        │
└─────────────────────────────────────┘
```

### 编译流程

```
src/host.zig
    ↓ ./solana-zig/zig build (sbf-solana 目标)
zig-out/lib/roc-hello.so (Solana SBF 程序)
    ↓ solana program deploy
链上程序
```

**注意**: 新架构不再需要 sbpf-linker！solana-zig 原生支持 SBF 目标。

## 项目结构

```
roc-on-solana/
├── solana-zig/               # solana-zig-bootstrap (Zig 0.15.2 + SBF)
│   └── zig                   # 编译器可执行文件
├── src/
│   └── host.zig              # Zig 宿主实现
├── platform/
│   └── main.roc              # Roc 平台定义 (预留)
├── examples/
│   └── hello-world/
│       └── app.roc           # Roc 示例 (预留)
├── vendor/
│   └── solana-program-sdk-zig/  # Solana SDK
├── roc-source/               # Roc 编译器源码 (待用 solana-zig 编译)
├── docs/
│   ├── architecture.md       # 架构文档
│   ├── build-integration.md  # 构建集成文档
│   └── new-architecture-plan.md  # 新架构规划
├── stories/
│   ├── v0.1.0-hello-world.md # v0.1.0 Story
│   └── v0.2.0-roc-integration.md # v0.2.0 Story
├── build.zig                 # 构建配置
└── build.zig.zon             # 依赖配置
```

## 构建命令

| 命令 | 说明 |
|------|------|
| `./solana-zig/zig build test` | 运行单元测试 |
| `./solana-zig/zig build solana` | 构建 Solana 程序 (.so) |
| `./solana-zig/zig build` | 默认构建 (同 solana) |

## 技术细节

### 为什么使用 solana-zig？

标准 Zig 编译器不支持 Solana 的 SBF (Solana BPF) 目标。`solana-zig-bootstrap` 是修改版的 Zig，添加了：

- `sbf` CPU 架构支持
- `solana` 操作系统目标
- 原生 SBF 链接器支持

这消除了对 `sbpf-linker` 的依赖，简化了构建流程。

### Roc 运行时接口

`host.zig` 实现了 Roc 需要的运行时函数：

- `roc_alloc` - 内存分配 (使用 SDK allocator)
- `roc_realloc` - 内存重分配
- `roc_dealloc` - 内存释放
- `roc_panic` - 恐慌处理 (输出到日志)
- `roc_dbg` - 调试输出
- `roc_memset` / `roc_memcpy` - 内存操作

### Solana SDK 集成

使用 `solana-program-sdk-zig` 提供：
- `sdk.allocator.allocator` - SBF 堆分配器 (32KB 限制)
- `sdk.log.log()` - Solana 日志输出
- `sdk.syscalls` - Solana 系统调用

## 下一步计划 (v0.2.0)

- [ ] 使用 solana-zig 重新编译 Roc 编译器
- [ ] 集成 Roc 编译器 LLVM 输出
- [ ] 实现 Roc 效果到 Solana syscalls 映射
- [ ] 支持账户操作和 CPI
- [ ] 完整的 Roc 程序示例

## 相关资源

- [Roc 语言](https://www.roc-lang.org/)
- [Solana 文档](https://docs.solana.com/)
- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)
- [solana-program-sdk-zig](https://github.com/joncinque/solana-program-sdk-zig)

## 许可证

MIT
