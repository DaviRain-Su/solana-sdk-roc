# Roc SBF 原生目标支持实现

> 时间: 2026-01-04
> 目标: 为 Roc Rust 后端添加原生 SBF (Solana BPF) 目标支持

## 概述

本文档记录了为 Roc 编译器添加原生 SBF 目标的**尝试**过程。

## ⚠️ 重要说明：原生 SBF 目标未完成

### 当前状态总结

| 组件 | 状态 | 说明 |
|------|------|------|
| **Roc 源码修改** | ✅ 已完成 | `roc_target/src/lib.rs` 添加了 Sbf 目标定义 |
| **自编译 Roc** (`roc-source/zig-out/bin/roc`) | 🔴 不可用 | 有 Sbf 修改但语法解析器与主线不兼容 |
| **Nightly Roc** (`roc_nightly-.../roc`) | ✅ 可用 | 生成 x86_64 IR，**无 SBF 支持** |
| **SBF IR 直接输出** | 🔴 不工作 | `--target sbf` 选项无法使用 |

### 原因分析

1. **Roc 源码 SBF 修改存在**: `Architecture::Sbf`, `OperatingSystem::Solana` 已添加
2. **但需要 `target-bpf` Cargo 特性**: 编译时需 `--features target-bpf`
3. **自编译 Roc 语法解析器不兼容**: 与主线 Roc 语法差异太大，无法编译现有代码
4. **Zig 0.15 兼容性问题**: builtins 编译失败

### 实际工作解决方案: Option B+ IR Patching

由于原生 SBF 目标不工作，我们使用 **IR Patching** 作为替代：

```
test-roc/main.roc
    ↓ roc_nightly 编译器 (--emit-llvm-ir)
test-roc/main.ll (target: x86_64-unknown-linux-musl)  ← Roc 输出
    ↓ tools/clean_roc_ir.zig (修改 target triple)
zig-out/roc_clean.ll (target: sbf-unknown-solana)     ← IR Patching
    ↓ solana-zig cc -target sbf-solana
roc_minimal.o (SBF 目标代码)
    ↓ solana-zig build (链接 host.zig)
zig-out/lib/roc-hello.so (Solana 程序)
```

**关键**: Roc 编译器输出 x86_64 IR，我们用工具将其转换为 SBF IR。

## 实现状态

### ⚠️ 源码修改已完成，但无法正常工作

以下修改已添加到 Roc 源码，但由于编译器兼容性问题无法实际使用：

#### 1. roc_target/src/lib.rs - 目标定义
```rust
// 新增:
pub enum OperatingSystem {
    // ...
    Solana,  // ← 新增
}

pub enum Architecture {
    // ...
    Sbf,  // ← 新增 (64-bit 指针宽度)
}

pub enum Target {
    // ...
    Sbf,  // ← 新增
}
```

#### 2. build/src/target.rs - LLVM 三元组
```rust
Target::Sbf => "bpfel-unknown-unknown"  // SBF LLVM 三元组

// LLVM 后端初始化
LlvmTarget::initialize_bpf()

// 架构字符串
Target::Sbf => "bpfel"
```

#### 3. build/Cargo.toml - 特性标志
```toml
[features]
target-bpf = []
```

#### 4. gen_llvm/src/llvm/build.rs - Builtins 引用
```rust
Target::Sbf => {
    include_bytes!("../../../builtins/bitcode/zig-out/builtins-sbf.bc")
}
```

#### 5. builtins/bitcode/build.zig - 条件编译
- 添加 `has_sbf_support` 检查
- 仅在 solana-zig 下编译 SBF 目标
- 系统 zig 不会尝试编译 SBF

#### 6. builtins/bitcode/src/utils.zig - 调用约定
```zig
const has_sbf = @hasField(std.Target.Cpu.Arch, "sbf");

pub const cc: std.builtin.CallingConvention = blk: {
    if (has_sbf and builtin.cpu.arch == .sbf) {
        break :blk .{ .bpf_std = .{} };
    } else if (builtin.target.cCallingConvention()) |c| {
        break :blk c;
    } else {
        break :blk .auto;
    }
};
```

#### 7. builtins/bitcode/src/main.zig - @export 修复
```zig
// Zig 0.15 需要 & 前缀
@export(&func, .{ .name = "...", .linkage = .strong });
```

#### 8. builtins/bitcode/src/sbf_minimal.zig - 最小 SBF Builtins
- 不依赖 std 库的线程/posix 功能
- 仅包含基本数学和内存操作
- 成功编译为 `builtins-sbf.bc` (3.8KB)

### ⚠️ 阻塞问题 (原生 SBF 目标)

#### Roc Builtins Zig 0.15 兼容性

主要 Roc builtins 代码有大量 Zig 0.15 不兼容问题:

| 问题 | 位置 | 说明 |
|------|------|------|
| `.Int` → `.int` | num.zig | @typeInfo 枚举大小写变化 |
| `std.fmt.formatIntBuf` | dec.zig | API 已移除/重命名 |
| `std.mem.split` | str.zig | API 已移除/重命名 |
| Format string `{f}` | dec.zig | 自定义格式需显式指定 |
| Unicode API | str.zig | utf8Decode 签名变化 |

