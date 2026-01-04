# v0.2.0 快速开始指南

**版本**: v0.2.0 🔨 进行中  
**当前阶段**: LLVM 编译链集成验证  
**预计时间**: 30-60 分钟

---

## 概览

v0.2.0 目标是实现完整的 **Roc → LLVM 位码 → SBF 机器代码** 编译链。

### 当前状态
- ✅ Roc 编译器已编译
- ✅ LLVM 三元组已修复
- ✅ 测试应用已准备
- ⏳ 编译链验证即将开始

---

## 一键验证脚本

将以下脚本保存为 `verify_roc_sbf.sh` 并执行：

```bash
#!/bin/bash
set -e

cd /home/davirain/dev/solana-sdk-roc

export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"
export ROC_BIN="./roc-source/zig-out/bin/roc"

echo "======================================"
echo "v0.2.0 Roc SBF 编译链验证"
echo "======================================"
echo ""

# 步骤 1
echo "[1/5] Roc 版本检查..."
$ROC_BIN --version || echo "❌ Roc 编译器不可用"
echo ""

# 步骤 2
echo "[2/5] Roc 应用编译检查..."
$ROC_BIN check examples/hello-world/app.roc || {
    echo "❌ 应用编译检查失败"
    exit 1
}
echo "✅ 应用编译检查通过"
echo ""

# 步骤 3
echo "[3/5] 生成 LLVM 位码..."
mkdir -p zig-out/lib
$ROC_BIN build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc 2>&1 || {
    echo "❌ 位码生成失败"
    exit 1
}

file zig-out/lib/app.bc
echo "✅ 位码生成成功"
echo ""

# 步骤 4
echo "[4/5] 使用 Solana LLVM 编译位码..."
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc 2>&1 || {
    echo "❌ SBF 编译失败"
    exit 1
}

file zig-out/lib/app.o
echo "✅ SBF 编译成功"
echo ""

# 步骤 5
echo "[5/5] Zig 构建..."
./solana-zig/zig build 2>&1 | tail -10 || {
    echo "❌ Zig 构建失败"
    exit 1
}

echo ""
echo "======================================"
echo "✅ 所有验证通过！"
echo "======================================"
echo ""
echo "生成的文件:"
ls -lh zig-out/lib/ | grep -E "(app|roc-hello)"
echo ""
echo "下一步:"
echo "1. 启动测试网: solana-test-validator"
echo "2. 部署程序: solana program deploy zig-out/lib/roc-hello.so"
echo "3. 检查日志: solana logs <PROGRAM_ID> | grep 'Hello from Roc'"
```

---

## 手动验证步骤

### 步骤 1: 验证 Roc 编译器 (5 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 检查编译器
./roc-source/zig-out/bin/roc --version
# 预期输出: Roc compiler version debug-0e1cab9f

# 检查应用
./roc-source/zig-out/bin/roc check examples/hello-world/app.roc
# 预期输出: No errors found
```

**如果失败**:
- 检查文件存在: `ls -la roc-source/zig-out/bin/roc`
- 检查权限: `chmod +x roc-source/zig-out/bin/roc`

### 步骤 2: 生成 LLVM 位码 (10 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 创建输出目录
mkdir -p zig-out/lib

# 生成位码
./roc-source/zig-out/bin/roc build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc

# 验证生成的文件
file zig-out/lib/app.bc
# 预期输出: LLVM bitcode, version 0

# 查看文件大小
ls -lh zig-out/lib/app.bc
```

**如果失败**:
- 检查目标识别: `./roc-source/zig-out/bin/roc --list-targets | grep sbf`
- 查看错误信息: 在上面的命令添加 `2>&1 | tee /tmp/roc_error.log`

### 步骤 3: 使用 Solana LLVM 编译 (10 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 设置 LLVM 路径
export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"

# 验证 LLVM 工具可用
$LLVM_PATH/bin/llc --version | head -5
# 预期输出: LLVM version ...

# 编译位码到 SBF
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc

# 验证生成的文件
file zig-out/lib/app.o
# 预期输出: ELF 64-bit LSB relocatable, (SBF) SBF

# 检查文件大小
ls -lh zig-out/lib/app.o
```

**如果失败**:
- 检查 LLVM 编译完成: `ls -la $LLVM_PATH/bin/llc`
- 查看详细错误: `$LLVM_PATH/bin/llc -debug zig-out/lib/app.bc 2>&1 | head -50`

### 步骤 4: Zig 构建 (10 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 清除旧构建
rm -rf .zig-cache zig-out/lib/roc-hello*

# 构建最终程序
./solana-zig/zig build

# 验证生成的程序
file zig-out/lib/roc-hello.so
# 预期输出: ELF 64-bit LSB shared object, (SBF) SBF

# 查看大小
ls -lh zig-out/lib/roc-hello.so
```

