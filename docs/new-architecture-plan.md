# Roc on Solana 新架构方案

> 基于 solana-zig-bootstrap 的统一编译方案

## 背景

当前项目面临的主要挑战是：
1. Roc 编译器不原生支持 Solana 的 SBF (Solana BPF) 目标
2. 当前使用的 `bpfel-freestanding` 目标 + `sbpf-linker` 方案存在链接问题
3. 需要手动处理 LLVM IR 转换，过程繁琐且容易出错

## 新方案概述

使用 `solana-zig-bootstrap` 作为核心编译工具链：

```
┌─────────────────────────────────────────────────────────────────┐
│              solana-zig-bootstrap (修改版 Zig)                   │
│          (原生支持 SBF 目标的 Zig 编译器)                         │
│                                                                   │
│  来源: https://github.com/joncinque/solana-zig-bootstrap         │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ↓                                   ↓
┌───────────────────────┐         ┌───────────────────────────────┐
│     Roc 编译器         │         │   solana-program-sdk-zig      │
│  (用修改版 Zig 编译)   │         │  (原生 SBF 支持的 SDK)         │
│                       │         │                                │
│ 来源: roc-lang/roc    │         │ 来源: joncinque/               │
└───────────────────────┘         │       solana-program-sdk-zig   │
            │                     └───────────────────────────────┘
            ↓                                   │
┌───────────────────────┐                       │
│   Roc 应用 (app.roc)   │                       │
│ + 平台 (main.roc)     │                       │
└───────────────────────┘                       │
            │                                   │
            ↓                                   ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Zig Host (host.zig)                          │
│              使用 solana-program-sdk-zig                         │
│                                                                   │
│  - Roc 运行时接口 (roc_alloc, roc_panic, etc.)                   │
│  - 调用 Roc 的 main_for_host 函数                                 │
│  - 使用 SDK 的 allocator 和 log 模块                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Solana eBPF 程序 (.so)                         │
│                                                                   │
│  目标: sbf-solana-solana (原生 SBF 目标)                         │
└─────────────────────────────────────────────────────────────────┘
```

## 关键依赖

### 1. solana-zig-bootstrap

**仓库**: https://github.com/joncinque/solana-zig-bootstrap

**作用**: 提供修改版的 Zig 编译器，添加了 Solana SBF 目标支持

**特性**:
- 原生 `sbf-solana-solana` 目标
- 集成了 Solana BPF 特定的 LLVM 后端修改
- 不需要额外的 sbpf-linker（直接链接）

### 2. solana-program-sdk-zig

**仓库**: https://github.com/joncinque/solana-program-sdk-zig

**作用**: Solana 程序开发 SDK

**依赖**: 需要使用 solana-zig-bootstrap 编译

**提供**:
- 系统调用封装 (sol_log, sol_invoke, etc.)
- 内存分配器 (32KB 堆限制的 bump allocator)
- 类型定义 (Pubkey, Account, Instruction, etc.)

### 3. Roc 编译器

**仓库**: https://github.com/roc-lang/roc

**修改**: 需要使用 solana-zig-bootstrap 重新编译

**原因**: Roc 使用 Zig 作为其编译工具链的一部分，需要让 Roc 的 LLVM 后端能够生成 SBF 目标代码

## 项目目录结构

```
roc-on-solana/
├── solana-zig/                    # solana-zig-bootstrap 发行版
│   ├── zig                        # 修改版 Zig 可执行文件
│   └── lib/                       # Zig 标准库
│
├── roc-source/                    # Roc 编译器源码
│   ├── build.zig                  # 需要使用 solana-zig 编译
│   └── ...
│
├── vendor/
│   └── solana-program-sdk-zig/    # Solana SDK
│       ├── src/
│       └── build.zig
│
├── src/
│   └── host.zig                   # Zig 宿主实现
│
├── platform/
│   └── main.roc                   # Roc 平台定义
│
├── examples/
│   └── hello-world/
│       └── app.roc                # Roc 应用示例
│
├── build.zig                      # 项目构建配置
└── build.zig.zon                  # 依赖配置
```

## 编译流程

### 阶段 1: 准备工具链

```bash
# 1. 获取 solana-zig-bootstrap
# 下载预编译版本或从源码编译
wget https://github.com/joncinque/solana-zig-bootstrap/releases/download/v0.15.X/zig-linux-x86_64.tar.xz
tar -xf zig-linux-x86_64.tar.xz -C solana-zig/

# 2. 验证 SBF 目标支持
./solana-zig/zig targets | grep sbf
```

### 阶段 2: 编译 Roc 编译器

```bash
# 使用 solana-zig 编译 Roc
cd roc-source
../solana-zig/zig build
```

### 阶段 3: 编译 Roc 应用

```bash
# 使用重新编译的 Roc 编译 app.roc
./roc-source/zig-out/bin/roc build --emit-llvm-bc examples/hello-world/app.roc
```

### 阶段 4: 编译并链接 Solana 程序

```bash
# 使用 solana-zig 编译 host.zig 并链接 Roc 输出
./solana-zig/zig build -Dtarget=sbf-solana-solana
```

## 与旧方案对比

| 方面 | 旧方案 | 新方案 |
|------|--------|--------|
| 目标架构 | `bpfel-freestanding` | `sbf-solana-solana` |
| 链接器 | 需要 `sbpf-linker` | 原生 Zig 链接器 |
| LLVM 版本 | 可能不匹配 | 统一版本 |
| 编译步骤 | 多步骤（IR → BC → OBJ → SO） | 一步到位 |
| 维护复杂度 | 高（多个外部工具） | 低（统一工具链） |
| Roc 编译器 | 标准版本 | 需要重新编译 |

## 实施步骤

### 第一阶段: 验证工具链

- [ ] 下载/编译 solana-zig-bootstrap
- [ ] 验证 SBF 目标可用
- [ ] 测试使用 solana-program-sdk-zig 编译简单程序

### 第二阶段: 编译 Roc

- [ ] 配置 Roc 使用 solana-zig
- [ ] 解决可能的编译问题
- [ ] 验证 Roc 编译器可用

### 第三阶段: 集成测试

- [ ] 编译 Roc 平台和示例应用
- [ ] 链接生成 .so 文件
- [ ] 部署到 Solana devnet 测试

### 第四阶段: 文档和优化

- [ ] 更新所有文档
- [ ] 优化构建流程
- [ ] 创建一键部署脚本

## 风险和挑战

### 1. Roc 编译器修改

- Roc 使用 Zig 作为其工具链的一部分
- 可能需要修改 Roc 的 build.zig 以适配 solana-zig-bootstrap
- 需要确保 LLVM 版本兼容

### 2. ABI 兼容性

- Roc 和 Zig 之间的数据结构布局必须匹配
- RocStr、RocList 等类型的内存布局需要验证

### 3. 工具链版本管理

- solana-zig-bootstrap 可能落后于最新 Zig 版本
- 需要跟踪上游更新

## 参考资源

- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)
- [solana-program-sdk-zig](https://github.com/joncinque/solana-program-sdk-zig)
- [Roc 语言](https://github.com/roc-lang/roc)
- [Solana 程序开发文档](https://docs.solana.com/programs)

## 版本信息

- 创建日期: 2026-01-04
- 状态: 规划中
- 作者: Sisyphus AI
