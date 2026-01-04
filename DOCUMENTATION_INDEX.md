# 文档索引 - Roc on Solana 平台

**最后更新**: 2026-01-04  
**版本**: v0.2.0 🔨 进行中

---

## 📚 文档体系

本项目的文档分为以下几个层级：

### 1️⃣ 快速入门 (推荐从这里开始)

| 文档 | 说明 | 读者 |
|------|------|------|
| **README.md** | 项目总览，架构和快速开始 | 所有人 |
| **QUICK_START_v0.2.0.md** | v0.2.0 一键验证脚本和手动步骤 | 想快速验证的人 |
| **NEXT_STEPS.md** | 下一步行动清单 (推荐) | 即将开始工作的人 |

### 2️⃣ 实施指南 (工作时参考)

| 文档 | 说明 | 用途 |
|------|------|------|
| **TESTING_GUIDE.md** | 5 阶段测试详细说明和故障排除 | 执行测试时 |
| **IMPLEMENTATION_STATUS.md** | 当前实施状态、优先级和下一步 | 了解现状和计划 |
| **SESSION_WORK_LOG.md** | 本次会话的工作记录和决策 | 理解工作背景 |

### 3️⃣ 技术文档 (深度理解)

| 文档 | 说明 | 深度 |
|------|------|------|
| **docs/solution-plan-a-implementation.md** | 方案 A 详细实施步骤 (6 个阶段) | ⭐⭐⭐ |
| **docs/roc-llvm-sbf-fix.md** | LLVM 三元组问题分析和修复 | ⭐⭐⭐ |
| **docs/implementation-progress.md** | 实施进度追踪和检查点 | ⭐⭐ |

### 4️⃣ 项目管理 (追踪进度)

| 文档 | 说明 | 频率 |
|------|------|------|
| **stories/v0.2.0-roc-integration.md** | Story 进度和验收标准 | 每日更新 |
| **CHANGELOG.md** | 变更日志 | 每次提交时 |
| **VERIFICATION_RESULTS.md** | 上次验证结果 | 完成验证后 |

---

## 🎯 使用场景指南

### 场景 1: 我是新来的，想了解项目

**推荐阅读顺序**:
1. `README.md` - 了解项目目标和状态
2. `QUICK_START_v0.2.0.md` - 了解当前工作
3. `SESSION_WORK_LOG.md` - 理解工作背景

### 场景 2: 我需要执行 v0.2.0 的编译链验证

**推荐阅读顺序**:
1. `QUICK_START_v0.2.0.md` - 快速验证 (5 分钟)
2. `TESTING_GUIDE.md` - 详细步骤 (需要时参考)
3. `IMPLEMENTATION_STATUS.md` - 理解优先级

### 场景 3: 某个步骤失败了，我需要故障排除

**推荐阅读顺序**:
1. `TESTING_GUIDE.md` - 查看"故障排除"部分
2. `docs/roc-llvm-sbf-fix.md` - 查看备选方案
3. `docs/solution-plan-a-implementation.md` - 查看详细技术

### 场景 4: 我需要理解完整的技术方案

**推荐阅读顺序**:
1. `docs/solution-plan-a-implementation.md` - 6 个实施阶段
2. `docs/roc-llvm-sbf-fix.md` - LLVM 问题分析
3. `docs/implementation-progress.md` - 进度追踪

### 场景 5: 我需要报告进度或更新 Story

**推荐工具**:
1. `IMPLEMENTATION_STATUS.md` - 复制状态信息
2. `SESSION_WORK_LOG.md` - 记录工作成果
3. `stories/v0.2.0-roc-integration.md` - 更新 Story

---

## 📖 文档特性矩阵

