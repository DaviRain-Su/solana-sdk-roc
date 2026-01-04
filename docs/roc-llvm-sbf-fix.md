# Roc LLVM SBF 目标配置修复方案

> 识别问题日期: 2026-01-04  
> 问题: Roc 的 LLVM 三元组不匹配 Solana LLVM 支持的三元组  
> 状态: 🔧 需要修复

## 问题分析

### 当前配置

在 `roc-source/src/target/mod.zig` 第 183 行：

```zig
.sbfsolana => "sbf-unknown-solana-unknown",
```

### Solana LLVM 支持的目标

根据 Solana Rust 仓库中编译的 LLVM，支持的 SBF 目标三元组是：

```
sbf-solana-solana
sbf-unknown-solana-unknown  (可能也支持)
```

### 关键库验证

从 LLVM 构建的库文件，我们确认 SBF 支持已包含：

- ✅ `libLLVMSBFCodeGen.a` (1.3M) - 代码生成
- ✅ `libLLVMSBFAsmParser.a` (42K) - 汇编解析
- ✅ `libLLVMSBFDesc.a` (122K) - 描述符
- ✅ `libLLVMSBFInfo.a` (6.7K) - 信息

### LLVM 错误消息

```
LLVM error: No available targets are compatible with triple "sbf-solana-solana"
warning: LLVM compilation not ready, falling back to clang
```

这表明 Roc 的 LLVM 后端无法识别三元组，而不是库缺失。

## 根本原因

**关键发现**: Roc 的 LLVM 绑定可能使用的是标准 LLVM 配置，而 Solana LLVM 是修改版本。

虽然 Solana Rust 的 LLVM 子模块支持 SBF 目标，但 Roc 的编译器可能：
1. 使用了与 Solana LLVM 不兼容的 LLVM 版本
2. 使用了不同的三元组格式
3. LLVM 目标三元组注册方式不同

## 修复方案

### 方案 1: 更新三元组格式（推荐）

**修改文件**: `roc-source/src/target/mod.zig`

**第 183 行修改**:

```diff
- .sbfsolana => "sbf-unknown-solana-unknown",
+ .sbfsolana => "sbf-solana-solana",
```

**测试命令**:

```bash
cd roc-source
./zig-out/bin/roc build \
    --target sbfsolana \
    examples/hello-world/app.roc

# 或者直接编译
./zig-out/bin/roc check examples/hello-world/app.roc
```

### 方案 2: 添加备用三元组支持

如果方案 1 不完全工作，可以在 Roc 的后端添加三元组规范化。

**寻找位置**: `roc-source/crates/compiler/gen_llvm/` 或 `roc-source/src/llvm_compile/`

**修改策略**:
1. 找到处理 LLVM 三元组的代码
2. 添加 `sbf-solana-solana` 的规范化映射
3. 或添加 Solana LLVM 的特殊处理

### 方案 3: 使用 LLVM 别名

如果 Solana LLVM 支持多个三元组格式，可以添加别名：

在 Roc 的 LLVM 后端添加：

```zig
// 规范化 Solana 三元组
pub fn normalizeTriple(triple: []const u8) []const u8 {
    if (std.mem.eql(u8, triple, "sbf-unknown-solana-unknown")) {
        return "sbf-solana-solana";
    }
    return triple;
}
```

### 方案 4: 编译期标志指定 LLVM 路径

如果 Roc 已编译的 LLVM 绑定与 Solana LLVM 不兼容，需要使用 Solana LLVM：

```bash
# 重新编译 Roc，使用 Solana LLVM
cd roc-source

export LLVM_SYS_190_PREFIX=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 使用 solana-zig 重新编译（如果 build.zig 支持）
../solana-zig/zig build \
    -Dllvm-path=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 或清除缓存后重新编译
rm -rf .zig-cache zig-out
../solana-zig/zig build
```

## 验证步骤

### 步骤 1: 检查 LLVM 目标支持

```bash
LLVM_PATH=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 列出支持的目标
$LLVM_PATH/bin/llc -version | grep -i sbf

# 或者测试编译
$LLVM_PATH/bin/llc --version | grep Target | grep -i sbf
```

### 步骤 2: 创建简单的 SBF LLVM IR

```llvm
target triple = "sbf-solana-solana"

define void @_start() {
  ret void
}
```

```bash
# 保存为 test.ll
$LLVM_PATH/bin/llc -mtriple=sbf-solana-solana test.ll -o test.o
```

### 步骤 3: 测试 Roc 编译

```bash
cd roc-source

# 在修改后，测试 Roc 编译
./zig-out/bin/roc check examples/hello-world/app.roc

# 如果支持，尝试编译到目标代码
./zig-out/bin/roc build --emit-llvm-ir examples/hello-world/app.roc
```

## LLVM 版本信息

### Roc 使用的 LLVM 版本

```bash
cd roc-source
./zig-out/bin/roc --version

# 查看编译配置
grep -i "llvm" build.zig 2>/dev/null || grep -i "llvm" crates/compiler/build.rs
```

### Solana LLVM 版本

```bash
LLVM_PATH=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

$LLVM_PATH/bin/llvm-config --version
```

## 关键文件清单

| 文件 | 目的 | 修改项 |
|------|------|--------|
| `src/target/mod.zig` | Roc 目标定义 | 第 183 行，三元组格式 |
| `crates/compiler/gen_llvm/src/` | LLVM 代码生成 | 三元组规范化（如需） |
| `build.zig` / `crates/compiler/build.rs` | 构建配置 | LLVM 路径指定 |

## 执行计划

1. **立即** (15 分钟)
   - [ ] 修改 `src/target/mod.zig` 第 183 行的三元组
   - [ ] 提交修改: `sbf-unknown-solana-unknown` → `sbf-solana-solana`

2. **验证** (30 分钟)
   - [ ] 运行 Roc 编译器检查
   - [ ] 尝试编译 hello-world 应用
   - [ ] 检查 LLVM IR 输出

3. **如果失败** (1-2 小时)
   - [ ] 分析 LLVM 后端代码
   - [ ] 查找三元组识别/规范化位置
   - [ ] 添加 Solana LLVM 特殊处理

4. **最终** (1 小时)
   - [ ] 完整编译链测试
   - [ ] 链接和部署验证

## 参考文献

- [LLVM 目标三元组说明](https://clang.llvm.org/docs/CrossCompilation.html)
- [Solana BPF 文档](https://docs.solana.com/)
- [Roc 编译器架构](https://github.com/roc-lang/roc/blob/main/crates/compiler/README.md)

---

**下一步**: 执行方案 1 的第一步修改，然后验证。
