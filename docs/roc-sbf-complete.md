# Roc SBF 完整修改指南

> 本文档记录了使 Roc 编译器支持 Solana SBF 目标的所有修改。
> 补丁文件: `docs/roc-sbf-complete.patch` (4600+ 行)

## 修改概览

```
33 个文件被修改
1416 行添加
540 行删除
2 个新文件创建
```

## 修改分类

### 1. Rust 编译器核心 (Cargo/LLVM)

| 文件 | 修改内容 |
|------|---------|
| `crates/cli/Cargo.toml` | 添加 `target-bpf` feature |
| `crates/compiler/build/Cargo.toml` | 添加 BPF 相关依赖 |
| `crates/compiler/build/src/program.rs` | SBF 目标的 bitcode 输出支持 |
| `crates/compiler/build/src/target.rs` | SBF 目标定义 |
| `crates/compiler/roc_target/src/lib.rs` | Roc Target 枚举添加 SBF |
| `crates/compiler/builtins/src/bitcode.rs` | Bitcode 路径配置 |
| `crates/glue/src/types.rs` | Glue 类型生成 |

### 2. LLVM 代码生成 (关键修复)

| 文件 | 修改内容 |
|------|---------|
| `crates/compiler/gen_llvm/src/llvm/bitcode.rs` | **SBF 字符串/列表 ABI 修复** |
| `crates/compiler/gen_llvm/src/llvm/build.rs` | LLVM 构建配置 |
| `crates/compiler/gen_llvm/src/llvm/build_str.rs` | 字符串构建 |
| `crates/compiler/gen_llvm/src/llvm/expect.rs` | Expect 处理 |
| `crates/compiler/gen_llvm/src/llvm/lowlevel.rs` | 低级操作 |
| `crates/compiler/gen_llvm/src/llvm/memcpy.rs` | **memcpy 修复 (避免 inline intrinsics)** |
| `crates/compiler/gen_dev/src/object_builder.rs` | 对象文件构建 |

### 3. Zig Builtins (SBF 兼容性)

| 文件 | 修改内容 |
|------|---------|
| `crates/compiler/builtins/bitcode/build.zig` | SBF 目标构建配置 |
| `crates/compiler/builtins/bitcode/src/utils.zig` | **memcpy_c/memset_c 外部函数声明** |
| `crates/compiler/builtins/bitcode/src/str.zig` | 字符串操作 SBF 兼容 |
| `crates/compiler/builtins/bitcode/src/list.zig` | 列表操作 SBF 兼容 |
| `crates/compiler/builtins/bitcode/src/num.zig` | 数值操作 SBF 兼容 |
| `crates/compiler/builtins/bitcode/src/dec.zig` | Decimal 操作 |
| `crates/compiler/builtins/bitcode/src/sort.zig` | 排序操作 |
| `crates/compiler/builtins/bitcode/src/hash.zig` | 哈希操作 |
| `crates/compiler/builtins/bitcode/src/dbg.zig` | 调试函数 |
| `crates/compiler/builtins/bitcode/src/panic.zig` | Panic 处理 |
| `crates/compiler/builtins/bitcode/src/expect.zig` | Expect 处理 |
| `crates/compiler/builtins/bitcode/src/fuzz_sort.zig` | 模糊排序 |
| `crates/compiler/builtins/bitcode/src/main.zig` | 主入口 |
| `crates/compiler/builtins/bitcode/src/sbf_minimal.zig` | **新文件**: SBF 最小运行时 |

### 4. Zig CLI/目标系统

| 文件 | 修改内容 |
|------|---------|
| `build.zig` | 顶层构建配置 |
| `src/target/mod.zig` | **LLVM 三元组: sbf-solana-solana** |
| `src/cli/main.zig` | CLI 入口 |
| `src/cli/builder.zig` | 构建器 |
| `src/cli/linker.zig` | 链接器配置 |
| `src/cli/platform_host_shim.zig` | 平台宿主垫片 |
| `src/interpreter_shim/sbf_stub.zig` | **新文件**: SBF 解释器存根 |

## 关键修复详解

### 修复 1: LLVM 三元组

**文件**: `src/target/mod.zig`

```zig
// 修改前
.sbfsolana => "sbf-unknown-solana-unknown",

// 修改后  
.sbfsolana => "sbf-solana-solana",
```

### 修复 2: SBF 字符串/列表 ABI

**文件**: `crates/compiler/gen_llvm/src/llvm/bitcode.rs`

**问题**: x86_64 使用 sret (指针返回) 约定，SBF 使用值传递/返回

**解决**: 为 SBF 目标:
1. 从指针加载结构体值后传参
2. 跳过 sret 指针参数
3. 直接接收返回的结构体值

