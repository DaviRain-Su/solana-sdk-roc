# AGENTS.md - AI 编码代理规范 (Zig 项目模板)

> 本模板定义了 AI 编码代理在 Zig 项目中的行为准则。
> 使用时请根据具体项目进行配置。

**Zig 版本**: 0.15.x (最低要求)

---

## 项目配置（使用前必填）

```yaml
# 项目基本信息
project_name: "Your Project Name"
description: "项目简短描述"

# 文档语言
doc_language: "中文"  # 或 "English"

# 项目结构
src_dir: "src/"
docs_dir: "docs/"
examples_dir: "examples/"

# 可选：项目特定规则
sensitive_data_wrapper: "Secret"  # 敏感数据包装类型名
decimal_type: "Decimal"           # 精确计算类型名（如金融项目）
```

---

## 文档语言规范

**强制规则**: 项目中所有文档必须使用配置的语言编写。

- README.md、ROADMAP.md、所有 Story 文件使用配置的文档语言
- 代码注释可以使用英文（遵循 Zig 惯例）
- 变量名、函数名使用英文（编程规范）

---

## 开发流程规范（文档驱动开发）

**核心原则**: 文档先行，代码跟随，测试验证，文档收尾。

### 开发周期

每个功能/修改都必须遵循以下流程：

```
┌─────────────────────────────────────────────────────────────────┐
│  1. 文档准备阶段                                                   │
│     ├── 更新/创建设计文档 (docs/design/)                          │
│     ├── 更新 ROADMAP.md (如果是新功能)                            │
│     └── 更新 Story 文件 (stories/)                                │
├─────────────────────────────────────────────────────────────────┤
│  2. 编码阶段                                                       │
│     ├── 实现功能代码                                               │
│     ├── 添加代码注释                                               │
│     ├── 同步更新 docs/ 对应文档（必须！）                          │
│     └── 更新模块文档                                               │
├─────────────────────────────────────────────────────────────────┤
│  3. 测试阶段                                                       │
│     ├── 单元测试 (zig test src/xxx.zig)                           │
│     ├── 集成测试 (zig build test)                                 │
│     └── 示例测试 (examples/*.zig)                                 │
├─────────────────────────────────────────────────────────────────┤
│  4. 文档收尾阶段                                                   │
│     ├── 更新 CHANGELOG.md                                         │
│     ├── 更新 API 文档 (如有变化)                                   │
│     └── 更新 README.md (如有用户可见变化)                          │
└─────────────────────────────────────────────────────────────────┘
```

### 强制规则

**每次代码修改必须通过测试验证**

所有代码修改完成后必须立即运行测试验证：

```bash
# 运行完整测试套件
zig build test

# 或运行特定模块测试
zig test src/module.zig
```

**测试失败处理原则**:
- ❌ **禁止**: 提交测试失败的代码
- ❌ **禁止**: 为了"暂时修复"而禁用测试或添加不正确的代码
- ✅ **必须**: 修复所有编译错误和测试失败，直到完全通过
- ✅ **必须**: 如果遇到无法立即解决的错误，撤销修改或寻求帮助解决
- ✅ **必须**: 确保 `zig build test` 完全通过后才算完成修改

**代码实现要求**:
- ✅ **必须**: 所有代码实现必须是真实功能实现，不能使用模拟(placeholder/mock)实现
- ✅ **必须**: 功能必须实际可用，能够执行预期的操作
- ❌ **禁止**: 使用 `undefined`、`unreachable` 或其他placeholder值
- ❌ **禁止**: 实现返回硬编码值或模拟数据的函数，除非是测试辅助函数

**验证流程**:
1. 修改代码后立即运行 `zig build test`
2. 如果测试失败，立即修复所有错误
3. 重复步骤1-2直到测试完全通过
4. 只有在测试通过后，才能进行下一步开发

---

### 阶段详解

#### 1. 文档准备阶段

在写任何代码之前，必须先准备文档：

```markdown
# 检查清单

- [ ] 功能是否已在 ROADMAP.md 中规划？
- [ ] 是否需要新的设计文档 (RFC)？
- [ ] Story 文件是否已创建/更新？
```

#### 2. 编码阶段

编码时同步更新相关文档：

```zig
/// 每个公共 API 必须有文档注释
///
/// 示例:
/// ```zig
/// const result = try api.doSomething(.{...});
/// ```
pub fn doSomething(args: Args) !Result {
    // 实现...
}
```

#### 3. 测试阶段

**强制要求**: 所有测试必须完全通过，任何测试失败都必须立即修复（见强制规则）。

测试分三个层次：

```bash
# 1. 单元测试 - 测试单个模块
zig test src/module/file.zig

# 2. 集成测试 - 测试整个项目
zig build test

# 3. 完整测试套件
zig test src/root.zig

# 4. 示例测试 - 验证用户场景
zig build run-example_name
```

### 测试质量要求（强制）

**核心原则**: 所有测试必须通过，且无内存泄漏和段错误。

#### 必须满足的条件

1. **所有测试通过**: `zig build test` 和 `zig test src/root.zig` 必须 100% 通过
2. **无内存泄漏**: 使用 `std.testing.allocator` 会自动检测内存泄漏
3. **无段错误**: 测试不能崩溃或产生未定义行为

#### 内存泄漏检测

Zig 的 `std.testing.allocator` 会自动检测内存泄漏：

```zig
test "no memory leak" {
    const allocator = std.testing.allocator;

    // 如果忘记 free，测试会失败
    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer);  // ✅ 必须释放

    // 测试代码...
}
```

#### 常见内存问题及解决方案

```zig
// ❌ 错误 - 内存泄漏
test "leaky test" {
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 100);
    // 忘记 free -> 测试失败: memory leak detected
}

// ✅ 正确 - 使用 defer 释放
test "clean test" {
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 100);
    defer allocator.free(data);
    // 测试代码...
}

// ❌ 错误 - ArrayList 内存泄漏
test "leaky arraylist" {
    const allocator = std.testing.allocator;
    var list = try std.ArrayList(u8).initCapacity(allocator, 16);
    // 忘记 deinit -> 内存泄漏
}

// ✅ 正确 - ArrayList 正确释放
test "clean arraylist" {
    const allocator = std.testing.allocator;
    var list = try std.ArrayList(u8).initCapacity(allocator, 16);
    defer list.deinit();
    // 测试代码...
}
```

#### 段错误预防

```zig
// ❌ 危险 - 可能段错误
test "dangerous" {
    var ptr: ?*u8 = null;
    _ = ptr.?.*;  // 解引用 null -> 段错误
}

// ✅ 安全 - 检查 null
test "safe" {
    var ptr: ?*u8 = null;
    if (ptr) |p| {
        _ = p.*;
    }
}