这些是 **上游 Roc 项目的 Zig 版本兼容性问题**，不是我们 SBF 修改引入的。

**结论**: 在 Roc 上游更新 Zig 版本之前，原生 SBF 目标无法完全工作。

### ✅ 工作解决方案: Option B+ IR Patching

由于原生 SBF 目标被阻塞，我们使用 IR Patching 作为替代方案：

#### IR 清理工具 (`tools/clean_roc_ir.zig`)

该工具执行以下转换：

1. **修改 target triple**: `x86_64-unknown-linux-musl` → `sbf-unknown-solana`
2. **修改 data layout**: 适配 SBF 内存模型
3. **提取核心函数**: 保留 `roc__main_for_host_1_exposed_generic` 等必要函数
4. **移除不兼容代码**: 去除 128 位整数运算等 SBF 不支持的操作

#### 验证

```bash
# Roc 原生输出
head -3 test-roc/main.ll
# target triple = "x86_64-unknown-linux-musl"

# 清理后输出
head -3 zig-out/roc_clean.ll
# target triple = "sbf-unknown-solana"
```

### 📁 生成的文件

```
roc-source/crates/compiler/builtins/bitcode/zig-out/
├── builtins-sbf.bc   (3,780 bytes)  ← SBF bitcode
└── builtins-sbf.ll   (4,867 bytes)  ← SBF LLVM IR

生成的 LLVM IR:
- target triple: "sbf-unknown-solana-unknown"
- 函数: roc_builtins.num.{add,sub,mul}_{i64,u64}
- 函数: roc_builtins.utils.{memcpy,memset}
- 函数: roc_builtins.{str,list}.init (占位符)
```

## 构建说明

### 使用 solana-zig 构建 SBF Builtins

```bash
cd roc-source/crates/compiler/builtins/bitcode
/path/to/solana-zig/zig build ir-sbf --release
```

### 系统 zig 行为

使用系统 zig 时，SBF 目标会被自动跳过:

```bash
zig build --help
# 不会显示 ir-sbf 和 sbf-object 步骤
```

## ✅ 部署和验证结果 (2026-01-04)

### 部署成功

**Option B+ IR Patching 管道完整验证通过！**

```bash
# 构建流程
./solana-zig/zig build  # 使用现有 roc_minimal.o 生成 3.3KB 程序

# 部署
solana program deploy zig-out/lib/roc-hello.so
# Program Id: DoqVoBZKrVRzMVPr4kiQETy2zmUC3DDeewZmvHQW9gux

# 调用验证
node scripts/call-program.mjs
# Program log: Fibonacci(15) = 610 - Roc on Solana!
# consumed 121 of 200000 compute units
# Program success
```

### 验证指标

| 指标 | 值 | 状态 |
|------|-----|------|
| 程序大小 | 3.3 KB | ✅ 很小 |
| 计算单元 | 121 | ✅ 极低 |
| 日志输出 | Fibonacci(15) = 610 | ✅ 正确 |
| 部署成功 | DoqVoBZ... | ✅ 通过 |

## 后续工作

### 短期 (已完成)

- ✅ Option B+ 管道完整可工作
- ✅ 部署到本地测试网成功
- ✅ 程序调用验证通过

### 中期 (v0.3.0)

1. 实现账户操作 (读取/写入账户数据)
2. 支持 CPI (跨程序调用)
3. 部署到 devnet/testnet

### 长期 (Roc 上游更新)

等待 Roc 项目更新到 Zig 0.15 后:
1. 重新测试完整编译器构建
2. 验证 `roc build --target sbf` 功能
3. 提交 SBF 目标修改到上游 Roc
4. 添加 SBF 特定优化

## 相关文件

| 文件 | 修改说明 |
|------|---------|
| `roc_target/src/lib.rs` | Target::Sbf 定义 |
| `build/src/target.rs` | LLVM 三元组和初始化 |
| `build/Cargo.toml` | target-bpf 特性 |
| `gen_llvm/src/llvm/build.rs` | builtins-sbf.bc 引用 |
| `builtins/bitcode/build.zig` | 条件 SBF 编译 |
| `builtins/bitcode/src/utils.zig` | bpf_std 调用约定 |
| `builtins/bitcode/src/main.zig` | @export 修复 |
| `builtins/bitcode/src/sbf_minimal.zig` | 最小 SBF builtins |

## 验证命令

```bash
# 检查 SBF builtins 是否生成
ls -la roc-source/crates/compiler/builtins/bitcode/zig-out/builtins-sbf.*

# 检查 LLVM IR 目标三元组
head -5 roc-source/crates/compiler/builtins/bitcode/zig-out/builtins-sbf.ll

# 使用 solana-zig 重建 SBF builtins
cd roc-source/crates/compiler/builtins/bitcode
/path/to/solana-zig/zig build ir-sbf --release
```
