# Roc on Solana 架构文档

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                       Roc 源代码 (.roc)                          │
│                                                                   │
│  app [main] { pf: platform "platform/main.roc" }                 │
│  main : Str                                                       │
│  main = "Fib(10) = $(Num.to_str (fib 10))"                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Roc 编译器 (修改版)                               │
│                                                                   │
│  - Cargo 编译: --features target-bpf                             │
│  - LLVM 18 后端                                                   │
│  - SBF ABI 修复 (字符串/列表传递)                                 │
│  - 输出: LLVM Bitcode (.o)                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 solana-zig (0.15.2)                              │
│                                                                   │
│  - 原生 SBF 目标支持                                             │
│  - build-obj: LLVM BC → SBF Object                               │
│  - build-lib: 链接生成 .so                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Solana SBF 程序 (.so)                            │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐      │
│  │  roc_app.o  │  │  host.zig   │  │  solana-program-sdk │      │
│  │  (Roc 逻辑) │  │  (胶水代码) │  │  (Solana SDK)       │      │
│  └─────────────┘  └─────────────┘  └─────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Solana 区块链                                 │
│                                                                   │
│  solana program deploy → 执行                                     │
└─────────────────────────────────────────────────────────────────┘
```

## 组件说明

### 1. Roc 编译器 (修改版)

**位置**: `roc-source/`

**修改内容**:
- 添加 `target-bpf` Cargo feature
- 修复 SBF 目标的 LLVM 三元组 (`sbf-solana-solana`)
- 修复字符串/列表 ABI (参数传值，返回值直接返回)
- 避免 SBF 不支持的 LLVM 内联函数

**编译命令**:
```bash
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli
```

### 2. solana-zig

**位置**: `solana-zig/`

**来源**: [joncinque/solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)

**作用**:
- 提供支持 SBF 目标的 Zig 编译器
- 将 LLVM bitcode 编译为 SBF 目标代码
- 链接生成最终的 Solana 程序

### 3. Host (host.zig)

**位置**: `src/host.zig`

**职责**:
- Solana 程序入口点 (`entrypoint`)
- Roc 内存管理函数 (`roc_alloc`, `roc_dealloc`, `roc_realloc`)
- 辅助函数 (`roc_panic`, `roc_dbg`, `memcpy_c`, `memset_c`)
- RocStr 解码 (支持 SSO)

### 4. Solana SDK

**位置**: `vendor/solana-program-sdk-zig/`

**提供**:
- `sdk.allocator` - SBF 堆分配器 (32KB 限制)
- `sdk.log` - Solana 日志输出
- `sdk.syscalls` - Solana 系统调用

## 数据流

### 编译时

```
Roc 源码 (.roc)
    │ [roc build --target sbf --no-link]
    ▼
LLVM Bitcode (.o)
    │ [cp .o .bc]
    ▼
LLVM Bitcode (.bc)
    │ [solana-zig build-obj -target sbf-solana]
    ▼
SBF Object (roc_app.o)
    │ [solana-zig build-lib]
    ▼
Solana 程序 (.so)
```

### 运行时

```
Solana 调用 entrypoint()
    │
    ▼
Host 调用 roc__mainForHost_1_exposed_generic(&result)
    │
    ▼
Roc 代码执行 (可能调用 roc_alloc, roc_panic)
    │
    ▼
Host 解码 RocStr，调用 sdk.log.log()
    │
    ▼
返回 0 (成功)
```

## RocStr 内存布局

```
64-bit 系统上的 RocStr (24 字节，带 SSO):

堆字符串 (len > 23):
┌──────────────┬──────────────┬──────────────┐
│ ptr (8字节)  │ len (8字节)  │ cap (8字节)  │
└──────────────┴──────────────┴──────────────┘

小字符串 (len <= 23):
┌──────────────────────────────────────────────┬───────┐
│          内联字符数据 (最多 23 字节)          │SSO|len│
└──────────────────────────────────────────────┴───────┘

SSO 标志: 第三个 u64 的最高位 (1 = 小字符串)
长度: bits 56-62
```

## 限制

| 限制 | 值 |
|------|------|
| 堆内存 | 32 KB |
| 栈深度 | 4 KB |
| 计算单元 | 200,000 CU |
| 程序大小 | 10 MB |

## 文件结构

```
solana-sdk-roc/
├── solana-zig/              # solana-zig-bootstrap
├── roc-source/              # Roc 编译器源码 (需修改)
├── src/host.zig             # Solana Host
├── vendor/solana-program-sdk-zig/
├── test-roc/                # 测试 Roc 程序
├── docs/
│   ├── journey-from-zero-to-success.md  # 完整历程
│   ├── roc-build-guide.md               # 编译指南
│   ├── roc-sbf-complete.md              # 修改说明
│   └── roc-sbf-complete.patch           # 完整补丁
├── build.zig
└── build.zig.zon
```