**如果失败**:
- 确保使用 solana-zig: `which zig` 应该显示 `./solana-zig/zig`
- 清除缓存: `rm -rf .zig-cache zig-out`

---

## 验证完成标准

### ✅ 成功标志

| 检查项 | 标志 |
|--------|------|
| Roc 编译器可用 | ✅ `roc version` 正常 |
| 应用编译成功 | ✅ `roc check` 无错误 |
| 位码生成成功 | ✅ `app.bc` 是有效的 LLVM 位码 |
| SBF 编译成功 | ✅ `app.o` 是有效的 ELF SBF 文件 |
| Zig 构建成功 | ✅ `roc-hello.so` 生成 |

### ❌ 失败标志

| 错误 | 原因 | 解决 |
|------|------|------|
| `No such file` | 文件不存在 | 检查路径和编译是否完成 |
| `unsupported target` | 三元组不支持 | 重新编译 Roc (参考 SESSION_SUMMARY.md) |
| `Permission denied` | 文件无执行权限 | `chmod +x` |
| `connection refused` | LLVM 工具不可用 | 检查 Solana LLVM 编译是否完成 |

---

## 常见问题速查

### Q1: 如何知道 Solana LLVM 是否已编译？
```bash
ls -lh solana-rust/build/x86_64-unknown-linux-gnu/llvm/build/bin/llc
# 应该显示文件大小 > 10MB
```

### Q2: 如何确认 Roc 识别了 sbfsolana 目标？
```bash
./roc-source/zig-out/bin/roc --list-targets 2>/dev/null | grep -i sbf
# 应该显示: sbfsolana
```

### Q3: LLVM 位码看起来不对，如何调试？
```bash
# 查看位码信息
solana-rust/build/.../llvm/build/bin/llvm-dis zig-out/lib/app.bc | head -30

# 查看目标信息
grep "target triple\|target datalayout" /tmp/app.ir
```

### Q4: 目标文件大小太大或太小，是否正常？
```bash
# 查看目标文件内容
readelf -h zig-out/lib/app.o
readelf -S zig-out/lib/app.o

# 查看符号
readelf -s zig-out/lib/app.o
```

---

## 后续步骤

### 如果所有验证都通过 ✅

1. 更新进度文档
```bash
# 记录完成时间和结果
# 更新 IMPLEMENTATION_STATUS.md
# 更新 stories/v0.2.0-roc-integration.md
```

2. 部署到测试网 (参考 TESTING_GUIDE.md 中的部署步骤)

3. 继续 v0.3.0 规划

### 如果某个步骤失败 ❌

1. 查看详细错误信息
2. 参考 TESTING_GUIDE.md 的故障排除部分
3. 检查 docs/roc-llvm-sbf-fix.md 的备选方案
4. 记录问题和解决方案

---

## 参考资源

| 资源 | 说明 |
|------|------|
| `TESTING_GUIDE.md` | 详细的 5 阶段测试 |
| `IMPLEMENTATION_STATUS.md` | 当前状态总览 |
| `SESSION_WORK_LOG.md` | 本次会话工作日志 |
| `docs/roc-llvm-sbf-fix.md` | 三元组修复细节 |
| `docs/solution-plan-a-implementation.md` | 完整实施计划 |

---

## 时间估计

| 步骤 | 时间 | 累计 |
|------|------|------|
| 步骤 1: Roc 检查 | 5 分钟 | 5 |
| 步骤 2: 位码生成 | 10 分钟 | 15 |
| 步骤 3: SBF 编译 | 10 分钟 | 25 |
| 步骤 4: Zig 构建 | 10 分钟 | 35 |
| 步骤 5: 部署 (可选) | 15 分钟 | 50 |
| **总计** | | **35-50 分钟** |

---

## 检查清单

执行时使用以下清单：

```markdown
### 验证清单

- [ ] Roc 编译器版本正确
- [ ] 应用编译检查通过
- [ ] LLVM 位码生成成功
- [ ] 位码文件有效
- [ ] Solana LLVM 工具可用
- [ ] SBF 编译成功
- [ ] 目标文件有效
- [ ] Zig 构建成功
- [ ] 最终程序生成

### 后续步骤

- [ ] 记录完成时间
- [ ] 更新进度文档
- [ ] 部署到测试网
- [ ] 验证日志输出
- [ ] 更新 Story 状态为 ✅
```

---

**预计完成时间**: 30-50 分钟  
**难度等级**: 中等 ⚠️  
**关键路径**: Roc → 位码 → SBF → 链接

立即开始: 运行 `verify_roc_sbf.sh` 或按步骤 1-4 手动执行
