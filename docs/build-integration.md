# 构建集成：Roc + Zig 用于 Solana

本文档解释了 Roc-Solana 平台如何将 Roc 编译与 Zig 的构建系统集成，以生成 Solana 兼容的 SBF 程序。

## 概述

### 新架构（基于 solana-zig-bootstrap）

构建 Roc 合约使用统一工具链方法：

1. **工具链准备**：使用 solana-zig-bootstrap（支持 SBF 目标的 Zig 0.15.2）
2. **Roc 编译器编译**：使用 solana-zig 编译 Roc 编译器
3. **Roc 应用编译**：编译 Roc 应用为 LLVM 位码
4. **Zig Host 编译 + 链接**：编译并链接为 Solana eBPF 程序

### 旧架构（已弃用）

~~构建 Roc 合约涉及三个主要步骤：~~
~~1. Roc 编译：将 Roc 源码编译为 LLVM 位码~~
~~2. Zig 编译：使用 SDK 集成编译 Zig 宿主代码~~
~~3. 链接：使用 sbpf-linker 将 Roc 和 Zig 组合成 BPF 共享库~~

## 先决条件

### 新方案先决条件

- **solana-zig-bootstrap**: 支持 SBF 目标的修改版 Zig
  - 来源：https://github.com/joncinque/solana-zig-bootstrap
  - 版本：Zig 0.15.2（已验证支持 `sbf-freestanding` 目标）
  - 位置：`./solana-zig/zig`

- **Roc 编译器源码**：需要使用 solana-zig 重新编译
  - 来源：https://github.com/roc-lang/roc
  - 位置：`./roc-source/`

- **solana-program-sdk-zig**：Solana SDK
  - 来源：https://github.com/joncinque/solana-program-sdk-zig
  - 位置：`./vendor/solana-program-sdk-zig/`

### 旧方案先决条件（已弃用）

~~- Roc 编译器，具有 LLVM 后端支持~~
~~- Zig 0.15+，具有 BPF 目标支持~~
~~- LLVM 工具链用于位码操作~~
~~- sbpf-linker~~

## 新构建流程

### 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                solana-zig-bootstrap (./solana-zig/zig)          │
│                  Zig 0.15.2 + SBF 目标支持                       │
└─────────────────────────────────────────────────────────────────┘
                               │
             ┌─────────────────┴─────────────────┐
             ↓                                   ↓
┌───────────────────────┐         ┌───────────────────────────────┐
│     Roc 编译器         │         │   solana-program-sdk-zig      │
│  (用 solana-zig 编译)  │         │   (原生 SBF 支持的 SDK)        │
│                       │         │                                │
│ 位置: ./roc-source/   │         │ 位置: ./vendor/                │
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
│                    Zig Host (./src/host.zig)                    │
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
│  目标: sbf-freestanding (原生 SBF 目标)                          │
│  无需 sbpf-linker，直接由 solana-zig 链接                        │
└─────────────────────────────────────────────────────────────────┘
```

### 详细构建步骤

#### 阶段 1: 准备工具链

```bash
# 1. 验证 solana-zig 存在且可用
./solana-zig/zig version
# 输出: 0.15.2

# 2. 验证 SBF 目标支持
./solana-zig/zig targets | grep sbf
# 输出应包含 "sbf"

# 3. 测试 SBF 编译
echo 'export fn _start() void {}' > /tmp/test.zig
./solana-zig/zig build-obj -target sbf-freestanding /tmp/test.zig
# 应成功生成 test.o
```

#### 阶段 2: 编译 Roc 编译器（首次设置）

```bash
# 使用 solana-zig 编译 Roc 编译器
cd roc-source

# 设置环境变量指向 solana-zig
export ZIG_PATH=$(pwd)/../solana-zig/zig

# 编译 Roc（需要较长时间）
$ZIG_PATH build -Drelease

# 验证编译成功
./zig-out/bin/roc version
```

#### 阶段 3: 编译 Roc 应用

```bash
# 使用重新编译的 Roc 编译应用
./roc-source/zig-out/bin/roc build \
    --lib \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc
```

#### 阶段 4: 编译并链接 Solana 程序

```bash
# 使用 solana-zig 编译 host.zig 并链接 Roc 输出
./solana-zig/zig build-lib \
    -target sbf-freestanding \
    -O ReleaseSmall \
    src/host.zig \
    --dep solana_sdk \
    -Msolana_sdk=vendor/solana-program-sdk-zig/src/root.zig

# 链接 Roc 位码
./solana-zig/zig build-exe \
    -target sbf-freestanding \
    zig-out/lib/host.o \
    zig-out/lib/app.bc \
    -o zig-out/lib/roc-hello.so
