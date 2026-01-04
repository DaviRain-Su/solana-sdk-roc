# Roc on Solana: 从零到成功的完整历程

> 本文档记录了使 Roc 语言成功编译到 Solana SBF 目标的完整过程，包括遇到的挑战、尝试的方案、最终的解决方案。

## 目录

1. [项目目标](#项目目标)
2. [技术背景](#技术背景)
3. [探索历程](#探索历程)
4. [最终解决方案](#最终解决方案)
5. [关键修复详解](#关键修复详解)
6. [验证结果](#验证结果)
7. [经验总结](#经验总结)

---

## 项目目标

**目标**: 使用 Roc 函数式编程语言编写 Solana 智能合约。

**为什么选择 Roc**:
- Perceus 引用计数内存管理，无 GC 停顿
- 纯函数式语言，适合确定性执行
- Platform 架构允许自定义运行时
- 编译到 LLVM，理论上可支持任何 LLVM 目标

**挑战**: 
- Roc 编译器不原生支持 Solana 的 SBF (Solana BPF) 目标
- SBF 是特殊的 eBPF 变体，有独特的 ABI 和限制

---

## 技术背景

### Solana SBF 是什么

SBF (Solana BPF) 是 Solana 区块链的程序执行格式：
- 基于 eBPF 的 64 位 RISC 指令集
- 有限的系统调用 (syscalls)
- 32KB 堆内存限制
- 200,000 计算单元限制
- 4KB 栈深度限制

### 编译链要求

```
源代码 → LLVM IR → LLVM Bitcode → SBF Object → ELF .so
```

需要支持 SBF 目标的 LLVM 后端。

### 工具链现状

| 工具 | SBF 支持 |
|------|---------|
| 标准 LLVM | ❌ 无 |
| Solana LLVM Fork | ✅ 有 |
| 标准 Zig | ❌ 无 |
| solana-zig-bootstrap | ✅ 有 |
| 标准 Roc | ❌ 无 |

---

## 探索历程

### 阶段 1: 初始尝试 - sbpf-linker 方案 (失败)

**思路**: 使用 Roc 编译到 `bpfel-freestanding` 目标，然后用 `sbpf-linker` 转换。

```
Roc → bpfel-freestanding LLVM BC → sbpf-linker → SBF .so
```

**结果**: ❌ 失败
- LLVM 版本不匹配 (Roc 用 LLVM 18, sbpf-linker 用不同版本)
- 链接错误，重定位失败
- sbpf-linker 对多文件支持差

### 阶段 2: 探索 - Solana LLVM 重编译 Roc (部分成功)

**思路**: 用 Solana 的 LLVM Fork 重编译 Roc 编译器。

**发现**:
- Solana LLVM Fork 是 LLVM 20.x，Roc 需要 LLVM 18.x
- C++ ABI 不兼容
- 编译成功但链接失败

**结果**: ❌ 失败，但获得了重要信息

### 阶段 3: 发现 solana-zig-bootstrap (突破)

**发现**: `solana-zig-bootstrap` 项目提供了支持 SBF 目标的 Zig 编译器。

**关键认识**:
- solana-zig 原生支持 `sbf-solana` 目标
- 可以直接生成 SBF 可执行文件
- 不需要 sbpf-linker

**新方案**:
```
Roc (修改版) → SBF LLVM BC → solana-zig build-obj → SBF Object
                                    ↓
Zig Host + Solana SDK → solana-zig build-lib → SBF .so
```

### 阶段 4: 修改 Roc 编译器 (成功)

**需要修改 Roc 的原因**:
1. Roc 需要知道如何输出 SBF 目标的 LLVM bitcode
2. Roc 的 builtins (内置函数) 需要兼容 SBF
3. LLVM 代码生成的 ABI 需要适配 SBF

**修改内容** (33 个文件, 1400+ 行):

| 类别 | 修改 |
|------|------|
| 目标定义 | 添加 SBF 目标，正确的 LLVM 三元组 |
| LLVM 代码生成 | 修复 ABI，避免不支持的内联函数 |
| Zig Builtins | 添加 SBF 条件编译，外部函数声明 |
| 构建系统 | 添加 `target-bpf` feature |

---

## 最终解决方案

### 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         开发者                                    │
│                     编写 Roc 代码                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    app.roc (Roc 应用)                            │
│                                                                   │
│  app [main] { pf: platform "platform/main.roc" }                 │
│                                                                   │
│  main : Str                                                       │
│  main = "Fib(10) = $(Num.to_str (fib 10))"                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Roc 编译器 (修改版, Cargo 编译)                       │
│                                                                   │
│  修改内容:                                                        │
│  - target-bpf feature                                            │
│  - SBF 目标定义 (sbf-solana-solana)                              │
│  - LLVM 代码生成 ABI 修复                                         │
│  - Zig builtins SBF 兼容                                         │
│                                                                   │
│  输出: LLVM Bitcode (.o/.bc)                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              solana-zig (0.15.2)                                 │
│                                                                   │
│  1. build-obj: .bc → roc_app.o (SBF 目标代码)                    │
│  2. build-lib: 链接 host.zig + roc_app.o → .so                   │
│                                                                   │
│  来源: github.com/joncinque/solana-zig-bootstrap                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    roc-hello.so                                   │
│                  (Solana SBF 程序)                                │
│                                                                   │
│  包含:                                                            │
│  - Roc 应用逻辑 (roc_app.o)                                       │
│  - Zig Host (entrypoint, 内存管理, syscalls)                     │
│  - Solana SDK (日志, 分配器)                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Solana 区块链                                  │
│                                                                   │
│  solana program deploy roc-hello.so                              │
│  → Program Id: CPXHpK5aQhzvwU1ysw3D7F9VMcdyt7iY2N8eieiVsvbN     │
└─────────────────────────────────────────────────────────────────┘
```

### 工具链要求

| 组件 | 版本 | 用途 |
|------|------|------|
| LLVM | 18.x | Roc 编译器依赖 |
| Rust | 1.70+ | 编译 Roc 编译器 |
| solana-zig | 0.15.2 | SBF 目标编译和链接 |
| Solana CLI | 2.0+ | 部署和测试 |

---

## 关键修复详解

### 修复 1: LLVM 三元组

**问题**: Roc 输出的三元组 Solana LLVM 不识别

**修复**: `src/target/mod.zig`
```zig
// 修改前
.sbfsolana => "sbf-unknown-solana-unknown",

// 修改后
.sbfsolana => "sbf-solana-solana",
```

### 修复 2: memcpy.inline 内联函数

**问题**: SBF 不支持 `llvm.memcpy.inline` 内联函数

**修复**: `crates/compiler/gen_llvm/src/llvm/memcpy.rs`
- 对于 SBF 目标，使用普通 memcpy 调用而非内联函数

### 修复 3: SBF 字符串/列表 ABI (最关键)

**问题**: x86_64 和 SBF 的调用约定不同

| 架构 | 参数传递 | 返回值 |
|------|---------|--------|
| x86_64 | 指针 | sret (通过指针返回) |
| SBF | 结构体值 | 直接返回结构体 |

**修复**: `crates/compiler/gen_llvm/src/llvm/bitcode.rs`
```rust
// 对于 SBF 目标
if is_sbf {
    // 从指针加载结构体值
    let str_value = env.builder.new_build_load(str_type, str_ptr, "load_str");
    arguments.push(str_value);
    
    // 跳过 sret 指针，直接接收返回值
    let args_without_sret = &arguments[1..];
    let value = call_bitcode_fn(env, args_without_sret, fn_name);
}
```

### 修复 4: Builtins 外部函数

**问题**: Zig 的 `@memcpy` 在 SBF 上生成不支持的代码

**修复**: `crates/compiler/builtins/bitcode/src/utils.zig`
```zig
extern fn memcpy_c(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) [*]u8;

pub inline fn memcpy(dest: []u8, src: []const u8) void {
    if (comptime is_solana) {
        _ = memcpy_c(dest.ptr, src.ptr, dest.len);
    } else {
        @memcpy(dest, src);
    }
}
```

**Host 端**: `src/host.zig` 需要导出这些函数
```zig
pub export fn memcpy_c(dest: [*]u8, src: [*]const u8, count: usize) callconv(.c) [*]u8 {
    @memcpy(dest[0..count], src[0..count]);
    return dest;
}
```

---

## 验证结果

### 测试用例

**test-roc/fib_dynamic.roc**:
```roc
app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 10
    result = fib n
    "Fib(10) = $(Num.to_str result)"

fib : U64 -> U64
fib = \num ->
    if num <= 1 then num
    else fib (num - 1) + fib (num - 2)
```

### 编译命令

```bash
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc
```

### 部署和调用

```bash
$ solana program deploy zig-out/lib/roc-hello.so
Program Id: CPXHpK5aQhzvwU1ysw3D7F9VMcdyt7iY2N8eieiVsvbN

$ node scripts/call-program.mjs
Program log: Fib(10) = 55
Program consumed 2339 of 200000 compute units
Program success
```

### 性能数据

| 测试 | 计算单元 | 说明 |
|------|----------|------|
| Hello World | ~127 CU | 简单字符串输出 |
| 递归 Fib(15) | ~20,842 CU | 递归算法 |
| 迭代 Fib(50) | ~831 CU | 迭代算法 |
| 字符串插值 Fib(10) | ~2,339 CU | 递归 + 字符串操作 |

---

## 经验总结

### 成功因素

1. **找到正确的工具链**: solana-zig-bootstrap 是关键突破
2. **理解 ABI 差异**: SBF 的调用约定与 x86_64 不同
3. **逐步调试**: 从简单程序开始，逐步增加复杂度
4. **阅读 LLVM IR**: 分析生成的 IR 帮助定位问题

### 遇到的坑

1. **LLVM 版本地狱**: 不同组件要求不同 LLVM 版本
2. **隐式假设**: Roc 编译器假设所有 64 位目标行为相同
3. **内联函数**: LLVM 内联函数在 SBF 上不可用
4. **文档缺失**: SBF ABI 文档不完整

### 可复用的方法论

1. 先验证工具链可行性
2. 最小化测试用例
3. 对比工作和不工作的 LLVM IR
4. 理解底层 ABI 和调用约定
5. 保持补丁可维护性

---

## 文件清单

### 关键文件

| 文件 | 用途 |
|------|------|
| `docs/roc-sbf-complete.patch` | 完整 Roc 修改补丁 (4600+ 行) |
| `docs/roc-build-guide.md` | 编译指南 |
| `src/host.zig` | Solana 宿主代码 |
| `build.zig` | 构建配置 |

### 补丁应用

```bash
cd roc-source
git apply ../docs/roc-sbf-complete.patch
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli
```

---

## 未来计划

### 短期 (v0.3.0)
- [ ] 账户读取支持
- [ ] 指令数据解析
- [ ] 更多 Solana syscalls

### 中期
- [ ] CPI (跨程序调用)
- [ ] SPL Token 集成
- [ ] PDAs (Program Derived Addresses)

### 长期
- [ ] 上游 PR 到 Roc
- [ ] 独立的 Roc Solana Platform
- [ ] 完整的 DeFi 程序示例

---

*文档更新日期: 2025-01-04*
*状态: v0.2.0 核心功能完成*