| 文档 | 快速? | 详细? | 代码? | 故障排除? |
|------|--------|--------|--------|-----------|
| README.md | ⭐⭐⭐ | ⭐ | ⭐⭐ | ❌ |
| QUICK_START_v0.2.0.md | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐ |
| TESTING_GUIDE.md | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| NEXT_STEPS.md | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐ |
| IMPLEMENTATION_STATUS.md | ⭐⭐ | ⭐⭐ | ⭐ | ⭐ |
| docs/solution-plan-a-* | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |

---

## 📋 文档组织方式

```
roc-on-solana/
├── 🚀 快速开始
│   ├── README.md                          # 项目入口
│   ├── QUICK_START_v0.2.0.md             # v0.2.0 快速验证
│   └── NEXT_STEPS.md                      # 下一步行动
│
├── 🔨 实施指南
│   ├── TESTING_GUIDE.md                   # 5 阶段测试
│   ├── IMPLEMENTATION_STATUS.md           # 当前状态
│   └── SESSION_WORK_LOG.md                # 工作日志
│
├── 📚 技术文档
│   └── docs/
│       ├── solution-plan-a-implementation.md  # 方案 A
│       ├── roc-llvm-sbf-fix.md               # LLVM 修复
│       ├── implementation-progress.md         # 进度追踪
│       └── ...其他文档...
│
├── 📊 项目管理
│   ├── stories/
│   │   └── v0.2.0-roc-integration.md      # Story 进度
│   ├── CHANGELOG.md                        # 变更日志
│   └── VERIFICATION_RESULTS.md             # 验证结果
│
└── 📑 本索引
    └── DOCUMENTATION_INDEX.md              # 你在这里
```

---

## 🔍 按话题查找文档

### 话题: Roc 编译器和编译

| 话题 | 相关文档 | 部分 |
|------|---------|------|
| Roc 编译器编译 | SESSION_SUMMARY.md | 已完成的工作 |
| Roc 编译目标配置 | docs/roc-llvm-sbf-fix.md | LLVM 三元组部分 |
| Roc 应用编译 | TESTING_GUIDE.md | 测试 1-2 |
| Roc 编译故障排除 | TESTING_GUIDE.md | 故障排除部分 |

### 话题: LLVM 和编译链

| 话题 | 相关文档 | 部分 |
|------|---------|------|
| LLVM 三元组问题 | docs/roc-llvm-sbf-fix.md | 完整文件 |
| LLVM 位码编译 | TESTING_GUIDE.md | 测试 3 |
| SBF 目标编译 | docs/solution-plan-a-implementation.md | 步骤 4 |
| llc 工具使用 | TESTING_GUIDE.md | 测试 3 和故障排除 |

### 话题: Zig 和构建

| 话题 | 相关文档 | 部分 |
|------|---------|------|
| Zig 构建配置 | build.zig | 完整文件 |
| Zig SBF 构建 | TESTING_GUIDE.md | 测试 5 |
| solana-zig 使用 | AGENTS.md | 工具链规范 |
| Zig 构建故障排除 | TESTING_GUIDE.md | 测试 5 故障排除 |

### 话题: 部署和验证

| 话题 | 相关文档 | 部分 |
|------|---------|------|
| 部署到测试网 | TESTING_GUIDE.md | 后续步骤 |
| 功能验证 | TESTING_GUIDE.md | 测试 5 |
| 日志检查 | README.md | v0.2.0 实施进度 |

### 话题: 问题和故障排除

| 话题 | 相关文档 | 部分 |
|------|---------|------|
| 三元组问题 | docs/roc-llvm-sbf-fix.md | 问题描述 |
| 编译错误 | TESTING_GUIDE.md | 各测试的故障排除 |
| 链接错误 | TESTING_GUIDE.md | 测试 5 故障排除 |
| 一般问题 | TESTING_GUIDE.md | FAQ 部分 |

---

## ✍️ 文档维护指南

### 何时创建新文档

- [ ] 当新增加 1+ 小时的工作时
- [ ] 当新增加新的测试流程时
- [ ] 当发现需要记录的关键决策时

### 何时更新现有文档