### 修复 3: memcpy.inline 内联函数

**文件**: `crates/compiler/gen_llvm/src/llvm/memcpy.rs`

**问题**: SBF 不支持 `llvm.memcpy.inline` 内联函数

**解决**: 对于 SBF 目标使用普通 memcpy 调用

### 修复 4: Builtins 内存函数

**文件**: `crates/compiler/builtins/bitcode/src/utils.zig`

**问题**: SBF 上 `@memcpy` 生成不支持的内联函数

**解决**: 声明外部 `memcpy_c` / `memset_c` 函数，由宿主提供

```zig
extern fn memcpy_c(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) [*]u8;
extern fn memset_c(dest: [*]u8, c: i32, n: usize) callconv(.c) [*]u8;

pub inline fn memcpy(dest: []u8, src: []const u8) void {
    if (comptime is_solana) {
        _ = memcpy_c(dest.ptr, src.ptr, dest.len);
    } else {
        @memcpy(dest, src);
    }
}
```

## 应用补丁

### 方法 1: Git Apply (推荐)

```bash
cd roc-source

# 首先确保工作目录干净
git status

# 如果有未提交的更改，先存储
git stash

# 应用完整补丁
git apply ../docs/roc-sbf-complete.patch

# 检查状态
git status
git diff --stat
```

### 方法 2: 手动合并

如果补丁因版本差异无法直接应用:

```bash
# 尝试 3-way 合并
git apply --3way ../docs/roc-sbf-complete.patch

# 或者逐个文件应用
git apply --reject ../docs/roc-sbf-complete.patch
# 然后手动解决 .rej 文件
```

### 方法 3: 创建分支保存修改

```bash
# 在当前修改基础上创建分支
cd roc-source
git checkout -b sbf-support
git add -A
git commit -m "Add SBF/Solana target support"

# 之后可以通过 cherry-pick 或 rebase 应用到新版本
```

## 编译步骤

### 1. 编译 Roc 编译器

```bash
cd roc-source
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli
```

### 2. 验证

```bash
./target/release/roc version
./target/release/roc --help | grep target
```

### 3. 测试 SBF 编译

```bash
cd /path/to/solana-sdk-roc
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc
```

## 新文件说明

### sbf_minimal.zig

SBF 目标的最小运行时支持，提供基本的系统调用存根。

### sbf_stub.zig

SBF 解释器存根，用于在非 SBF 环境下编译时提供占位实现。

## 依赖关系

```
Roc 编译器 (Rust)
├── roc_target (SBF 目标定义)
├── roc_build (构建配置)
├── roc_gen_llvm (LLVM 代码生成)
│   ├── bitcode.rs (ABI 修复)
│   └── memcpy.rs (内联函数修复)
└── builtins (Zig)
    ├── utils.zig (memcpy_c/memset_c)
    └── *.zig (SBF 兼容性修改)
```

## 测试矩阵

| 测试类型 | 命令 | 预期结果 |
|---------|------|---------|
| Hello World | `./solana-zig/zig build roc -Droc-app=test-roc/simple.roc` | 编译成功 |
| Fibonacci | `./solana-zig/zig build roc -Droc-app=test-roc/fib_iter.roc` | 编译成功 |
| 字符串插值 | `./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc` | 编译成功 |
| 部署测试 | `solana program deploy zig-out/lib/roc-hello.so` | 部署成功 |
| 运行测试 | `node scripts/call-program.mjs` | 输出 "Fib(10) = 55" |

## 常见问题

### Q: 补丁应用失败怎么办?

A: 
1. 检查 Roc 版本是否差异太大
2. 使用 `git apply --reject` 查看哪些部分失败
3. 参考本文档手动修改对应文件

### Q: 编译时报 LLVM 错误怎么办?

A: 
1. 确保 `LLVM_SYS_180_PREFIX` 指向正确的 LLVM 18 安装
2. 确保启用了 `--features target-bpf`

### Q: 运行时报 memcpy_c 未定义怎么办?

A: 确保 `src/host.zig` 中导出了 `memcpy_c` 和 `memset_c` 函数

## 版本信息

- 基于 Roc 版本: 开发版 (2025-01 主分支)
- LLVM 版本: 18.x
- 补丁创建日期: 2025-01-04

## 相关文档

- `docs/roc-build-guide.md` - **完整编译指南 (前置条件、环境配置)**
- `docs/roc-sbf-string-fix.md` - 字符串 ABI 修复详解
- `docs/roc-sbf-native-target.md` - SBF 目标配置
- `docs/architecture.md` - 整体架构