// ❌ 危险 - 数组越界
test "out of bounds" {
    const arr = [_]u8{ 1, 2, 3 };
    _ = arr[5];  // 越界 -> 段错误或未定义行为
}

// ✅ 安全 - 边界检查
test "bounds checked" {
    const arr = [_]u8{ 1, 2, 3 };
    if (5 < arr.len) {
        _ = arr[5];
    }
}
```

#### 提交前测试检查清单

```markdown
# 测试检查清单

- [ ] `zig build test` 通过
- [ ] `zig test src/root.zig` 通过
- [ ] 无 "memory leak detected" 错误
- [ ] 无段错误或崩溃
- [ ] 新代码有对应的测试
- [ ] 测试覆盖正常路径和错误路径
```

#### 4. 文档收尾阶段

每次开发完成后必须更新：

```markdown
# CHANGELOG.md 更新模板

### Session YYYY-MM-DD-NNN

**日期**: YYYY-MM-DD
**目标**: 简要描述

#### 完成的工作
1. ...
2. ...

#### 测试结果
- 单元测试: X tests passed
- 集成测试: passed/failed

#### 下一步
- [ ] ...
```

---

## Stories 文件规范（强制）

**核心原则**: 每个版本必须有对应的 Story 文件，且必须与实现状态保持同步。

### Story 文件结构

```
stories/
├── v0.1.0-core-types.md      # v0.1.0 核心功能
├── v0.2.0-extensions.md      # v0.2.0 扩展功能
└── v0.3.0-advanced.md        # v0.3.0 高级功能
```

### Story 文件模板

```markdown
# Story: vX.Y.Z 功能名称

> 简短描述

## 目标

实现的功能列表...

## 验收标准

### 模块名 (module.zig)

- [ ] 功能 1
- [ ] 功能 2
- [ ] 单元测试

### 集成

- [ ] root.zig 导出
- [ ] 文档更新
- [ ] 测试通过

## 完成状态

- 开始日期: YYYY-MM-DD
- 完成日期: YYYY-MM-DD
- 状态: ⏳ 进行中 / ✅ 已完成
```

### Story 同步规则（强制）

| 时机 | 必须执行的操作 |
|------|---------------|
| 开始新版本开发 | 创建对应的 Story 文件，列出所有验收标准 |
| 完成单个功能 | 将对应的 `[ ]` 改为 `[x]` |
| 完成整个版本 | **严格检查：只有当所有 `[ ]` 都变为 `[x]` 时，才能更新完成日期和状态为 ✅** |
| 添加新功能 | 在 Story 中添加对应的验收标准 |
| 版本发布前 | 确保所有 `[ ]` 都变为 `[x]` |

### 禁止行为

1. **禁止**: 代码完成但 Story 未更新
2. **禁止**: Story 标记完成但代码未实现
3. **禁止**: 跳过 Story 直接开发
4. **禁止**: 版本发布时 Story 中仍有 `[ ]`
5. **🚨 强制约束**: **绝对禁止在部分功能完成时将整个Story标记为✅完成**。只有当Story中所有验收标准都标记为`[x]`时，才能更新状态为✅。

### Story 完成检查命令

```bash
# 检查 Story 中未完成的任务
grep -rn "\[ \]" stories/

# 检查 Story 状态
grep -rn "状态:" stories/

# 验证 Story 和 ROADMAP 一致性
echo "=== ROADMAP ===" && grep -n "✅\|⏳" ROADMAP.md
echo "=== Stories ===" && grep -rn "状态:" stories/
```

### 禁止行为

1. **禁止**: 代码完成但 Story 未更新
2. **禁止**: Story 标记完成但代码未实现
3. **禁止**: 跳过 Story 直接开发
4. **禁止**: 版本发布时 Story 中仍有 `[ ]`

---

## 文档同步更新规范（强制）

**核心原则**: 代码和文档必须同步更新，不允许代码实现后文档滞后。

### docs/ 目录结构镜像 src/

```
src/                          docs/
├── types/                    ├── types/
│   ├── decimal.zig          │   ├── decimal.md
│   ├── address.zig          │   ├── address.md
│   └── ...                  │   └── ...
├── module_a/                 ├── module_a/
│   └── ...                  │   └── README.md
└── ...                       └── ...
```

### 文档更新触发条件

| 代码变更类型 | 必须更新的文档 |
|-------------|---------------|
| 新增模块 | `docs/<module>/README.md` + 各文件对应的 `.md` |
| 新增类型 | `docs/types/<type>.md` + `docs/design/types.md` |
| 新增公共函数 | 对应模块的 `.md` 文件 |
| 修改函数签名 | 对应模块的 `.md` 文件 |
| 修改行为/逻辑 | 对应模块的 `.md` 文件 |
| 新增错误类型 | `docs/error.md` |
| Story 完成 | ROADMAP.md 对应任务标记 ✅ |

---

## 阶段完成前检查规范（强制）

**核心原则**: 在开始下一个版本阶段之前，必须检查并解决之前版本的遗留问题。

### 文档扫描命令

```bash
# 1. 扫描 ROADMAP.md 中的待办项
grep -n "⏳" ROADMAP.md

# 2. 扫描 stories/ 中未完成的任务
grep -rn "\[ \]" stories/
grep -rn "⏳" stories/

# 3. 扫描 docs/ 中的 TODO 和未完成标记
grep -rn "TODO\|FIXME\|⏳\|\[ \]" docs/

# 4. 扫描代码中的 TODO 和 FIXME
grep -rn "TODO\|FIXME\|XXX" src/ --include="*.zig"

# 5. 一键扫描所有
echo "=== ROADMAP.md ===" && grep -n "⏳" ROADMAP.md && \
echo "=== stories/ ===" && grep -rn "\[ \]\|⏳" stories/ && \
echo "=== docs/ ===" && grep -rn "TODO\|FIXME\|⏳\|\[ \]" docs/ && \
echo "=== src/ ===" && grep -rn "TODO\|FIXME\|XXX" src/ --include="*.zig"
```

### 未完成标记说明

| 标记 | 位置 | 含义 |
|------|------|------|
| `⏳` | ROADMAP.md, stories/, docs/ | 待开始或进行中 |
| `🔨` | ROADMAP.md, stories/ | 正在进行中 |
| `[ ]` | stories/, docs/ | 未完成的检查项/任务 |
| `TODO` | 代码注释, docs/ | 待实现的功能 |
| `FIXME` | 代码注释, docs/ | 需要修复的问题 |
| `XXX` | 代码注释 | 需要注意或重构的代码 |

### 阶段完成标准

只有满足以下所有条件，才能标记版本为"已完成"：

1. **当前版本核心功能 100% 完成**
2. **所有测试通过**，无内存泄漏
3. **文档状态同步**
4. **遗留问题已评估并记录**

---

## 构建命令

```bash
# 构建项目
zig build

