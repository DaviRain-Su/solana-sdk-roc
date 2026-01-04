# 下一步行动清单 (2026-01-04)

## 概览

我们正在实施**方案 A: 使用 Solana LLVM 静态库**来实现完整的 Roc → SBF 编译链。

**当前状态**: 🔧 正在修复 Roc LLVM 三元组配置

**关键修改**: 已将 Roc 的 SBF 目标三元组从 `sbf-unknown-solana-unknown` 改为 `sbf-solana-solana`

## 立即执行的步骤

### 步骤 1: 重新编译 Roc (30-60 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source

# 1. 清除旧的编译缓存
rm -rf .zig-cache zig-out

# 2. 重新编译 Roc 编译器（使用 solana-zig）
../solana-zig/zig build

# 3. 验证编译成功
./zig-out/bin/roc version
```

**预期结果**: 编译成功，版本信息显示

### 步骤 2: 验证三元组修改 (5 分钟)

```bash
# 1. 检查源码修改
grep "sbfsolana =>" src/target/mod.zig
# 应该输出: .sbfsolana => "sbf-solana-solana",

# 2. 确认编译后的目标支持
./zig-out/bin/roc --list-targets 2>/dev/null | grep -i sbf
# 应该输出: sbfsolana
```

**预期结果**: 目标列表中包含 `sbfsolana`

### 步骤 3: 创建简单 Roc 应用测试 (15 分钟)

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 创建简单的 Roc 应用
cat > examples/hello-world/app.roc << 'EOF'
app "hello"
    provides [main] to pf
    imports [pf.Stdout]

main : Str
main = "Hello from Roc!"
EOF

# 2. 测试编译检查
./roc-source/zig-out/bin/roc check examples/hello-world/app.roc

# 3. 尝试生成 LLVM IR（调试用）
./roc-source/zig-out/bin/roc build \
    --target sbfsolana \
    --emit-llvm-ir \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.ir 2>&1

# 4. 或尝试位码输出
./roc-source/zig-out/bin/roc build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc 2>&1
```

**预期结果**: 编译成功或给出有意义的错误（不是三元组不支持的错误）

## 如果出现问题

### 问题 1: "No available targets are compatible with triple"
**解决**:
1. 检查三元组是否正确: `grep sbfsolana src/target/mod.zig`
2. 清除缓存重新编译
3. 查看 `docs/roc-llvm-sbf-fix.md` 的备用方案

### 问题 2: "sbfsolana target not found"
**解决**:
1. 确保 Roc 重新编译成功
2. 检查 `zig-out/bin/roc` 是新生成的
3. 运行 `roc --version` 确认版本变化

### 问题 3: Roc 编译器编译失败
**解决**:
1. 清除所有缓存: `rm -rf .zig-cache zig-out`
2. 检查磁盘空间: `df -h`
3. 检查网络（可能需要下载依赖）
4. 查看完整错误信息

## 成功标志

✅ 当以下条件满足时，此阶段成功：

1. ✅ Roc 编译器成功重新编译
2. ✅ `sbfsolana` 目标在支持的目标列表中
3. ✅ 可以生成 LLVM IR 或位码（即使包含错误，也说明编译器识别了目标）
4. ✅ 没有 "No available targets" 的错误

## 后续步骤

完成上述步骤后，进行下一阶段：

1. **LLVM 编译链测试** (使用 Solana LLVM 工具编译位码)
2. **Zig 宿主集成** (链接 Roc 输出和 Zig 代码)
3. **部署和验证** (在 Solana 链上测试)

## 参考文档

- `docs/solution-plan-a-implementation.md` - 完整实施计划
- `docs/roc-llvm-sbf-fix.md` - 三元组修复详解
- `docs/implementation-progress.md` - 总体进度追踪
- `stories/v0.2.0-roc-integration.md` - Story 进度

## 时间估计

- **步骤 1-2**: 1-1.5 小时
- **步骤 3**: 15 分钟
- **总计**: 1.5 小时

---

**状态**: 🔨 进行中  
**最后更新**: 2026-01-04  
**预期完成**: 今天

**执行人**: [Your Name]  
**检查点**: 完成步骤 3 后更新文档
