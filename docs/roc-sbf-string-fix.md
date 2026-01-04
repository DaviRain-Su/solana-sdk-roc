# Roc SBF 字符串操作修复指南

> 本文档记录了在 Roc 编译器中修复 SBF (Solana BPF) 目标的字符串操作问题的完整方案。
> 当重新拉取 Roc 源码后，需要重新应用这些修改。

## 问题描述

### 症状

使用 Roc 的字符串插值功能时，编译失败：

```roc
app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 10
    result = fib n
    "Fib(10) = $(Num.to_str result)"  # 字符串插值导致编译失败
```

### 错误信息

```
LLVM error: Call parameter type does not match function signature!
ptr %"#arg1"
 %str.RocStr = type { ptr, i64, i64 }
 %call_builtin = call %str.RocStr @roc_builtins.str.concat(ptr %"#arg1", ptr %"#arg2")
```

## 根本原因分析

### ABI 调用约定差异

Roc 编译器的 LLVM 代码生成针对不同架构使用不同的调用约定：

| 架构 | 参数传递方式 | 返回值方式 |
|------|-------------|-----------|
| x86_64 / aarch64 | 指针 (ptr) | sret (通过指针返回) |
| SBF (Solana) | **结构体值** | **直接返回结构体** |

### 问题所在

1. **函数声明** (Zig builtins): 
   ```llvm
   %str.RocStr @roc_builtins.str.concat(%str.RocStr %0, %str.RocStr %1)
   ```
   期望接收结构体值，返回结构体值。

2. **函数调用** (Roc 编译器生成):
   ```llvm
   @roc_builtins.str.concat(ptr %"#arg1", ptr %"#arg2")
   ```
   传递的是指针！

### 涉及的代码路径

```
call_str_bitcode_fn()
  └── pass_string_to_zig_64bit()  # 返回指针
  └── call_and_load_64bit()       # 处理返回值
```

## 解决方案

### 修改策略

对于 SBF 目标：
1. **参数传递**: 从指针加载结构体值，传递值而非指针
2. **返回值处理**: 直接接收返回的结构体值，存储到 alloca

### 需要修改的文件

```
roc-source/crates/compiler/gen_llvm/src/llvm/bitcode.rs
```

## 具体代码修改

### 修改 1: `call_str_bitcode_fn` 函数 (约第 1158 行)

**原代码:**
```rust
X86_64 | Aarch64 | Sbf => {
    let capacity = other_arguments.len() + strings.len() + returns.additional_arguments();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    let return_value = returns.return_value_64bit(env, &mut arguments);

    for string in strings {
        arguments.push(pass_string_to_zig_64bit(env, *string).into());
    }

    arguments.extend(other_arguments);

    return_value.call_and_load_64bit(env, &arguments, fn_name)
}
```

**修改后:**
```rust
X86_64 | Aarch64 | Sbf => {
    let is_sbf = env.target.architecture() == Sbf;
    let capacity = other_arguments.len() + strings.len() + returns.additional_arguments();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    let return_value = returns.return_value_64bit(env, &mut arguments);

    for string in strings {
        let str_ptr = pass_string_to_zig_64bit(env, *string);
        if is_sbf {
            // SBF: load struct value from pointer (builtins expect by-value args)
            let str_type = super::convert::zig_str_type(env);
            let str_value = env.builder.new_build_load(str_type, str_ptr, "load_str");
            arguments.push(str_value);
        } else {
            // x86_64/aarch64: pass pointer directly (sret convention)
            arguments.push(str_ptr.into());
        }
    }

    arguments.extend(other_arguments);

    return_value.call_and_load_64bit(env, &arguments, fn_name)
}
```

### 修改 2: `call_void_list_bitcode_fn` 函数 (约第 1223 行)

**原代码:**
```rust
X86_64 | Aarch64 | Sbf => {
    let capacity = other_arguments.len() + lists.len();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    for list in lists {
        arguments.push(pass_list_to_zig_64bit(env, (*list).into()).into());
    }

    arguments.extend(other_arguments);

    call_void_bitcode_fn(env, &arguments, fn_name);
}
```