# 运行可执行文件
zig build run

# 运行所有测试
zig build test

# 运行单个文件测试
zig test src/module/file.zig

# 使用优化构建
zig build -Doptimize=ReleaseFast

# 清理构建缓存
rm -rf .zig-cache zig-out
```

---

## 代码风格规范

### 命名约定

```zig
// 类型名: PascalCase
const MyStruct = struct {};
const ClientState = enum {};

// 函数和变量: camelCase
fn processOrder() void {}
var orderCount: u32 = 0;

// 常量: snake_case 或 SCREAMING_SNAKE_CASE
const max_retries = 3;
const DEFAULT_TIMEOUT: u64 = 30000;

// 文件名: snake_case.zig
// order_builder.zig, http_client.zig
```

### 导入顺序

```zig
const std = @import("std");

// 导入分组：先 std，再项目模块
const types = @import("types/mod.zig");
const Decimal = types.Decimal;
```

### 文档注释

所有公共 API 必须有文档注释：

```zig
/// 创建新的资源
///
/// 参数:
///   - allocator: 内存分配器
///   - config: 配置选项
///
/// 返回: 资源对象
/// 错误: OutOfMemory, InvalidConfig
pub fn create(allocator: std.mem.Allocator, config: Config) !Resource {
    // ...
}
```

### 重写项目源引用规范（强制）

**核心原则**: 本项目是 Rust Solana SDK 的 Zig 重写实现，每个模块必须明确标识其对应的 Rust 源模块。

#### 强制规则

每个 Zig 模块文件**顶部**必须包含源引用注释，格式如下：

```zig
//! Zig implementation of Solana SDK's [模块名]
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/[crate-name]/src/lib.rs
//!
//! 模块简短描述...
```

#### 完整示例

```zig
//! Zig implementation of Solana SDK's pubkey module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs
//!
//! This module provides the Pubkey type representing a Solana public key (Ed25519).
//! It includes utilities for creating, parsing, and manipulating public keys.

const std = @import("std");

/// A Solana public key (32 bytes)
/// 
/// Rust equivalent: `solana_pubkey::Pubkey`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs
pub const Pubkey = struct {
    // ...
};
```

#### solana-sdk 仓库结构

**重要**: solana-sdk 是独立的 monorepo，每个模块是独立的 crate。

| Zig 模块 | Rust crate 路径 | 链接示例 |
|----------|----------------|---------|
| `public_key.zig` | `pubkey/` | `solana-sdk/blob/master/pubkey/src/lib.rs` |
| `hash.zig` | `hash/` | `solana-sdk/blob/master/hash/src/lib.rs` |
| `signature.zig` | `signature/` | `solana-sdk/blob/master/signature/src/lib.rs` |
| `keypair.zig` | `keypair/` | `solana-sdk/blob/master/keypair/src/lib.rs` |
| `account.zig` | `account-info/` | `solana-sdk/blob/master/account-info/src/lib.rs` |
| `instruction.zig` | `instruction/` | `solana-sdk/blob/master/instruction/src/lib.rs` |
| `clock.zig` | `clock/` | `solana-sdk/blob/master/clock/src/lib.rs` |
| `rent.zig` | `rent/` | `solana-sdk/blob/master/rent/src/lib.rs` |
| `slot_hashes.zig` | `slot-hashes/` | `solana-sdk/blob/master/slot-hashes/src/lib.rs` |
| `log.zig` | `program-log/` | `solana-sdk/blob/master/program-log/src/lib.rs` |
| `syscalls.zig` | `define-syscall/` | `solana-sdk/blob/master/define-syscall/src/lib.rs` |
| `entrypoint.zig` | `program-entrypoint/` | `solana-sdk/blob/master/program-entrypoint/src/lib.rs` |
| `error.zig` | `program-error/` | `solana-sdk/blob/master/program-error/src/lib.rs` |
| `blake3.zig` | `blake3-hasher/` | `solana-sdk/blob/master/blake3-hasher/src/lib.rs` |

#### 引用格式规范

| 元素 | 格式 | 示例 |
|------|------|------|
| 模块级引用 | `//!` 文档注释 | 文件顶部 |
| 类型级引用 | `///` 文档注释 | struct/enum 定义前 |
| 函数级引用 | `///` 文档注释（可选） | 复杂函数实现前 |
| 行号引用 | `#L{行号}` 或 `#L{起始}-L{结束}` | `#L50` 或 `#L50-L100` |

#### Rust 源仓库地址

| 仓库 | 用途 | 地址 |
|------|------|------|
| solana-sdk | 主 SDK 实现（独立 monorepo） | `https://github.com/anza-xyz/solana-sdk` |
| agave | Solana 验证器 | `https://github.com/anza-xyz/agave` |
| solana-program-library | SPL 程序 | `https://github.com/solana-labs/solana-program-library` |

#### 链接验证规范（强制）

**核心原则**: 添加的所有 GitHub 链接必须是可访问的有效链接。

**验证步骤**:
1. 添加链接前，必须在浏览器中验证链接可访问
2. 使用正确的仓库结构路径（参考上表）
3. 确保分支名称正确（`master` 或具体版本标签）

**常见错误**:
- ❌ `sdk/src/pubkey.rs` - 错误：旧的路径结构
- ❌ `sdk/pubkey/src/lib.rs` - 错误：多余的 `sdk/` 前缀
- ✅ `pubkey/src/lib.rs` - 正确：直接使用 crate 名称

**验证命令**:
```bash
# 验证链接是否可访问
curl -s -o /dev/null -w "%{http_code}" "https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs"
# 应返回 200
```

#### 分支/标签规范

- 优先使用稳定版本标签（如 `v2.0.0`）
- 如无对应标签，使用 `master` 分支
- 在注释中说明引用的版本：`//! Based on solana-sdk v2.0.0`

#### 禁止行为

- ❌ **禁止**: 创建新模块而不添加 Rust 源引用
- ❌ **禁止**: 使用无效或无法访问的 GitHub 链接
- ❌ **禁止**: 省略模块级 `//!` 文档注释
- ❌ **禁止**: 不验证链接直接添加

#### 审查要点

- [ ] 每个 `.zig` 文件顶部都有 `//!` 源引用注释
- [ ] GitHub 链接格式正确且**已验证可访问**
- [ ] 使用正确的仓库路径结构（参考 solana-sdk 仓库结构表）
- [ ] 复杂类型/函数有对应的 Rust 源引用
- [ ] 版本/分支信息明确