- [ ] 当完成一个测试步骤时 (更新 TESTING_GUIDE.md)
- [ ] 当改变实施计划时 (更新 IMPLEMENTATION_STATUS.md)
- [ ] 当完成一个 Story 时 (更新 v0.2.0-roc-integration.md)
- [ ] 在会话结束时 (更新 SESSION_WORK_LOG.md)

### 文档风格规范

- ✅ 使用中文编写
- ✅ 使用 Emoji 标记状态 (✅ ❌ ⏳ 🔨)
- ✅ 包含代码示例和命令
- ✅ 提供预期输出和错误处理
- ✅ 提供表格和列表便于查找

---

## 📈 文档完成度

| 文档 | 状态 | 完成度 |
|------|------|--------|
| README.md | ✅ 已完成 | 100% |
| QUICK_START_v0.2.0.md | ✅ 已完成 | 100% |
| TESTING_GUIDE.md | ✅ 已完成 | 100% |
| NEXT_STEPS.md | ✅ 已完成 | 100% |
| IMPLEMENTATION_STATUS.md | ✅ 已完成 | 100% |
| SESSION_WORK_LOG.md | ✅ 已完成 | 100% |
| docs/solution-plan-a-implementation.md | ✅ 已完成 | 100% |
| docs/roc-llvm-sbf-fix.md | ✅ 已完成 | 100% |
| stories/v0.2.0-roc-integration.md | 🔨 进行中 | 80% |
| **总体** | **🔨 进行中** | **90%** |

---

## 🚀 推荐起点

### 对于新开发者
```
1. README.md (5 分钟)
   ↓
2. QUICK_START_v0.2.0.md (30 分钟)
   ↓
3. TESTING_GUIDE.md (参考用)
```

### 对于项目维护者
```
1. IMPLEMENTATION_STATUS.md (10 分钟)
   ↓
2. SESSION_WORK_LOG.md (15 分钟)
   ↓
3. stories/v0.2.0-roc-integration.md (更新)
```

### 对于技术审查者
```
1. docs/solution-plan-a-implementation.md (30 分钟)
   ↓
2. docs/roc-llvm-sbf-fix.md (20 分钟)
   ↓
3. TESTING_GUIDE.md (验证)
```

---

## 📞 快速问答

### Q: 我应该从哪个文档开始？
A: 根据你的角色选择上面"推荐起点"中的路径。

### Q: 我需要执行验证，最快的方式是什么？
A: 运行 `QUICK_START_v0.2.0.md` 中的一键验证脚本。

### Q: 我遇到问题了，怎么找解决方案？
A: 查看 `TESTING_GUIDE.md` 的"故障排除"部分。

### Q: 项目的总体技术方案是什么？
A: 阅读 `docs/solution-plan-a-implementation.md`。

### Q: 当前项目进度如何？
A: 查看 `IMPLEMENTATION_STATUS.md` 和 `stories/v0.2.0-roc-integration.md`。

### Q: 如何更新进度和文档？
A: 参考"文档维护指南"部分。

---

## 📝 最后更新记录

| 日期 | 文档 | 变更 |
|------|------|------|
| 2026-01-04 | 本索引 | 创建文档索引 |
| 2026-01-04 | SESSION_WORK_LOG.md | 创建工作日志 |
| 2026-01-04 | TESTING_GUIDE.md | 创建测试指南 |
| 2026-01-04 | IMPLEMENTATION_STATUS.md | 创建实施状态 |
| 2026-01-04 | QUICK_START_v0.2.0.md | 创建快速开始 |
| 2026-01-04 | README.md | 更新 v0.2.0 进度 |
| 2026-01-04 | v0.2.0 Story | 更新验收标准 |

---

**导航**: [README.md](README.md) | [QUICK_START_v0.2.0.md](QUICK_START_v0.2.0.md) | [TESTING_GUIDE.md](TESTING_GUIDE.md)

**问题反馈**: 如发现文档问题或遗漏，请在 Story 中记录。