**修改后:**
```rust
X86_64 | Aarch64 | Sbf => {
    let is_sbf = env.target.architecture() == Sbf;
    let capacity = other_arguments.len() + lists.len();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    for list in lists {
        let list_ptr = pass_list_to_zig_64bit(env, (*list).into());
        if is_sbf {
            let list_type = super::convert::zig_list_type(env);
            let list_value = env.builder.new_build_load(list_type, list_ptr, "load_list");
            arguments.push(list_value);
        } else {
            arguments.push(list_ptr.into());
        }
    }

    arguments.extend(other_arguments);

    call_void_bitcode_fn(env, &arguments, fn_name);
}
```

### 修改 3: `call_list_bitcode_fn` 函数 (约第 1275 行)

**原代码:**
```rust
X86_64 | Aarch64 | Sbf => {
    let capacity = other_arguments.len() + lists.len() + returns.additional_arguments();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    let return_value = returns.return_value_64bit(env, &mut arguments);

    for list in lists {
        arguments.push(pass_list_to_zig_64bit(env, (*list).into()).into());
    }

    arguments.extend(other_arguments);

    return_value.call_and_load_64bit(env, &arguments, fn_name)
}
```

**修改后:**
```rust
X86_64 | Aarch64 | Sbf => {
    let is_sbf = env.target.architecture() == Sbf;
    let capacity = other_arguments.len() + lists.len() + returns.additional_arguments();
    let mut arguments: Vec<BasicValueEnum> = Vec::with_capacity_in(capacity, env.arena);

    let return_value = returns.return_value_64bit(env, &mut arguments);

    for list in lists {
        let list_ptr = pass_list_to_zig_64bit(env, (*list).into());
        if is_sbf {
            let list_type = super::convert::zig_list_type(env);
            let list_value = env.builder.new_build_load(list_type, list_ptr, "load_list");
            arguments.push(list_value);
        } else {
            arguments.push(list_ptr.into());
        }
    }

    arguments.extend(other_arguments);

    return_value.call_and_load_64bit(env, &arguments, fn_name)
}
```

### 修改 4: `call_and_load_64bit` 函数 (约第 837 行)

这个修改处理返回值 - 对于 SBF，函数直接返回结构体值而非通过 sret 指针。

**在函数开头添加 SBF 检测:**
```rust
fn call_and_load_64bit<'a, 'env>(
    &self,
    env: &Env<'a, 'ctx, 'env>,
    arguments: &[BasicValueEnum<'ctx>],
    fn_name: &str,
) -> BasicValueEnum<'ctx> {
    // SBF builtins return structs by value, not via sret pointer
    let is_sbf = env.target.architecture() == roc_target::Architecture::Sbf;

    match self {
        BitcodeReturnValue::List(result) => {
            if is_sbf {
                // SBF: function returns struct by value, skip sret pointer argument
                let args_without_sret = &arguments[1..]; // Skip the sret pointer
                let value = call_bitcode_fn(env, args_without_sret, fn_name);
                // Store the returned struct into the alloca
                env.builder.new_build_store(*result, value);
                env.builder
                    .new_build_load(zig_list_type(env), *result, "load_list")
            } else {
                call_void_bitcode_fn(env, arguments, fn_name);
                env.builder
                    .new_build_load(zig_list_type(env), *result, "load_list")
            }
        }
        BitcodeReturnValue::Str(result) => {
            if is_sbf {
                // SBF: function returns struct by value, skip sret pointer argument
                let args_without_sret = &arguments[1..]; // Skip the sret pointer
                let value = call_bitcode_fn(env, args_without_sret, fn_name);
                // Store the returned struct into the alloca
                env.builder.new_build_store(*result, value);
                // we keep a string in the alloca
                (*result).into()
            } else {
                call_void_bitcode_fn(env, arguments, fn_name);
                // we keep a string in the alloca
                (*result).into()
            }
        }
        BitcodeReturnValue::Basic => call_bitcode_fn(env, arguments, fn_name),
    }
}
```