### 单元测试完整性规范（强制）

**核心原则**: 重写模块的单元测试必须**完全覆盖**原 Rust 代码中的所有测试用例，只许多不许少。

#### 强制规则

1. **完全匹配**: 每个 Rust 模块中的 `#[test]` 函数都必须在 Zig 中有对应的 `test` 块
2. **测试名称对应**: Zig 测试名称应能清晰对应 Rust 测试函数名
3. **测试逻辑一致**: 测试的输入、预期输出、边界条件必须与 Rust 版本一致
4. **可以增加**: 允许添加额外的 Zig 特有测试（如内存安全测试）
5. **不可遗漏**: 禁止遗漏任何 Rust 源码中存在的测试

#### 工作流程

```
1. 查看 Rust 源文件中的所有 #[test] 函数
2. 为每个 Rust 测试创建对应的 Zig test 块
3. 确保测试逻辑和断言完全一致
4. 可选：添加 Zig 特有的额外测试
```

#### 测试命名规范

```zig
// Rust: #[test] fn test_create_program_address() { ... }
// Zig:
test "pubkey: create program address" {
    // 测试逻辑与 Rust 版本一致
}

// Rust: #[test] fn test_find_program_address() { ... }
// Zig:
test "pubkey: find program address" {
    // 测试逻辑与 Rust 版本一致
}
```

#### 测试注释引用

每个测试应注明对应的 Rust 测试：

```zig
/// Rust test: test_create_program_address
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/pubkey/src/lib.rs#L500
test "pubkey: create program address" {
    // ...
}
```

#### 验证命令

```bash
# 1. 查看 Rust 源码中的测试数量
curl -s "https://raw.githubusercontent.com/anza-xyz/solana-sdk/master/pubkey/src/lib.rs" | grep -c "#\[test\]"

# 2. 查看 Zig 模块中的测试数量  
grep -c "^test " src/public_key.zig

# 3. 对比确保 Zig 测试数量 >= Rust 测试数量
```

#### 禁止行为

- ❌ **禁止**: 遗漏 Rust 源码中存在的任何测试
- ❌ **禁止**: 简化或跳过复杂的测试用例
- ❌ **禁止**: 修改测试预期值使其"通过"
- ❌ **禁止**: 使用 `// TODO: add test` 注释代替实际测试

#### 审查检查清单

- [ ] 列出 Rust 源码中所有 `#[test]` 函数
- [ ] 确认每个 Rust 测试在 Zig 中有对应实现
- [ ] 验证测试逻辑与 Rust 版本一致
- [ ] 运行 `zig build test` 确保所有测试通过

### 类型定义统一规范

**强制规则**: 所有基础类型必须在统一位置定义，避免重复定义。

#### 禁止行为
- ❌ 不要在多个文件中重复定义相同的类型
- ❌ 不要在模块内部重新定义已存在的类型（如 Result、Option）

#### 正确做法
- ✅ 在 `result.zig` 中定义 `Result` 类型，并在其他地方通过导入使用
- ✅ 在 `option.zig` 中定义 `Option` 类型，并在其他地方通过导入使用
- ✅ 在 `root.zig` 中统一导出所有基础类型

#### 类型引用示例
```zig
// ✅ 正确 - 通过导入使用统一定义的类型
const Result = @import("result.zig").Result;
const Option = @import("option.zig").Option;

// ✅ 正确 - 从 root.zig 导入
const { Result, Option } = @import("root.zig");

// ❌ 错误 - 重复定义
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,
    };
}
```

#### 审查要点
- 检查所有 `.zig` 文件，确保没有重复的类型定义
- 验证所有类型都通过正确的导入路径引用
- 确保 root.zig 包含所有必要的类型导出

---

## Zig 0.15 API 要求（关键）

### ArrayList（需要 allocator 参数）

```zig
// 初始化 - 始终使用 initCapacity
var list = try std.ArrayList(T).initCapacity(allocator, 16);
defer list.deinit();

// ❌ 错误 - Zig 0.15 的 append 需要 allocator
list.append(item);
try list.append(item);

// ✅ 正确 - 传入 allocator 参数
try list.append(allocator, item);
try list.appendSlice(allocator, items);
const ptr = try list.addOne(allocator);
try list.ensureTotalCapacity(allocator, n);
const owned = try list.toOwnedSlice(allocator);

// AssumeCapacity 系列不需要 allocator
list.appendAssumeCapacity(item);
```

### ArrayList API 速查表（Zig 0.15+）

| 方法 | 需要 allocator | 说明 |
|------|---------------|------|
| `initCapacity(allocator, n)` | 是 | 初始化并预分配容量 |
| `deinit()` | 否 | 释放内存 |
| `append(allocator, item)` | 是 | 添加单个元素 |
| `appendSlice(allocator, items)` | 是 | 添加多个元素 |
| `addOne(allocator)` | 是 | 获取新元素指针 |
| `ensureTotalCapacity(allocator, n)` | 是 | 确保容量 |
| `toOwnedSlice(allocator)` | 是 | 转换为拥有的切片 |
| `appendAssumeCapacity(item)` | 否 | 假设容量足够 |
| `items` 字段 | 否 | 只读访问 |

### HashMap

```zig
// Managed（StringHashMap, AutoHashMap）- 存储 allocator
var map = std.StringHashMap(V).init(allocator);
defer map.deinit();
try map.put(key, value);  // 不需要 allocator

// Unmanaged（StringHashMapUnmanaged）- 需要 allocator
var umap = std.StringHashMapUnmanaged(V){};
defer umap.deinit(allocator);
try umap.put(allocator, key, value);  // 需要 allocator

// 使用 getOrPut 避免重复查找
const result = try map.getOrPut(key);
if (!result.found_existing) {
    result.value_ptr.* = new_value;
}
```

### HTTP Client（Zig 0.15+ request/response API）

**注意**: Zig 0.15 完全重构了 HTTP Client API，移除了 `fetch()` 方法。

```zig
var client: std.http.Client = .{ .allocator = allocator };
defer client.deinit();

// 解析 URI
const uri = std.Uri.parse(url) catch return error.BadRequest;

// 创建请求
var req = client.request(.GET, uri, .{
    .extra_headers = &.{
        .{ .name = "Accept", .value = "application/json" },
    },
}) catch return error.ConnectionFailed;
defer req.deinit();

// 发送 GET 请求（无 body）
req.sendBodiless() catch return error.ConnectionFailed;

// 或发送 POST 请求（带 body）
// req.transfer_encoding = .{ .content_length = body.len };
// var body_writer = req.sendBodyUnflushed(&.{}) catch return error.ConnectionFailed;
// body_writer.writer.writeAll(body) catch return error.ConnectionFailed;
// body_writer.end() catch return error.ConnectionFailed;
// if (req.connection) |conn| {
//     conn.flush() catch return error.ConnectionFailed;
// }

// 接收响应头
var response = req.receiveHead(&.{}) catch return error.ConnectionFailed;

// 检查状态码
if (response.head.status != .ok) {
    return error.HttpError;
}

// 读取响应体
var reader = response.reader(&.{});
const body = reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return error.ReadFailed;
defer allocator.free(body);
```