```

### build.zig 配置

新的 `build.zig` 使用 solana-zig 而非系统 zig：

```zig
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseSmall;
    
    // SBF 目标 (使用 solana-zig 原生支持)
    const sbf_target = b.resolveTargetQuery(.{
        .cpu_arch = .sbf,
        .os_tag = .freestanding,
    });

    // Solana SDK 依赖
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = sbf_target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    // 编译 Host 为 SBF 目标
    const host_lib = b.addStaticLibrary(.{
        .name = "roc-host",
        .root_source_file = b.path("src/host.zig"),
        .target = sbf_target,
        .optimize = optimize,
    });
    host_lib.root_module.addImport("solana_sdk", solana_mod);

    // 添加 Roc 生成的对象文件
    // host_lib.addObjectFile(b.path("zig-out/lib/app.o"));

    // 安装步骤
    b.installArtifact(host_lib);

    // 测试（在主机上运行，非 SBF）
    const host_mod = b.addModule("roc_solana_host", .{
        .root_source_file = b.path("src/host.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    
    const host_dep_for_test = b.dependency("solana_program_sdk", .{
        .target = b.graph.host,
        .optimize = optimize,
    });
    host_mod.addImport("solana_sdk", host_dep_for_test.module("solana_program_sdk"));

    const host_tests = b.addTest(.{
        .root_module = host_mod,
    });
    const run_host_tests = b.addRunArtifact(host_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_host_tests.step);
}
```

### 与旧方案对比

| 方面 | 旧方案 | 新方案 |
|------|--------|--------|
| 目标架构 | `bpfel-freestanding` | `sbf-freestanding` |
| Zig 编译器 | 系统 zig | `./solana-zig/zig` |
| 链接器 | 需要 `sbpf-linker` | 原生 Zig 链接器 |
| LLVM 版本 | 可能不匹配 | 统一版本 |
| 编译步骤 | 多步骤（IR → BC → OBJ → SO） | 一步到位 |
| 维护复杂度 | 高（多个外部工具） | 低（统一工具链） |
| Roc 编译器 | 标准版本 | 需要用 solana-zig 重新编译 |

## 内存布局考虑

**关键**：确保 Roc 和 Zig 对数据布局意见一致。

- **列表**：Roc 的 `List U8` = `{ ptr: *u8, len: usize, cap: usize }`
- **结构体**：内存布局必须在 Roc 和 Zig 之间匹配
- **字符串**：Roc 字符串是 UTF-8，确保正确处理

### RocStr ABI

```zig
// Roc 字符串 ABI (16 字节)
pub const RocStr = extern struct {
    ptr: [*]u8,      // 8 字节
    len: u32,        // 4 字节
    cap: u32,        // 4 字节
    
    pub fn asSlice(self: RocStr) []const u8 {
        return self.ptr[0..self.len];
    }
};
```

## 入口点集成

Zig 宿主提供 Solana 入口点：

```zig
// src/host.zig
const sdk = @import("solana_sdk");

// 从 Roc 导入的函数
extern fn roc__mainForHost_1_exposed_generic(*RocStr) void;

export fn entrypoint(input: [*]u8) u64 {
    // 调用 Roc 主函数
    var result: RocStr = undefined;
    roc__mainForHost_1_exposed_generic(&result);

    // 输出结果到 Solana 日志
    sdk.log.log(result.asSlice());

    return 0; // 成功
}
```

## 效果处理

Roc 效果作为导出的 Zig 函数实现：

```zig
// src/effects.zig
const sdk = @import("solana_sdk");

export fn roc_fx_log(msg: RocStr) void {
    sdk.log.log(msg.asSlice());
}

export fn roc_fx_transfer(from: *RocPubkey, to: *RocPubkey, amount: u64) void {
    // 将 Roc 类型转换为 SDK 类型
    const zig_from = rocPubkeyToSdk(from);
    const zig_to = rocPubkeyToSdk(to);

    // 使用 SDK 构建指令
    const instruction = sdk.system_program.transfer(zig_from, zig_to, amount);
    sdk.invoke(&instruction);
}
```

## 构建命令

### 开发构建

```bash
# 使用 solana-zig 构建
./solana-zig/zig build

# 仅编译，不链接
./solana-zig/zig build -Dstep=compile

# 带调试信息
./solana-zig/zig build -Doptimize=Debug
```

### 生产构建

```bash
# 优化发布构建
./solana-zig/zig build -Doptimize=ReleaseFast

# 部署最小尺寸
./solana-zig/zig build -Doptimize=ReleaseSmall
```

### 测试构建

```bash
# 运行单元测试（在主机上运行）
./solana-zig/zig build test

# 运行集成测试（需要 Solana）
./solana-zig/zig build test-integration
```

## 故障排除

### 常见问题

**"未定义符号: roc_mainForHost"**
- 确保 Roc 编译生成了正确的符号名称
- 检查 Roc 平台声明是否与 Zig extern 声明匹配

**"内存布局不匹配"**
- 验证 Roc 和 Zig 之间结构体字段顺序匹配
- 对 C ABI 兼容性使用 `extern struct`

**"LLVM 版本不匹配"**
- 使用 solana-zig-bootstrap 统一工具链
- 确保 Roc 使用相同的 solana-zig 编译

**"BPF 重定位错误"**
- 使用 `sbf-freestanding` 目标而非 `bpfel-freestanding`
- 避免跨编译单元的复杂指针算术

**"找不到 sbf 目标"**
- 确保使用 `./solana-zig/zig` 而非系统 zig
- 验证：`./solana-zig/zig targets | grep sbf`

### 调试提示

```bash
# 转储 LLVM IR 以进行检查
./solana-zig/zig build-obj -femit-llvm-ir src/host.zig

# 检查符号表
llvm-nm zig-out/lib/host.o

# 验证 SBF 字节码
llvm-objdump -d zig-out/lib/host.o
```

## 性能优化

- 对最小二进制大小使用 `ReleaseSmall`（Solana 52KB 限制很重要）
- 在 build.zig 中启用 LTO（链接时优化）
- 分析与 Solana 的计算单元计量

## 部署

```bash
# 启动本地验证器
solana-test-validator

# 配置 CLI
solana config set --url localhost

# 获取 SOL
solana airdrop 2

# 部署程序
solana program deploy zig-out/lib/roc-hello.so

# 调用程序
./scripts/invoke.sh <PROGRAM_ID>
```

## 未来改进

- Roc 编译器中的原生 SBF 目标支持
- 从 Roc 类型自动生成 ABI
- 集成测试框架
- 更广泛兼容性的 WASM/WebAssembly 目标
