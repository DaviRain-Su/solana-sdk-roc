# 验证检查清单 - v0.2.0 编译链

**目标**: 验证 Roc SBF 编译链完整可工作  
**时间**: 30-50 分钟  
**难度**: 中等 ⚠️

---

## 📋 执行清单

### 前置检查 (5 分钟)

- [ ] 位于正确目录: `/home/davirain/dev/solana-sdk-roc`
- [ ] `run_verification.sh` 脚本存在
- [ ] Roc 编译器存在: `roc-source/zig-out/bin/roc`
- [ ] Solana LLVM 存在: `solana-rust/build/.../llvm/build/bin/llc`
- [ ] Solana-zig 存在: `solana-zig/zig`

### 验证执行 (30-40 分钟)

- [ ] 运行脚本: `chmod +x run_verification.sh && ./run_verification.sh`
- [ ] 脚本开始: 显示头部信息
- [ ] 测试 1 通过: Roc 编译器检查 ✅
- [ ] 测试 2 通过: 应用编译检查 ✅
- [ ] 测试 3 通过: 位码生成 ✅
- [ ] 测试 4 通过: LLVM 编译 ✅
- [ ] 测试 5 通过: Zig 构建 ✅
- [ ] 脚本完成: 显示最终摘要

### 结果验证 (5 分钟)

**文件检查**:
- [ ] `zig-out/lib/app.bc` 存在
- [ ] `zig-out/lib/app.o` 存在
- [ ] `zig-out/lib/roc-hello.so` 存在

**文件类型验证**:
```bash
file zig-out/lib/app.bc       # 应显示: LLVM bitcode
file zig-out/lib/app.o        # 应显示: ELF ... (SBF) SBF
file zig-out/lib/roc-hello.so # 应显示: ELF ... shared object
```

- [ ] app.bc 是 LLVM bitcode
- [ ] app.o 是 ELF SBF 格式
- [ ] roc-hello.so 是共享对象

**文件大小检查**:
```bash
ls -lh zig-out/lib/app.* zig-out/lib/roc-hello.so
```

- [ ] app.bc 大小: 1 KB - 100 KB
- [ ] app.o 大小: 1 KB - 100 KB
- [ ] roc-hello.so 大小: 10 KB - 200 KB

---

## 🔧 故障排除决策树

### 如果脚本执行失败

```
脚本显示 ❌
  │
  ├─ [测试 1/5] Roc 编译器不可用
  │  └─ 查看: MANUAL_VERIFICATION_STEPS.md 步骤 2
  │
  ├─ [测试 2/5] 应用编译检查失败
  │  └─ 查看: TESTING_GUIDE.md 测试 2, 故障排除
  │
  ├─ [测试 3/5] 位码生成失败
  │  └─ 查看: TESTING_GUIDE.md 测试 2, 故障排除
  │     原因可能: unsupported target
  │  └─ 解决: docs/roc-llvm-sbf-fix.md
  │
  ├─ [测试 4/5] LLVM 编译失败
  │  └─ 查看: TESTING_GUIDE.md 测试 3, 故障排除
  │
  └─ [测试 5/5] Zig 构建失败
     └─ 查看: TESTING_GUIDE.md 测试 5, 故障排除
```

### 如果脚本成功但文件不正确

```
文件存在但类型错误
  │
  ├─ app.bc 不是 LLVM bitcode
  │  └─ 原因: Roc 生成的不是位码
  │  └─ 解决: 查看 Roc 编译选项
  │
  ├─ app.o 不是 ELF SBF 格式
  │  └─ 原因: LLVM 不是 Solana LLVM
  │  └─ 解决: 检查 LLVM_PATH 环境变量
  │
  └─ roc-hello.so 不是共享对象
     └─ 原因: Zig 链接器配置问题
     └─ 解决: 检查 build.zig 配置
```

---

## ✅ 成功标准

### 必需条件 (全部必须 ✅)

- ✅ 脚本执行完成，无 ❌ 错误
- ✅ 生成的 3 个文件都存在
- ✅ 文件类型都正确 (通过 `file` 命令验证)
- ✅ 文件大小在合理范围内

### 可选验证 (更深入的检查)

- ✅ 使用 `readelf` 检查 ELF 头
- ✅ 使用 `llvm-dis` 查看位码内容
- ✅ 使用 `nm` 查看目标文件符号