### std.json

```zig
// 解析并释放
const parsed = try std.json.parseFromSlice(MyStruct, allocator, json_string, .{});
defer parsed.deinit();
const data = parsed.value;

// 序列化
const json_output = try std.json.stringifyAlloc(allocator, data, .{});
defer allocator.free(json_output);
```

### std.fmt

```zig
// 分配式格式化
const formatted = try std.fmt.allocPrint(allocator, "value: {d}", .{42});
defer allocator.free(formatted);

// 非分配式格式化（使用缓冲区）
var buffer: [256]u8 = undefined;
const result = try std.fmt.bufPrint(&buffer, "value: {d}", .{42});
```

### 自定义 format 函数（Zig 0.15+）

```zig
// ❌ 旧版本
pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.writeAll("...");
}
// 使用: std.fmt.bufPrint(&buf, "{}", .{value});

// ✅ Zig 0.15+ (使用 {f} 格式)
pub fn format(self: Self, writer: anytype) !void {
    _ = self;
    try writer.writeAll("...");
}
// 使用: std.fmt.bufPrint(&buf, "{f}", .{value});
```

### 类型信息枚举（Zig 0.15+）

```zig
// ❌ 旧版本
if (@typeInfo(T) == .Slice) { ... }
if (info.pointer.size == .Slice) { ... }

// ✅ Zig 0.15+
if (@typeInfo(T) == .slice) { ... }
if (info.pointer.size == .slice) { ... }
```

**影响的枚举**:
- `.Slice` → `.slice`
- `.Pointer` → `.pointer`
- `.Struct` → `.@"struct"`
- `.Enum` → `.@"enum"`
- `.Union` → `.@"union"`
- `.Array` → `.array`
- `.Optional` → `.optional`

### Ed25519 加密 API（Zig 0.15+）

**注意**: Zig 0.15 对 Ed25519 API 进行了重大重构，密钥类型现在是结构体而非原始字节数组。

#### 类型变更

```zig
const Ed25519 = std.crypto.sign.Ed25519;

// ❌ 旧版本 - SecretKey 是 [32]u8
const secret: [32]u8 = ...;
const kp = Ed25519.KeyPair.fromSecretKey(secret);

// ✅ Zig 0.15+ - SecretKey 是结构体，包含 64 字节 (seed + public_key)
const Ed25519 = std.crypto.sign.Ed25519;

// SecretKey 结构体
pub const SecretKey = struct {
    bytes: [64]u8,  // 前 32 字节是 seed，后 32 字节是 public key
    
    pub fn seed(self: SecretKey) [32]u8;           // 获取 seed
    pub fn publicKeyBytes(self: SecretKey) [32]u8; // 获取公钥字节
    pub fn fromBytes(bytes: [64]u8) !SecretKey;    // 从字节创建
    pub fn toBytes(self: SecretKey) [64]u8;        // 转换为字节
};

// PublicKey 结构体
pub const PublicKey = struct {
    bytes: [32]u8,
    
    pub fn fromBytes(bytes: [32]u8) !PublicKey;
    pub fn toBytes(self: PublicKey) [32]u8;
};
```

#### KeyPair 使用方式

```zig
const Ed25519 = std.crypto.sign.Ed25519;

// ✅ 生成随机密钥对
const kp = Ed25519.KeyPair.generate();

// ✅ 从 32 字节 seed 确定性生成
const seed: [32]u8 = ...;
const kp = try Ed25519.KeyPair.generateDeterministic(seed);

// ✅ 从 SecretKey 结构体创建
var secret_bytes: [64]u8 = ...;
const secret_key = try Ed25519.SecretKey.fromBytes(secret_bytes);
const kp = try Ed25519.KeyPair.fromSecretKey(secret_key);

// ✅ 获取公钥字节
const pubkey_bytes: [32]u8 = kp.public_key.toBytes();

// ✅ 获取 seed（用于重建密钥对）
const seed: [32]u8 = kp.secret_key.seed();

// ✅ 获取完整密钥字节（64 字节）
const full_bytes: [64]u8 = kp.secret_key.toBytes();
```

#### Signature 使用方式

```zig
const Ed25519 = std.crypto.sign.Ed25519;

// ❌ 旧版本 - fromBytes 返回 error union
const sig = try Ed25519.Signature.fromBytes(bytes);

// ✅ Zig 0.15+ - fromBytes 不返回 error union
const sig = Ed25519.Signature.fromBytes(bytes);

// ✅ 签名消息
const signature = try kp.sign(message, null);  // null = 确定性签名
const sig_bytes: [64]u8 = signature.toBytes();

// ✅ 验证签名
try sig.verify(message, kp.public_key);
```

#### 常见迁移错误

| 错误消息 | 原因 | 解决方案 |
|---------|------|---------|
| `expected type 'SecretKey', found '[32]u8'` | SecretKey 现在是结构体 | 使用 `generateDeterministic(seed)` 或 `SecretKey.fromBytes()` |
| `expected error union type, found 'Signature'` | `Signature.fromBytes` 不再返回错误 | 移除 `try` |
| `type 'PublicKey' is not indexable` | PublicKey 是结构体 | 使用 `.toBytes()` 获取字节 |
| `no member named 'secret_key' in struct` | 字段访问方式变更 | 检查 KeyPair 结构体定义 |

#### Keypair 模块实现示例

