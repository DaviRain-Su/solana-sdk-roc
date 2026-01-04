# 测试指南 - Roc SBF 编译和 LLVM 编译链

**时间**: 2026-01-04  
**目标**: 验证 Roc 应用编译和 LLVM 编译链集成

---

## 测试 1: Roc 应用编译检查

### 目标
验证 Roc 编译器能够识别 `sbfsolana` 目标并编译 hello-world 应用。

### 执行步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 验证 Roc 编译器可用
./roc-source/zig-out/bin/roc --version
# 预期输出: Roc compiler version debug-0e1cab9f

# 2. 编译检查 (不生成输出，只检查语法)
./roc-source/zig-out/bin/roc check examples/hello-world/app.roc

# 预期输出:
# No errors found in examples/hello-world/app.roc
```

### 预期结果

✅ 成功: 没有编译错误  
❌ 失败: 显示编译错误（需要修复平台或应用）

### 故障排除

**错误**: `No available targets are compatible with triple "sbf-solana-solana"`
- **原因**: Roc 编译器没有正确识别修改后的三元组
- **解决**:
  1. 验证修改: `grep "sbfsolana =>" roc-source/src/target/mod.zig`
  2. 清除缓存: `rm -rf roc-source/.zig-cache roc-source/zig-out`
  3. 重新编译: `cd roc-source && ../solana-zig/zig build`

**错误**: `Error: module "pf" not found`
- **原因**: Roc 找不到平台引用
- **解决**: 检查 `platform/main.roc` 是否存在且有效

---

## 测试 2: LLVM 位码生成

### 目标
验证 Roc 编译器能够生成 LLVM 位码文件。

### 执行步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 生成 LLVM 位码 (BC 格式)
./roc-source/zig-out/bin/roc build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc 2>&1 | tee /tmp/roc_build.log

# 2. 验证生成的文件
file zig-out/lib/app.bc

# 预期输出:
# zig-out/lib/app.bc: LLVM bitcode, version 0
```

### 预期结果

✅ 成功: 生成有效的 LLVM 位码文件  
❌ 失败: 显示编译错误或无法生成位码

### 故障排除

**错误**: `Unsupported target arch sbf`
- **原因**: LLVM 后端不支持 SBF 架构
- **解决**:
  1. 检查 Roc 编译器版本: `./roc-source/zig-out/bin/roc version`
  2. 尝试使用 `--emit-llvm-ir` 生成 IR 进行调试

**错误**: `Could not find or load shared library`
- **原因**: Roc 依赖的库不在系统路径中
- **解决**: 使用完整路径运行 Roc: `./roc-source/zig-out/bin/roc`

---

## 测试 3: LLVM 编译链 - 位码到 SBF 目标

### 目标
使用 Solana LLVM 的 `llc` 工具将位码编译为 SBF 目标代码。

### 前提条件
- ✅ 已生成 `zig-out/lib/app.bc`
- ✅ Solana LLVM 已编译

### 执行步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 设置 LLVM 路径
export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"

# 2. 验证 llc 工具
file $LLVM_PATH/bin/llc
$LLVM_PATH/bin/llc --version | head -5

# 预期输出:
# LLVM version X.X.X
# ...

# 3. 编译位码到 SBF 目标代码
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc 2>&1 | tee /tmp/llc_compile.log

# 4. 验证生成的目标文件
file zig-out/lib/app.o

# 预期输出:
# zig-out/lib/app.o: ELF 64-bit LSB relocatable, (SBF) SBF 5, version 1 (SYSV)

# 5. 检查目标文件信息
$LLVM_PATH/bin/../../../tools/llvm-readelf -h zig-out/lib/app.o
# 或者使用系统 readelf (如果可用)
readelf -h zig-out/lib/app.o 2>/dev/null || echo "readelf not available"
```

### 预期结果

✅ 成功: 生成有效的 SBF 目标文件 (ELF 格式)  
❌ 失败: 显示编译错误或无效的文件格式

### 故障排除

**错误**: `Target triple not supported: sbf-solana-solana`
- **原因**: Solana LLVM 的架构不支持该三元组
- **解决**:
  1. 尝试不同的三元组: `sbf-unknown-linux-unknown`
  2. 查看支持的目标: `$LLVM_PATH/bin/llc --version | grep Targets`

**错误**: `unrecognized target triple`
- **原因**: 位码中的三元组与 llc 不匹配
- **解决**:
  1. 检查位码内容: `$LLVM_PATH/bin/llvm-dis zig-out/lib/app.bc | head -20`
  2. 查看目标信息: `grep "target triple" /tmp/llc_compile.log`

**错误**: `Permission denied`
- **原因**: llc 可执行文件无执行权限
- **解决**: `chmod +x $LLVM_PATH/bin/llc`

---

## 测试 4: 最小化集成测试

### 目标
验证最小的集成工作流程：Roc → 位码 → SBF 目标代码。

### 执行步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 完整工作流程脚本
set -e  # 任何错误时退出

export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"
export ROC_BIN="./roc-source/zig-out/bin/roc"

echo "=== 步骤 1: Roc 编译检查 ==="
$ROC_BIN check examples/hello-world/app.roc

echo "=== 步骤 2: 生成 LLVM 位码 ==="
$ROC_BIN build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc

echo "=== 步骤 3: 验证位码 ==="
file zig-out/lib/app.bc

echo "=== 步骤 4: 使用 llc 编译到 SBF ==="
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc

echo "=== 步骤 5: 验证目标文件 ==="
file zig-out/lib/app.o

echo "=== ✅ 所有步骤完成 ==="
```

