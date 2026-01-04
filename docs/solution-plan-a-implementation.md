# 方案 A 实施：使用 Solana LLVM 静态库构建 Roc-SBF 编译链

> 时间: 2026-01-04  
> 状态: 🔨 开始实施  
> 目标: 通过配置 Roc 编译器使用 Solana LLVM，实现完整的 Roc → SBF 编译管道

## 现状分析

### 已完成的工作

1. ✅ **Solana Rust 源码克隆**
   - 位置: `solana-rust/`
   - 分支: `solana-tools-v1.52`
   - 包含完整 LLVM 子模块

2. ✅ **LLVM 编译完成**
   - 位置: `solana-rust/build/x86_64-unknown-linux-gnu/llvm/build/`
   - 构建工具: ninja (build.ninja)
   - 完成时间: 2026-01-04 10:25

3. ✅ **LLVM 库统计**
   - 总库文件: 208 个 `.a` 文件
   - 总大小: 2.0 GB
   - 包含 SBF 库: ✓
     - `libLLVMSBFCodeGen.a` (1.3M)
     - `libLLVMSBFAsmParser.a` (42K)
     - `libLLVMSBFDesc.a` (122K)
     - `libLLVMSBFDisassembler.a` (21K)
     - `libLLVMSBFInfo.a` (6.7K)

4. ✅ **工具链检查**
   - `llvm-config` ✓ 可用
   - `llc` ✓ 可用
   - `llvm-link` ✓ 可用
   - 头文件 ✓ 存在
   - CMake 配置 ✓ 存在

5. ✅ **Roc 编译器编译**
   - 位置: `roc-source/`
   - 编译工具: solana-zig (Zig 0.15.2)
   - 版本: debug-0e1cab9f
   - 状态: ✓ 可执行

## 实施方案 A 详细步骤

### 步骤 1: 配置 Roc LLVM 后端使用 Solana LLVM

**目标**: 配置 Roc 的 LLVM 代码生成使用 Solana 构建的 LLVM，而不是标准 LLVM。

**方法 1A: 编译时指定 LLVM 路径**

```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source

# 指定 Solana LLVM 路径重新编译 Roc
export LLVM_SYS_190_PREFIX=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 方式 1: Cargo 环境变量
cargo clean
cargo build --release \
    --env LLVM_SYS_190_PREFIX=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 或使用 zig build 指令（如果 build.zig 支持 llvm-path）
../solana-zig/zig build \
    -Dllvm-path=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build
```

**方法 1B: 修改 Roc 的 LLVM 后端配置**

查看 `roc-source` 中的 LLVM 配置：

```bash
# 查找 Roc LLVM 相关的源文件
find roc-source -name "*llvm*" -type f | grep -E "\.rs$|\.zig$" | head -20
```

关键文件位置：
- `roc-source/crates/compiler/gen_llvm/` - LLVM 代码生成
- `roc-source/crates/compiler/backend/` - 后端实现

**修改策略**:
1. 定位 Roc 的 LLVM 三元组识别代码
2. 添加 `sbf-solana-solana` 三元组支持
3. 配置 LLVM 目标映射

### 步骤 2: 为 Roc 构建 SBF 主机库

**目标**: 生成 Roc 平台所需的 SBF 特定宿主库。

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 确认平台定义
cat platform/main.roc

# 2. 使用 solana-zig 和 Solana LLVM 编译宿主库
./solana-zig/zig build-lib \
    -target sbf-freestanding \
    -O ReleaseSmall \
    platform/targets/sbfsolana/host.zig \
    --dep solana_sdk \
    -Msolana_sdk=vendor/solana-program-sdk-zig/src/root.zig \
    -Dllvm-path=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build
```

### 步骤 3: 测试 Roc 编译 Hello World 应用

**目标**: 验证 Roc 编译器能够生成 SBF 兼容的位码。

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 准备 Roc 应用
cat > examples/hello-world/app.roc << 'ROC'
app "hello"
    packages {
        pf: platform "../../platform/main.roc",
    }
    imports [pf.Stdout]
    provides [main] to pf

main : Str
main = "Hello from Roc on Solana!"
ROC

# 2. 编译到 LLVM 位码
./roc-source/zig-out/bin/roc build \
    --lib \
    --emit-llvm-ir \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.ir

# 3. 查看生成的 IR（调试）
file zig-out/lib/app.ir

# 4. 如果支持位码输出
./roc-source/zig-out/bin/roc build \
    --lib \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc
```

### 步骤 4: 使用 Solana LLVM 工具链编译位码

**目标**: 将 Roc 生成的位码编译为 SBF 目标代码。

```bash
LLVM_PATH=/home/davirain/dev/solana-sdk-roc/solana-rust/build/x86_64-unknown-linux-gnu/llvm/build

# 方式 1: 使用 llc 直接编译（如果位码支持）
$LLVM_PATH/bin/llc \
    -mtriple=sbf-solana-solana \
    -filetype=obj \
    zig-out/lib/app.bc \
    -o zig-out/lib/app.o

# 方式 2: 如果是 IR，先转为位码
$LLVM_PATH/bin/llvm-as \
    zig-out/lib/app.ir \
    -o zig-out/lib/app.bc

# 然后编译
$LLVM_PATH/bin/llc \
    -mtriple=sbf-solana-solana \
    -filetype=obj \
    zig-out/lib/app.bc \
    -o zig-out/lib/app.o
```