```zig
//! keypair.zig - Ed25519 密钥对管理

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;

pub const Keypair = struct {
    inner: Ed25519.KeyPair,
    
    /// 生成随机密钥对
    pub fn generate() Keypair {
        return .{ .inner = Ed25519.KeyPair.generate() };
    }
    
    /// 从 32 字节 seed 创建
    pub fn fromSeed(seed: [32]u8) !Keypair {
        const kp = Ed25519.KeyPair.generateDeterministic(seed) catch {
            return error.InvalidSeed;
        };
        return .{ .inner = kp };
    }
    
    /// 从 64 字节创建 (seed + public_key 格式)
    pub fn fromBytes(bytes: []const u8) !Keypair {
        if (bytes.len != 64) return error.InvalidLength;
        
        var secret_bytes: [64]u8 = undefined;
        @memcpy(&secret_bytes, bytes);
        
        const secret_key = Ed25519.SecretKey.fromBytes(secret_bytes) catch {
            return error.InvalidSecretKey;
        };
        const kp = Ed25519.KeyPair.fromSecretKey(secret_key) catch {
            return error.PublicKeyMismatch;
        };
        return .{ .inner = kp };
    }
    
    /// 获取 64 字节表示
    pub fn toBytes(self: Keypair) [64]u8 {
        return self.inner.secret_key.toBytes();
    }
    
    /// 获取 32 字节 seed
    pub fn seed(self: Keypair) [32]u8 {
        return self.inner.secret_key.seed();
    }
    
    /// 获取公钥字节
    pub fn pubkeyBytes(self: Keypair) [32]u8 {
        return self.inner.public_key.toBytes();
    }
    
    /// 签名消息
    pub fn sign(self: Keypair, message: []const u8) ![64]u8 {
        const sig = try self.inner.sign(message, null);
        return sig.toBytes();
    }
};
```

---

## 内存管理

### 资源清理

```zig
// 始终使用 defer 清理
const buffer = try allocator.alloc(u8, size);
defer allocator.free(buffer);

// 使用 errdefer 处理错误路径清理
fn createResource(allocator: Allocator) !*Resource {
    const res = try allocator.create(Resource);
    errdefer allocator.destroy(res);

    res.data = try allocator.alloc(u8, 100);
    errdefer allocator.free(res.data);

    try res.initialize();
    return res;
}
```

### Arena Allocator 用于临时分配

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const temp = arena.allocator();
// arena.deinit() 会一次性释放所有分配
```

### 字符串所有权

```zig
// 借用 - 不要释放
fn process(borrowed: []const u8) void {
    // 只读，不能释放
}

// 拥有 - 调用者必须释放
fn createString(allocator: std.mem.Allocator) ![]u8 {
    return try allocator.dupe(u8, "owned string");
}

const owned = try createString(allocator);
defer allocator.free(owned);
```

---

## 错误处理

```zig
// ❌ 错误 - 静默忽略错误
const result = doSomething() catch null;

// ✅ 正确 - 传播错误
const result = try doSomething();

// ✅ 正确 - 有意义的错误处理
const result = doSomething() catch |err| {
    std.log.err("Failed: {}", .{err});
    return err;
};
```

---

## 项目特定规则（可选配置）

### 敏感数据处理

```zig
// ❌ 错误 - 原始敏感数据
const Credentials = struct {
    secret: []const u8,      // 可能被意外打印
};

// ✅ 正确 - 使用 Secret 包装
const Credentials = struct {
    secret: Secret([]const u8),
    passphrase: Secret([]const u8),
};

// Secret.format() 输出 "[REDACTED]"
```

### 精确计算（金融项目）

```zig
// ❌ 永远不要用 f64 处理金钱
const price: f64 = 0.65;
const total = price * 100.0;  // 可能是 64.99999999...

// ✅ 正确 - 使用 Decimal
const price = try Decimal.fromString("0.65");
const size = try Decimal.fromString("100");
const total = price.mul(size);  // 精确的 65.00
```

### 日志规范

```zig
// ❌ 错误 - 泄露敏感信息
std.log.info("API Key: {s}", .{credentials.key});

// ✅ 正确 - 安全日志
std.log.info("Request to {s}", .{endpoint});
std.log.debug("Order ID: {s}", .{order_id});
```

### 禁止 async/await

Zig 0.11+ 移除了原生 async/await。使用同步代码或线程：

```zig
// 同步（推荐）
const result = try fetchData();

// 并发操作使用线程
const thread = try std.Thread.spawn(.{}, workerFn, .{});
```

---

## 提交前检查清单

### Zig 0.15 API
- [ ] `ArrayList` 使用 `initCapacity` 并向变更方法传入 `allocator`
- [ ] `toOwnedSlice` 传入 `allocator` 参数
- [ ] 区分 Managed（`StringHashMap`）和 Unmanaged（`StringHashMapUnmanaged`）
- [ ] HTTP 请求使用 Zig 0.15 的 `request/response` API（非 fetch）
- [ ] 自定义 format 函数使用 `{f}` 格式说明符
- [ ] @typeInfo 枚举使用小写（如 `.slice` 而非 `.Slice`）

### 内存安全
- [ ] 所有分配都有对应的 `defer`/`errdefer`
- [ ] 使用 `errdefer` 处理错误路径清理
- [ ] 没有使用 `async`/`await`（Zig 0.11+ 已移除）

### 项目规则
- [ ] 敏感数据使用包装类型（如配置）
- [ ] 金融计算使用精确类型（如配置）
- [ ] 日志不包含敏感信息
- [ ] 公共 API 有文档注释
- [ ] **强制**: 每个 `.zig` 文件顶部有 Rust 源引用注释（见重写项目源引用规范）
- [ ] **强制**: 测试必须完全通过：`zig build test` (见强制规则)

### 文档规范
- [ ] 相关文档已同步更新
- [ ] ROADMAP.md 状态正确
- [ ] Story 文件已更新（所有 `[ ]` 改为 `[x]`）
- [ ] Story 完成状态已更新（⏳ → ✅）
- [ ] README.md 已更新（如需要）
- [ ] CHANGELOG.md 已更新

### Story 同步检查
- [ ] `grep -rn "\[ \]" stories/` 无输出（所有任务完成）
- [ ] Story 状态与 ROADMAP 一致

---

## Zig 版本兼容性问题速查

### 常见迁移错误消息

| 错误消息 | 原因 | 解决方案 |
|---------|------|---------|
| `expected 2 argument(s), found 1` | ArrayList.append 需要 allocator | 添加 allocator 参数 |
| `ambiguous format string` | 自定义 format 需要 `{f}` | 使用 `{f}` 而非 `{}` |
| `no field named 'response_storage'` | fetch API 已移除 | 使用 request/response 模式 |
| `member access not allowed on type` | 枚举大小写变更 | 使用小写枚举值 |
| `expected type 'i2'` | compare 返回类型 | 返回 -1, 0, 1 而非枚举 |
| `expected type 'SecretKey', found '[32]u8'` | Ed25519 SecretKey 是结构体 | 使用 `generateDeterministic()` |
| `expected error union type, found 'Signature'` | Signature.fromBytes 不返回错误 | 移除 `try` |
| `type 'PublicKey' is not indexable` | Ed25519 PublicKey 是结构体 | 使用 `.toBytes()` |

### 迁移检查清单

- [ ] ArrayList 方法添加 allocator 参数
- [ ] HTTP 请求改用 request/response 模式
- [ ] 自定义 format 使用 `{f}` 格式
- [ ] @typeInfo 枚举使用小写
- [ ] 检查 compare 函数返回 i2
- [ ] 测试所有网络错误处理
- [ ] Ed25519 密钥使用结构体而非原始字节
- [ ] Signature.fromBytes 移除 `try`

---

## Roc on Solana 项目规范

**项目概述**: 本项目旨在使用 Roc 函数式编程语言实现 Solana 智能合约，通过 Zig 胶水代码桥接 Roc 和 Solana 运行时。

### 项目配置

```yaml
# 项目基本信息
project_name: "Roc on Solana Platform"
description: "使用 Roc 语言在 Solana 上编写智能合约的平台"

