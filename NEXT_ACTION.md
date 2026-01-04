# 下一个行动 - 立即执行

**当前日期**: 2026-01-04  
**预计时间**: 30-50 分钟  
**难度**: 中等 ⚠️

---

## 🎯 任务

验证 Roc SBF 编译链是否完整可工作。

---

## ⚡ 快速执行 (5 分钟设置 + 25 分钟运行)

### 方式 1: 一键脚本 (推荐)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 复制脚本
cat > verify_roc_sbf.sh << 'EOF'
#!/bin/bash
set -e

export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"
export ROC_BIN="./roc-source/zig-out/bin/roc"

echo "====== v0.2.0 Roc SBF 编译链验证 ======"
echo ""

# 步骤 1
echo "[1/5] Roc 版本..."
$ROC_BIN --version || exit 1
echo ""

# 步骤 2
echo "[2/5] 应用编译检查..."
$ROC_BIN check examples/hello-world/app.roc || exit 1
echo "✅ 通过"
echo ""

# 步骤 3
echo "[3/5] 生成 LLVM 位码..."
mkdir -p zig-out/lib
$ROC_BIN build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc 2>&1 || exit 1
file zig-out/lib/app.bc
echo "✅ 生成成功"
echo ""

# 步骤 4
echo "[4/5] 使用 Solana LLVM 编译..."
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc 2>&1 || exit 1
file zig-out/lib/app.o
echo "✅ 编译成功"
echo ""

# 步骤 5
echo "[5/5] Zig 构建..."
./solana-zig/zig build 2>&1 | tail -5 || exit 1
echo ""
echo "====== ✅ 验证通过 ======"
echo ""
ls -lh zig-out/lib/ | grep -E "(app|roc-hello)"
EOF

# 运行脚本
chmod +x verify_roc_sbf.sh
./verify_roc_sbf.sh
```

### 方式 2: 手动步骤

```bash
cd /home/davirain/dev/solana-sdk-roc

# 步骤 1: 验证 Roc (5 分钟)
./roc-source/zig-out/bin/roc --version
./roc-source/zig-out/bin/roc check examples/hello-world/app.roc

# 步骤 2: 生成位码 (10 分钟)
mkdir -p zig-out/lib
./roc-source/zig-out/bin/roc build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc

file zig-out/lib/app.bc

# 步骤 3: LLVM 编译 (10 分钟)
export LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"
$LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc

file zig-out/lib/app.o

# 步骤 4: Zig 构建 (10 分钟)
./solana-zig/zig build

ls -lh zig-out/lib/ | grep roc-hello
```

---

## ✅ 预期结果

### 步骤 1-2: ✅ Roc 编译检查
```
Roc compiler version debug-0e1cab9f
No errors found in examples/hello-world/app.roc
```

### 步骤 3: ✅ 位码生成
```
zig-out/lib/app.bc: LLVM bitcode, version 0
```

### 步骤 4: ✅ SBF 编译
```
zig-out/lib/app.o: ELF 64-bit LSB relocatable, (SBF) SBF
```

### 步骤 5: ✅ Zig 构建
```
zig-out/lib/roc-hello.so: ELF 64-bit LSB shared object, (SBF) SBF
```

---

## ❌ 如果失败

### 失败位置
1. **Roc 检查失败** → 查看 TESTING_GUIDE.md 测试 1
2. **位码生成失败** → 查看 TESTING_GUIDE.md 测试 2
3. **LLVM 编译失败** → 查看 TESTING_GUIDE.md 测试 3
4. **Zig 构建失败** → 查看 TESTING_GUIDE.md 测试 5

### 快速诊断
```bash
# 检查 Roc 版本
./roc-source/zig-out/bin/roc --version

# 检查目标支持
./roc-source/zig-out/bin/roc --list-targets | grep sbf

# 检查 LLVM 工具
solana-rust/build/x86_64-unknown-linux-gnu/llvm/build/bin/llc --version

# 检查 Zig 工具
./solana-zig/zig --version
```

---

## 📝 记录结果

完成后，**立即执行以下操作**：

```bash
# 1. 记录时间
echo "开始时间: $(date)" > /tmp/verification.log
echo "结束时间: $(date)" >> /tmp/verification.log

# 2. 复制脚本输出到文档
# 编辑 IMPLEMENTATION_STATUS.md，添加验证结果

# 3. 更新 Story 进度
# 编辑 stories/v0.2.0-roc-integration.md，标记完成的测试

# 4. 如果全部通过，标记为：
# ✅ 编译链验证成功
```

---

## 📚 参考资源

| 资源 | 用途 |
|------|------|
| QUICK_START_v0.2.0.md | 详细步骤 |
| TESTING_GUIDE.md | 故障排除 |
| IMPLEMENTATION_STATUS.md | 记录进度 |
| SESSION_WORK_LOG.md | 了解背景 |

---

## 🎯 成功标志

- ✅ `app.bc` 是有效的 LLVM 位码
- ✅ `app.o` 是有效的 SBF ELF 文件
- ✅ `roc-hello.so` 成功生成
- ✅ 不存在"unsupported target"错误

---

## ⏱️ 时间表

| 步骤 | 时间 | 累计 |
|------|------|------|
| 准备脚本 | 5 分钟 | 5 |
| 步骤 1-2 | 5 分钟 | 10 |
| 步骤 3 | 10 分钟 | 20 |
| 步骤 4 | 10 分钟 | 30 |
| 步骤 5 | 10 分钟 | 40 |
| 记录结果 | 5 分钟 | 45 |
| **总计** | | **45 分钟** |

---

## 🚀 立即开始

```bash
cd /home/davirain/dev/solana-sdk-roc

# 推荐方式 - 运行脚本
./verify_roc_sbf.sh

# 或参考 QUICK_START_v0.2.0.md 手动执行
```

---

**当前日期**: 2026-01-04  
**预计完成**: 今天  
**下一步**: 记录结果并更新文档