### 步骤 5: 链接 Roc 对象与 Zig 宿主

**目标**: 生成最终的 Solana eBPF 程序。

```bash
# 使用 solana-zig 的链接器链接所有组件
./solana-zig/zig build-exe \
    -target sbf-freestanding \
    -O ReleaseSmall \
    src/host.zig \
    zig-out/lib/app.o \
    --dep solana_sdk \
    -Msolana_sdk=vendor/solana-program-sdk-zig/src/root.zig \
    -o zig-out/lib/roc-hello.so

# 或使用更高级的 Zig 构建系统 (build.zig)
./solana-zig/zig build solana
```

### 步骤 6: 验证和部署

**目标**: 验证生成的 SBF 程序有效并可部署。

```bash
# 1. 验证目标文件格式
file zig-out/lib/roc-hello.so

# 2. 检查符号表
./solana-zig/zig nm zig-out/lib/roc-hello.so | head -20

# 3. 启动本地测试网（如需）
solana-test-validator &

# 4. 配置和部署
solana config set --url localhost
solana airdrop 2
solana program deploy zig-out/lib/roc-hello.so

# 5. 调用程序
./scripts/invoke.sh <PROGRAM_ID>

# 6. 查看日志输出
solana logs <PROGRAM_ID> | grep "Program log:"
```

## 关键检查清单

### 前置检查
- [ ] Solana LLVM 库位置已验证: `/solana-rust/build/.../llvm/build/lib/`
- [ ] LLVM 工具可用 (`llvm-config`, `llc`, `llvm-link`)
- [ ] Roc 编译器已编译并可执行
- [ ] solana-zig 编译器可用

### LLVM 配置检查
- [ ] 确定 Roc LLVM 绑定版本 (可能是 LLVM 19.0)
- [ ] 查找 Roc 源码中的 LLVM 三元组识别代码
- [ ] 添加 `sbf-solana-solana` 三元组支持（如需修改）
- [ ] 配置 LLVM 目标架构映射

### Roc 编译检查
- [ ] Roc 识别 SBF 目标: `roc build --list-targets | grep sbf`
- [ ] Roc 可以生成位码: `roc build --emit-llvm-bc app.roc`
- [ ] 位码格式有效: `file zig-out/lib/app.bc`

### 编译链检查
- [ ] LLVM IR/BC → SBF 目标代码: `llc -mtriple=sbf-solana-solana app.bc`
- [ ] 生成有效目标文件: `file app.o`
- [ ] 链接成功: `solana-zig zig build-exe ... -o program.so`

### 部署检查
- [ ] 程序文件有效: `file zig-out/lib/roc-hello.so`
- [ ] 部署成功: `solana program deploy ...`
- [ ] 程序执行成功: 检查日志输出

## 常见问题排查

### 问题 1: "LLVM error: No available targets are compatible with triple"

**原因**: Roc 的 LLVM 后端不认识 `sbf-solana-solana` 三元组

**解决方案**:
1. 检查 Roc 使用的 LLVM 版本
2. 修改 `roc/crates/compiler/gen_llvm/src/` 中的目标识别代码
3. 或使用 `bpfel-unknown-solana` 作为临时三元组

### 问题 2: "Undefined symbol: _start"

**原因**: 链接器找不到程序入口点

**解决方案**:
1. 确保 `src/host.zig` 定义了 `export fn entrypoint()`
2. 检查 build.zig 中的链接器配置
3. 使用 `-exported-functions=entrypoint` 强制导出

### 问题 3: "Relocation has invalid symbol index"

**原因**: 目标文件重定位问题

**解决方案**:
1. 使用 solana-zig 而不是系统 zig
2. 检查目标文件生成方式
3. 尝试使用 LTO (Link Time Optimization)

### 问题 4: "stack limit exceeded"

**原因**: Solana 堆栈限制 (4KB)

**解决方案**:
1. 使用 `-O ReleaseSmall` 优化
2. 避免深度递归
3. 在堆上分配而非栈上

## 时间估计

| 阶段 | 任务 | 时间 |
|------|------|------|
| 1 | 配置 Roc LLVM 后端 | 1-2 小时 |
| 2 | 编译 Roc 编译器 | 30-60 分钟 |
| 3 | 测试 Roc 编译 | 30 分钟 |
| 4 | LLVM 工具链编译 | 15 分钟 |
| 5 | 链接和验证 | 30 分钟 |
| 6 | 部署和测试 | 30 分钟 |
| **总计** | | **4-5 小时** |

## 下一步行动

1. **立即**: 分析 Roc LLVM 后端代码，了解三元组识别机制
2. **今天**: 尝试方法 1A 或 1B 配置 Roc 使用 Solana LLVM
3. **本周**: 完成完整编译链的端到端测试
4. **文档**: 更新 Story 和文档进度

## 参考资源

- LLVM SBF 目标: `solana-rust/llvm/lib/Target/SBF/`
- Roc LLVM 后端: `roc-source/crates/compiler/gen_llvm/`
- Roc 目标配置: `roc-source/crates/compiler/module/src/target.rs`

---

**进度追踪**: 详见 `stories/v0.2.0-roc-integration.md`