# 文档语言
doc_language: "中文"

# 项目结构
src_dir: "src/"
platform_dir: "platform/"
docs_dir: "docs/"
examples_dir: "examples/"
stories_dir: "stories/"

# Roc on Solana 特定规则
roc_compiler_min_version: "0.0.0"  # 当前开发版
zig_sdk_dependency: "solana-program-sdk-zig"
llvm_backend_required: true
perceus_algorithm_enabled: true  # Roc 的引用计数算法
```

### 🚨 工具链规范（强制）

**核心原则**: 本项目使用自定义的 solana-zig-bootstrap 工具链，**禁止使用系统 zig**！

#### Zig 编译器要求

| 项目 | 要求 |
|------|------|
| **编译器路径** | `./solana-zig/zig` |
| **版本** | 0.15.2 (solana-zig-bootstrap) |
| **来源** | https://github.com/joncinque/solana-zig-bootstrap |
| **系统 zig** | ❌ **禁止使用** |

**为什么必须使用 solana-zig？**

标准 Zig 编译器**不支持** Solana 的 SBF (Solana BPF) 目标架构：
- 标准 Zig 没有 `sbf` CPU 架构
- 标准 Zig 没有 `solana` 操作系统目标
- 使用系统 zig 会导致编译错误：`enum 'Target.Cpu.Arch' has no member named 'sbf'`

solana-zig-bootstrap 是修改版的 Zig，添加了：
- `sbf` CPU 架构支持
- `solana` 操作系统目标
- 原生 SBF 链接器支持（无需 sbpf-linker）

#### 正确的构建命令

```bash
# ✅ 正确 - 使用 solana-zig
./solana-zig/zig build              # 构建 Solana 程序
./solana-zig/zig build test         # 运行测试
./solana-zig/zig build solana       # 构建 Solana 程序

# ❌ 错误 - 禁止使用系统 zig
zig build                           # 会失败！
zig build test                      # 会失败！
```

#### Roc 编译器要求

| 项目 | 要求 |
|------|------|
| **源码位置** | `./roc-source/` |
| **编译工具** | 必须使用 `./solana-zig/zig` 编译 |
| **标准 Roc** | ❌ **禁止使用**（不支持 SBF 目标） |

**为什么 Roc 也需要用 solana-zig 编译？**

Roc 编译器使用 Zig 作为其后端。为了生成 Solana 兼容的代码：
1. Roc 必须使用支持 SBF 目标的 Zig 编译
2. 这确保 Roc 的 LLVM 后端能生成 SBF 兼容的 IR
3. 标准 Roc 无法生成 Solana 程序

**编译 Roc 的正确方式：**

```bash
cd roc-source
../solana-zig/zig build -Drelease

# 验证
./zig-out/bin/roc version
```

#### 工具链检查清单

在开始任何开发工作前，必须验证：

- [ ] `./solana-zig/zig version` 输出 `0.15.2`
- [ ] `./solana-zig/zig targets | grep sbf` 显示 sbf 支持
- [ ] `./solana-zig/zig build test` 测试通过
- [ ] `./solana-zig/zig build` 生成 `zig-out/lib/roc-hello.so`

#### 禁止行为

- ❌ **禁止**: 使用系统 `zig` 命令
- ❌ **禁止**: 使用标准下载的 Roc 编译器
- ❌ **禁止**: 修改 build.zig 使其与系统 zig 兼容
- ❌ **禁止**: 在文档中写 `zig build` 而不是 `./solana-zig/zig build`

#### 错误处理

如果看到以下错误，说明使用了错误的工具链：

| 错误消息 | 原因 | 解决方案 |
|---------|------|---------|
| `enum 'Target.Cpu.Arch' has no member named 'sbf'` | 使用了系统 zig | 改用 `./solana-zig/zig` |
| `no field named 'addSharedLibrary'` | solana-zig API 不同 | 使用 `addLibrary` + `linkage = .dynamic` |
| `Roc: unsupported target` | 使用了标准 Roc | 用 solana-zig 重新编译 Roc |

### Roc 平台架构规范

#### 三层架构要求

**强制要求**: 项目必须遵循三层架构模式：

1. **Roc 平台层** (`platform/`): 纯函数式接口，定义类型和效果
2. **Zig 胶水层** (`src/`): 数据转换和系统调用桥接
3. **Zig SDK 层** (`vendor/solana-program-sdk-zig/`): 底层 Solana 功能

#### 层间通信规范

**数据格式要求**:
- Roc 类型必须与 Zig 类型内存布局兼容
- 使用显式转换函数处理 ABI 边界
- 禁止在层间直接传递复杂结构体

**效果处理要求**:
- Roc 效果必须映射到具体的 Zig SDK 调用
- 每个效果必须有对应的错误处理
- 禁止静默忽略效果失败

### Roc 语言规范

#### 代码风格要求

```elm
-- 强制：使用类型驱动开发
app "contract" {
    -- 明确类型声明
    main : Context -> Result {} [Error Str]
    main = \ctx -> ...

    -- 纯函数优先
    validateAccount : Account -> Result Account [InvalidAccount]
    validateAccount = \account ->
        if account.is_signer then
            Ok account
        else
            Err InvalidAccount
}

-- 强制：管道操作符用于可读性
transferTokens : Account -> Account -> U64 -> Result {} [TransferError]
transferTokens = \from to amount ->
    validateBalance from amount
    |> andThen (\_ -> checkPermissions from)
    |> andThen (\_ -> executeTransfer from to amount)
```

#### 类型定义规范

**强制要求**: 所有 Solana 数据结构必须在 Roc 中精确镜像：

```elm
-- 精确匹配 Solana 数据结构
Pubkey : [ Pubkey (List U8) ] -- 32 字节

Account : {
    key : Pubkey,
    lamports : U64,
    data : List U8,
    owner : Pubkey,
    isSigner : Bool,
    isWritable : Bool,
}