## Host 端修改

### src/host.zig

Roc builtins 在 SBF 目标上需要 `memcpy_c` 和 `memset_c` 函数。在 `host.zig` 中添加：

```zig
pub export fn memcpy_c(dest: [*]u8, src: [*]const u8, count: usize) callconv(.c) [*]u8 {
    @memcpy(dest[0..count], src[0..count]);
    return dest;
}

pub export fn memset_c(dest: [*]u8, val: i32, count: usize) callconv(.c) [*]u8 {
    @memset(dest[0..count], @intCast(val));
    return dest;
}
```

## 构建步骤

### 1. 编译修改后的 Roc 编译器

```bash
cd roc-source
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli
```

### 2. 构建 Roc 程序

```bash
cd /path/to/solana-sdk-roc
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc
```

### 3. 部署到 Solana

```bash
solana program deploy zig-out/lib/roc-hello.so
```

## 验证

### 测试程序 (test-roc/fib_dynamic.roc)

```roc
app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 10
    result = fib n
    "Fib(10) = $(Num.to_str result)"

fib : U64 -> U64
fib = \num ->
    if num <= 1 then
        num
    else
        fib (num - 1) + fib (num - 2)
```

### 预期输出

```
Program log: Fib(10) = 55
Program consumed 2339 of 200000 compute units
Program success
```

## 快速应用补丁

### 方法 1: 使用 Git Patch (推荐)

```bash
# 进入 Roc 源码目录
cd roc-source

# 应用补丁
git apply ../docs/roc-sbf-string-fix.patch

# 验证修改
git diff crates/compiler/gen_llvm/src/llvm/bitcode.rs
```

### 方法 2: 手动应用

如果 patch 因版本差异无法直接应用，参考上面的"具体代码修改"部分手动编辑。

### 重新拉取 Roc 代码后的步骤

```bash
# 1. 拉取最新 Roc 代码
cd roc-source
git pull origin main

# 2. 尝试应用补丁
git apply ../docs/roc-sbf-string-fix.patch

# 3. 如果有冲突，手动解决并参考文档修改

# 4. 重新编译
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli

# 5. 测试
cd ..
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc
```

## 相关文件

| 文件 | 用途 |
|------|------|
| `roc-source/crates/compiler/gen_llvm/src/llvm/bitcode.rs` | LLVM 代码生成 - 需要修改 |
| `roc-source/crates/compiler/builtins/bitcode/src/utils.zig` | Roc builtins - 声明了 memcpy_c |
| `src/host.zig` | Solana host - 需要导出 memcpy_c |

## 技术细节

### 为什么 SBF 不同？

SBF (Solana BPF) 是 Solana 的自定义虚拟机目标。它的调用约定与 x86_64/aarch64 不同：

1. **无 sret 约定**: SBF 不使用隐藏的返回指针参数
2. **结构体按值传递**: 小结构体直接通过寄存器传递
3. **Zig 编译的 builtins**: Solana 的 Zig SDK 编译的函数期望这种约定

### 调用约定对比

```
x86_64 调用 str.concat:
  %result_alloca = alloca %str.RocStr
  call void @str.concat(%str.RocStr* sret %result_alloca, %str.RocStr* %arg1, %str.RocStr* %arg2)
  ; 结果在 %result_alloca 中

SBF 调用 str.concat:
  %arg1_val = load %str.RocStr, %str.RocStr* %arg1_ptr
  %arg2_val = load %str.RocStr, %str.RocStr* %arg2_ptr
  %result = call %str.RocStr @str.concat(%str.RocStr %arg1_val, %str.RocStr %arg2_val)
  ; 结果直接在 %result 中
```

## 版本信息

- Roc: 开发版本 (基于 2025-01 主分支)
- LLVM: 18.x
- solana-zig: 0.15.2
- 修复日期: 2025-01-04

## 参考链接

- [Roc 编译器源码](https://github.com/roc-lang/roc)
- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)
- [Solana BPF 文档](https://docs.solana.com/developing/on-chain-programs/developing-rust)