### 预期输出

```
=== 步骤 1: Roc 编译检查 ===
No errors found in examples/hello-world/app.roc

=== 步骤 2: 生成 LLVM 位码 ===
[... 编译输出 ...]

=== 步骤 3: 验证位码 ===
zig-out/lib/app.bc: LLVM bitcode, version 0

=== 步骤 4: 使用 llc 编译到 SBF ===
[... 编译输出 ...]

=== 步骤 5: 验证目标文件 ===
zig-out/lib/app.o: ELF 64-bit LSB relocatable

=== ✅ 所有步骤完成 ===
```

---

## 测试 5: Zig 构建系统集成 (可选)

### 目标
验证 Zig 构建脚本能够成功构建 Solana 程序。

### 执行步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 清除旧的构建
rm -rf .zig-cache zig-out

# 2. 构建 Roc 宿主库
./solana-zig/zig build host

# 预期输出:
# 构建成功，生成 zig-out/lib/host.a

# 3. 构建完整的 Solana 程序
./solana-zig/zig build

# 预期输出:
# 构建成功，生成 zig-out/lib/roc-hello.so

# 4. 验证生成的程序
file zig-out/lib/roc-hello.so
ls -lh zig-out/lib/

# 预期输出:
# roc-hello.so: ELF 64-bit LSB shared object, (SBF) SBF
```

---

## 检查清单

使用以下清单验证完整工作流程：

```markdown
# Roc SBF 编译工作流程检查清单

- [ ] Roc 编译器版本正确 (debug-0e1cab9f)
- [ ] `roc check` 应用成功
- [ ] LLVM 位码生成成功
- [ ] 位码文件有效 (LLVM bitcode)
- [ ] LLVM 工具 (`llc`) 可用
- [ ] `llc` 能识别 SBF 目标
- [ ] SBF 目标代码编译成功
- [ ] 目标文件有效 (ELF 64-bit)
- [ ] Zig 构建系统可用
- [ ] 最终程序生成成功
- [ ] 程序能部署到测试网

## 下一步

- [ ] 如果所有测试通过，继续部署到测试网
- [ ] 如果测试失败，参考故障排除部分
- [ ] 更新 `IMPLEMENTATION_STATUS.md` 记录结果
```

---

## 常见问题 (FAQ)

### Q: 为什么需要修改 LLVM 三元组？
A: Roc 编译器定义的三元组必须与 Solana LLVM 支持的三元组匹配。Solana LLVM 支持 `sbf-solana-solana`，而原始 Roc 定义的是 `sbf-unknown-solana-unknown`。

### Q: 位码和目标文件有什么区别？
A: 
- **位码** (.bc): LLVM 中间表示的二进制格式，可移植性强
- **目标文件** (.o): 机器代码，特定于目标架构 (SBF)

### Q: 为什么需要两个编译步骤？
A: 
1. Roc 编译到 LLVM 位码
2. LLVM 编译位码到 SBF 机器代码

这种设计分离了前端和后端，使得 Roc 编译器不需要内置完整的 LLVM 后端。

### Q: 能否直接使用标准 llc 工具？
A: 否，需要使用 Solana LLVM 的 `llc`，因为标准 LLVM 不支持 SBF 架构。

---

## 参考资源

- `IMPLEMENTATION_STATUS.md` - 实施状态总结
- `NEXT_STEPS.md` - 用户操作指南
- `docs/solution-plan-a-implementation.md` - 详细实施计划
- `docs/roc-llvm-sbf-fix.md` - LLVM 三元组修复细节

---

**最后更新**: 2026-01-04  
**预期测试时间**: 20-30 分钟