Context : {
    programId : Pubkey,
    accounts : List Account,
    instructionData : List U8,
}
```

### Zig 胶水代码规范

#### 内存管理要求

**强制要求**: 实现 Roc 分配器接口：

```zig
// 必须实现的函数
export fn roc_alloc(size: usize, alignment: u32) ?[*]u8;
export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) ?[*]u8;
export fn roc_dealloc(ptr: [*]u8, alignment: u32) void;

// 使用 Solana 兼容的 Bump 分配器
var heap_pos: usize = 0;
const HEAP_SIZE: usize = 32 * 1024; // Solana 堆限制
```

#### 效果处理器要求

**强制要求**: 为每个 Roc 效果提供处理器：

```zig
// 导出给 Roc 的函数命名约定: roc_fx_[effect_name]
export fn roc_fx_log(msg: RocStr) void {
    const slice = msg.asSlice();
    solana.log(slice);
}

export fn roc_fx_transfer(from: *RocPubkey, to: *RocPubkey, amount: u64) void {
    // 转换类型
    const zig_from = rocPubkeyToZig(from);
    const zig_to = rocPubkeyToZig(to);

    // 调用 SDK
    const instruction = solana.systemProgram.transfer(zig_from, zig_to, amount);
    solana.invokeInstruction(&instruction);
}
```

### 构建和部署规范

#### 编译流程要求

**强制要求**: 构建过程必须按序执行：

1. **Roc 编译**: 生成 LLVM 位码
   ```bash
   roc build --emit-llvm-bc app.roc -o app.bc
   ```

2. **Zig 编译**: 链接胶水代码
   ```zig
   // build.zig - 必须包含 Roc 对象
   const roc_app = b.addObjectFile(.{ .path = "app.bc" });
   lib.addObject(roc_app);
   ```

3. **目标生成**: 产生 BPF 共享库
   ```bash
   zig build -Doptimize=ReleaseSmall  # 最小化大小
   ```

#### 部署验证要求

**强制要求**: 部署前必须验证：

- [ ] BPF 字节码有效
- [ ] 重定位正确
- [ ] 内存使用在 Solana 限制内 (32KB 堆)
- [ ] 计算单元消耗可接受

### 测试规范

#### 测试分层要求

**强制要求**: 实现完整测试覆盖：

```zig
// 1. Zig 胶水层测试
test "allocator works" {
    const ptr = roc_alloc(100, 8);
    try std.testing.expect(ptr != null);
}

// 2. Roc 平台测试
test "validate account logic" {
    const account = Account{...};
    const result = validateAccount(account);
    try std.testing.expect(result == Ok(account));
}

// 3. 集成测试
test "full contract execution" {
    const mock_context = createMockContext();
    const result = roc_mainForHost(mock_context);
    try std.testing.expect(result.is_ok);
}
```

#### 性能测试要求

**强制要求**: 测量和验证性能：

- [ ] 计算单元使用量
- [ ] 堆内存使用量
- [ ] 栈深度限制 (4KB Solana 限制)
- [ ] 对比等效 Rust/Anchor 实现

### 文档规范

#### 中文文档要求

**强制要求**: 所有文档使用中文编写：

- [ ] README.md - 完整中文用户指南
- [ ] docs/architecture.md - 架构详细说明
- [ ] docs/build-integration.md - 构建过程文档
- [ ] docs/challenges-solutions.md - 挑战和解决方案
- [ ] 所有代码注释和文档字符串

#### Story 文件要求

**强制要求**: 使用中文编写 Story 文件：

```markdown
# Story: v0.1.0 核心平台实现

> 实现 Roc on Solana 的基本平台架构

## 目标

- [ ] 实现 Roc 分配器接口
- [ ] 定义基础 Solana 类型 (Pubkey, Account, Context)
- [ ] 创建基本的日志效果
- [ ] 通过简单示例验证架构

## 验收标准

### platform/main.roc
- [ ] 定义 Context 和 Account 类型
- [ ] 实现 log 效果声明

### src/allocator.zig
- [ ] 实现 roc_alloc/dealloc 函数
- [ ] 正确处理 Solana 堆限制

### 测试
- [ ] 所有单元测试通过
- [ ] 集成测试通过

## 完成状态

- 开始日期: YYYY-MM-DD
- 完成日期: YYYY-MM-DD
- 状态: ⏳ 进行中
```

### 安全规范

#### 智能合约安全要求

**强制要求**: 实施安全最佳实践：

- [ ] 所有输入验证
- [ ] 边界检查防止溢出
- [ ] 权限检查防止未授权访问
- [ ] 状态一致性保证

#### 内存安全要求

**强制要求**: 防止常见漏洞：

- [ ] 无缓冲区溢出
- [ ] 无悬空指针
- [ ] 无内存泄漏
- [ ] 无段错误

### 兼容性规范

#### 版本兼容性要求

**强制要求**: 维护版本兼容性：

- [ ] 指定最小 Roc 版本要求
- [ ] 指定 Zig SDK 版本范围
- [ ] 定期测试新版本兼容性
- [ ] 提供升级指南

#### 平台兼容性要求

**强制要求**: 确保跨平台兼容：

- [ ] Linux 和 macOS 开发环境
- [ ] Solana devnet/testnet/mainnet
- [ ] 不同 Solana CLI 版本

### 性能优化规范

#### 计算单元优化

**强制要求**: 最小化链上计算成本：

- [ ] 使用 Roc 的 Perceus 算法优势
- [ ] 避免不必要的分配
- [ ] 优化热路径
- [ ] 批量操作减少调用次数

#### 内存优化

**强制要求**: 控制内存使用：

- [ ] 保持在 Solana 32KB 堆限制内
- [ ] 使用栈分配优先
- [ ] 最小化数据复制
- [ ] 及时释放临时资源

### 提交前检查清单（Roc on Solana 扩展）

#### Roc 特定检查
- [ ] 所有 Roc 代码通过类型检查
- [ ] 使用管道操作符提高可读性
- [ ] 纯函数优先，避免副作用
- [ ] 类型定义与 Zig 布局兼容

#### 平台集成检查
- [ ] ABI 边界正确处理
- [ ] 效果处理器完整实现
- [ ] 内存管理无泄漏
- [ ] 错误传播正确

#### Solana 兼容性检查
- [ ] BPF 字节码生成正确
- [ ] 堆使用在 32KB 限制内
- [ ] 计算单元消耗合理
- [ ] 部署到 devnet 成功

---

## 相关文档

- `ROADMAP.md` - 项目路线图（Source of Truth）
- `README.md` - 用户入口文档（必须保持最新）
- `stories/` - 工作单元（Stories）
- `docs/` - 详细设计文档
- `CHANGELOG.md` - 变更日志
