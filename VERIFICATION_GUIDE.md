# 修改验证指南

> 本指南用于验证 Roc LLVM 三元组修改是否有效

## 1. 验证源码修改

### 命令
```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source
grep -n "sbfsolana =>" src/target/mod.zig | grep "sbf-solana-solana"
```

### 预期输出
```
183:            .sbfsolana => "sbf-solana-solana",
```

### ✅ 成功标志
- 第 183 行存在
- 包含 `sbf-solana-solana`

---

## 2. 重新编译 Roc

### 前置清理
```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source

# 清除所有缓存
rm -rf .zig-cache zig-out
```

### 编译命令
```bash
../solana-zig/zig build
```

### ✅ 成功标志
- 编译完成，无致命错误
- 生成 `zig-out/bin/roc` 可执行文件

---

## 3. 验证编译器可用性

### 命令
```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source
./zig-out/bin/roc version
```

### ✅ 预期输出
```
Roc compiler version debug-0e1cab9f
```

---

## 4. 验证目标识别

### 命令
```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source
./zig-out/bin/roc --list-targets 2>/dev/null | grep sbf
```

### ✅ 预期输出
```
sbfsolana
```

---

## 5. 快速验证脚本

```bash
#!/bin/bash
cd /home/davirain/dev/solana-sdk-roc/roc-source

echo "=== 1. 检查源码修改 ==="
grep "sbf-solana-solana" src/target/mod.zig && echo "✅ 三元组正确" || echo "❌ 三元组未找到"

echo ""
echo "=== 2. 重新编译 ==="
rm -rf .zig-cache zig-out
../solana-zig/zig build && echo "✅ 编译成功" || echo "❌ 编译失败"

echo ""
echo "=== 3. 验证编译器 ==="
./zig-out/bin/roc version && echo "✅ 编译器可用" || echo "❌ 编译器不可用"

echo ""
echo "=== 4. 验证目标 ==="
./zig-out/bin/roc --list-targets 2>/dev/null | grep -q sbf && echo "✅ 目标已识别" || echo "❌ 目标未识别"

echo ""
echo "=== 验证完成 ==="
```

---

## 常见问题

### 编译失败
- 清除所有缓存: `rm -rf .zig-cache zig-out`
- 检查磁盘空间: `df -h`

### 目标未识别
- 确认编译器是新生成的 (检查时间戳)
- 确认源码修改已应用: `grep sbf-solana-solana src/target/mod.zig`

### 预期时间
- 首次编译: 30-60 分钟
- 总验证: 1.5-2 小时

---

**优先级**: 🔴 高  
**预计耗时**: 1.5-2 小时