```bash
# 可选的深度验证
readelf -h zig-out/lib/app.o
readelf -S zig-out/lib/app.o
nm zig-out/lib/app.o
```

---

## 📊 快速状态检查

### 一条命令检查所有条件

```bash
echo "=== 文件存在检查 ===" && \
ls -lh zig-out/lib/app.* zig-out/lib/roc-hello.so && \
echo "" && \
echo "=== 文件类型检查 ===" && \
file zig-out/lib/app.bc && \
file zig-out/lib/app.o && \
file zig-out/lib/roc-hello.so
```

### 预期输出

```
=== 文件存在检查 ===
-rw-r--r-- ... zig-out/lib/app.bc
-rw-r--r-- ... zig-out/lib/app.o
-rwxr-xr-x ... zig-out/lib/roc-hello.so

=== 文件类型检查 ===
zig-out/lib/app.bc: LLVM bitcode, version 0
zig-out/lib/app.o: ELF 64-bit LSB relocatable, (SBF) SBF, version 1 (SYSV)
zig-out/lib/roc-hello.so: ELF 64-bit LSB shared object, (SBF) SBF, version 1 (SYSV), dynamically linked
```

---

## 📝 记录格式

完成验证后，填写以下信息用于文档更新：

```markdown
### 验证执行记录 - [DATE]

**执行时间**: YYYY-MM-DD HH:MM:SS
**执行环境**: [Linux/macOS] [Distribution]
**执行人**: [Name]

#### 测试结果

| # | 测试 | 耗时 | 状态 | 备注 |
|----|------|------|------|------|
| 1 | Roc 版本检查 | X sec | ✅ | - |
| 2 | 应用编译检查 | X sec | ✅ | - |
| 3 | 位码生成 | X sec | ✅ | - |
| 4 | LLVM 编译 | X sec | ✅ | - |
| 5 | Zig 构建 | X sec | ✅ | - |

**总耗时**: X min

#### 生成文件

```bash
ls -lh zig-out/lib/
```

输出:
```
-rw-r--r-- ... X KB ... app.bc
-rw-r--r-- ... X KB ... app.o
-rwxr-xr-x ... X KB ... roc-hello.so
```

#### 验证结果

- [x] 所有测试通过
- [x] 文件存在且类型正确
- [x] 文件大小合理
- [ ] (可选) 后续部署验证

#### 问题与解决

(如有问题，记录诊断步骤)

#### 下一步

- [ ] 更新 IMPLEMENTATION_STATUS.md
- [ ] 更新 stories/v0.2.0-roc-integration.md
- [ ] 执行部署验证 (P2)
```

---

## 🔄 重复执行 (如需重新验证)

```bash
# 清除旧的构建
rm -rf .zig-cache zig-out

# 重新创建输出目录
mkdir -p zig-out/lib

# 重新运行验证
./run_verification.sh
```

---

## 📚 参考资源

| 情况 | 参考文档 |
|------|---------|
| 需要逐步执行 | MANUAL_VERIFICATION_STEPS.md |
| 脚本失败诊断 | TESTING_GUIDE.md (相应测试) |
| 三元组问题 | docs/roc-llvm-sbf-fix.md |
| 环境设置 | README.md |
| 完整技术方案 | docs/solution-plan-a-implementation.md |

---

## 💡 提示

### 快速执行
使用脚本是最快的方式，它会自动处理所有步骤：
```bash
./run_verification.sh
```

### 详细执行
如果需要了解每一步的细节，参考 `MANUAL_VERIFICATION_STEPS.md`

### 问题诊断
如果脚本失败，参考 `TESTING_GUIDE.md` 获取详细的故障排除步骤

### 文档更新
完成验证后，立即更新进度文档以保持同步

---

## 🎯 下一步 (验证成功后)

### 立即 (5-10 分钟)
```bash
# 更新进度文档
# 编辑: IMPLEMENTATION_STATUS.md
# 编辑: stories/v0.2.0-roc-integration.md
```

### 后续 (P2 优先级 15-30 分钟)
```bash
# 部署验证
solana-test-validator          # 在新终端
solana config set --url localhost
solana airdrop 2
solana program deploy zig-out/lib/roc-hello.so
solana logs <PROGRAM_ID>
```

---

**准备好了？** 开始验证：

```bash
cd /home/davirain/dev/solana-sdk-roc
./run_verification.sh
```

**不确定？** 查看 `EXEC_GUIDE.md` 了解详细的执行指南。
