# Roc on Solana 平台

使用 Zig 在 Solana 区块链上编写智能合约，为未来 Roc 语言集成做准备。

## 项目状态

**当前版本**: v0.1.0 ✅

- ✅ Zig 宿主实现 (使用 solana-program-sdk-zig)
- ✅ BPF 字节码生成和链接
- ✅ 部署到本地测试网
- ✅ 程序成功调用并输出日志
- ⏳ Roc 语言集成

## 快速开始

### 前置条件

```bash
# Zig 0.15+
# https://ziglang.org/download/

# LLVM 18
sudo apt install llvm-18 llvm-18-dev

# sbpf-linker
cargo install --git https://github.com/blueshift-gg/sbpf-linker.git

# Solana CLI
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
```

### 构建和部署

```bash
# 运行测试
zig build test

# 构建 Solana 程序
zig build solana

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
    ↓ zig build solana (bpfel-freestanding)
zig-out/lib/roc-hello.bc (LLVM bitcode)
    ↓ sbpf-linker
zig-out/lib/roc-hello.so (Solana eBPF)
    ↓ solana program deploy
链上程序
```

## 项目结构

```
roc-on-solana/
├── src/
│   └── host.zig              # Zig 宿主实现
├── platform/
│   └── main.roc              # Roc 平台定义 (预留)
├── examples/
│   └── hello-world/
│       └── app.roc           # Roc 示例 (预留)
├── vendor/
│   └── solana-program-sdk-zig/  # Solana SDK
├── scripts/
│   ├── deploy.sh             # 部署脚本
│   └── invoke.sh             # 调用脚本
├── stories/
│   └── v0.1.0-hello-world.md # 开发 Story
├── build.zig                 # 构建配置
└── build.zig.zon             # 依赖配置
```

## 构建命令

| 命令 | 说明 |
|------|------|
| `zig build test` | 运行单元测试 |
| `zig build solana` | 构建 Solana 程序 (.so) |
| `zig build` | 默认构建 (同 solana) |

## 技术细节

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
- `sdk.allocator.allocator` - BPF 堆分配器 (32KB 限制)
- `sdk.log.log()` - Solana 日志输出
- `sdk.syscalls` - Solana 系统调用

## 下一步计划

- [ ] 集成 Roc 编译器 LLVM 输出
- [ ] 实现 Roc 效果到 Solana syscalls 映射
- [ ] 支持账户操作和 CPI
- [ ] 完整的 Roc 程序示例

## 相关资源

- [Roc 语言](https://www.roc-lang.org/)
- [Solana 文档](https://docs.solana.com/)
- [solana-program-sdk-zig](https://github.com/joncinque/solana-program-sdk-zig)

## 许可证

MIT
