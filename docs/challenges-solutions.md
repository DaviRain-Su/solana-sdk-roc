# 挑战与解决方案：Roc on Solana 平台

本文档识别 Roc on Solana 平台的实施技术挑战，并提供实用解决方案。

## 新方案：solana-zig-bootstrap 统一工具链

### 核心思路

使用 `solana-zig-bootstrap` 作为统一的编译工具链，解决了旧方案中的大多数技术难题：

```
┌─────────────────────────────────────────────────────────────────┐
│              solana-zig-bootstrap (./solana-zig/zig)            │
│                  Zig 0.15.2 + 原生 SBF 目标                      │
│                                                                   │
│  - 原生支持 sbf-freestanding 目标                                │
│  - 不需要外部 sbpf-linker                                        │
│  - 统一的 LLVM 版本                                              │
│                                                                   │
│  来源: https://github.com/joncinque/solana-zig-bootstrap         │
└─────────────────────────────────────────────────────────────────┘
```

### 新方案如何解决旧挑战

| 旧挑战 | 旧方案痛点 | 新方案解决 |
|--------|-----------|-----------|
| LLVM 版本不匹配 | Zig/Roc/sbpf-linker LLVM 版本不一致 | 统一使用 solana-zig 的 LLVM |
| sbpf-linker 链接错误 | 多文件链接失败，重定位问题 | 原生 Zig 链接器，无需 sbpf-linker |
| 目标架构不匹配 | `bpfel-freestanding` 需要额外转换 | 原生 `sbf-freestanding` 目标 |
| 构建步骤复杂 | IR → BC → OBJ → SO 多步骤 | 一步编译链接 |
| 工具链维护 | 多个工具版本需要协调 | 单一工具链 |

---

## 1. ABI 边界问题

### 挑战：数据布局不匹配
Roc 和 Zig 可能对相同逻辑数据结构有不同的内存布局，导致崩溃或不正确行为。

**症状：**
- 随机崩溃
- 数据访问时不正确值
- 内存损坏

### 解决方案：显式布局规范

**1. 使用固定布局定义通用类型：**

```zig
// src/types.zig - Zig 端
pub const RocPubkey = extern struct {
    bytes: [32]u8,
};

pub const RocAccount = extern struct {
    key: RocPubkey,
    lamports: u64,
    data_len: usize,
    data_ptr: [*]u8,
    owner: RocPubkey,
    is_signer: bool,
    is_writable: bool,
    // 填充以匹配 Roc 的结构体布局
    _padding: [3]u8,
};
```

```elm
-- platform/types.roc - Roc 端
Pubkey : [ Pubkey (List U8) ]

Account : {
    key : Pubkey,
    lamports : U64,
    data : List U8,
    owner : Pubkey,
    isSigner : Bool,
    isWritable : Bool,
}
```

**2. 使用转换函数：**

```zig
// src/conversions.zig
pub fn zigAccountToRoc(zig_acc: *AccountInfo) RocAccount {
    return RocAccount{
        .key = RocPubkey{ .bytes = zig_acc.key.* },
        .lamports = zig_acc.lamports.*,
        .data_len = zig_acc.data.len,
        .data_ptr = zig_acc.data.ptr,
        .owner = RocPubkey{ .bytes = zig_acc.owner.* },
        .is_signer = zig_acc.is_signer,
        .is_writable = zig_acc.is_writable,
        ._padding = [_]u8{0} ** 3,
    };
}
```

## 2. 内存管理复杂性

### 挑战：Roc 的引用计数 vs Solana 的 Bump 分配器
Roc 期望引用计数用于内存管理，但 Solana 使用简单的 bump 分配器，没有释放。

**症状：**
- 内存泄漏
- 堆耗尽
- 性能下降

### 解决方案：自定义 Roc 分配器

**1. 实现 Roc 分配器接口：**

```zig
// src/allocator.zig
const sdk = @import("solana_sdk");

// 使用 SDK 的 bump allocator
const heap = sdk.allocator.heap;

export fn roc_alloc(size: usize, alignment: u32) ?[*]u8 {
    const aligned_size = std.mem.alignForward(usize, size, alignment);
    const result = heap.alloc(u8, aligned_size) catch return null;
    return result.ptr;
}

export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) ?[*]u8 {
    // Solana 上：分配新的并复制（无就地重新分配）
    const new_ptr = roc_alloc(new_size, alignment) orelse return null;
    const copy_size = @min(old_size, new_size);
    @memcpy(new_ptr[0..copy_size], ptr[0..copy_size]);
    return new_ptr;
}

export fn roc_dealloc(ptr: [*]u8, alignment: u32) void {
    // 无操作：Solana 堆是 bump allocator，程序结束后销毁
    _ = ptr;
    _ = alignment;
}
```

**2. 设计合约以最小化分配：**
- 尽可能使用栈分配缓冲区
- 预分配固定大小结构
- 在热路径中避免动态数据结构

## 3. 效果系统实现

### 挑战：将 Roc 效果映射到命令式操作
Roc 的纯函数式效果需要转换为 Solana 的命令式系统调用。

**症状：**
- 效果未执行
- 效果顺序不正确
- 性能开销

### 解决方案：直接效果绑定

**1. 在 Roc 中定义效果：**

```elm
-- platform/effects.roc
log : Str -> Task {} []
log = \msg -> Effect.map (Effect.always (Log msg))

transfer : Pubkey -> Pubkey -> U64 -> Task {} []
transfer = \from to amount ->
    Effect.map (Effect.always (Transfer from to amount))
```

**2. 在 Zig 中实现处理器：**

```zig
// src/effects.zig
const sdk = @import("solana_sdk");

pub const EffectTag = enum(u8) {
    Log,
    Transfer,
    // ...
};

pub const EffectData = union(EffectTag) {
    Log: RocStr,
    Transfer: struct {
        from: RocPubkey,
        to: RocPubkey,
        amount: u64,
    },
};

export fn roc_fx_handle(effect: EffectData) void {
    switch (effect) {
        .Log => |msg| sdk.log.log(msg.asSlice()),
        .Transfer => |data| {
            const instruction = sdk.system_program.transfer(
                &data.from.bytes,
                &data.to.bytes,
                data.amount
            );
            sdk.invoke(&instruction);
        },
    }
}
```

## 4. LLVM 目标兼容性 [核心阻塞问题]

### 挑战：Roc 的 LLVM 不支持 SBF 目标

**发现时间**: 2026-01-04

即使使用 solana-zig 编译 Roc 编译器，Roc 内部的 LLVM 代码生成仍然不支持 SBF 目标。

**症状：**
```
LLVM error: No available targets are compatible with triple "sbf-solana-solana"
warning: LLVM compilation not ready, falling back to clang
```

**根本原因：**
1. Roc 使用 Zig 的标准 LLVM 绑定进行代码生成
2. 虽然 solana-zig 的 Zig 编译器支持 SBF，但 Roc 内部的 LLVM 调用使用的是标准 LLVM 配置
3. 标准 LLVM 没有 SBF 目标后端

### 已完成的工作

1. ✅ 使用 solana-zig 编译 Roc 编译器
2. ✅ 修改 Roc 源码 `src/target/mod.zig` 添加 `sbfsolana` 目标
3. ✅ 编译 SBF 宿主库 `platform/targets/sbfsolana/libhost.a`
4. ✅ 更新 `platform/main.roc` 支持 sbfsolana 目标
5. ✅ Roc 代码检查通过 (`roc check app.roc`)

### 阻塞点

Roc 的 LLVM 后端不支持 SBF 目标三元组 "sbf-solana-solana"。

### 潜在解决方案

**方案 A: 修改 Roc 的 LLVM 后端配置**
- 难度：高
- 需要深入理解 Roc 的 LLVM 集成
- 可能需要修改 `src/llvm_compile/` 和 `src/backend/llvm/`

**方案 B: 使用 Roc 解释器模式**
- 难度：中
- Roc 有解释器可以评估代码
- 可能用于开发/测试，但不适合部署

**方案 C: 编译为 WASM 然后转换**
- 难度：中
- Roc 支持 wasm32 目标
- 可能需要 WASM 到 SBF 的转换器

**方案 D: 使用旧版 Rust Roc 编译器**
- 难度：中
- 旧版有 `--emit-llvm-bc` 选项
- 需要配合 solana-zig 的 LLVM 工具

**方案 E: 贡献 SBF 支持到 Roc 上游**
- 难度：高
- 长期最佳方案
- 需要与 Roc 社区合作

### 当前状态

v0.2.0 在此阻塞。需要选择一个方案并实施。

**推荐下一步**: 探索方案 D（旧版 Roc 编译器），因为它有 LLVM 输出选项。

## 5. sbpf-linker 链接问题 [已通过新方案解决]

### 旧挑战：多文件链接失败
sbpf-linker 在链接多个对象文件时报错。

**旧方案症状：**
- "Relocations found but no .rodata section"
- 链接失败

### 新方案解决

```bash
# 旧方案：使用 sbpf-linker（问题多多）
sbpf-linker host.bc roc.o -o program.so

# 新方案：使用 solana-zig 原生链接
./solana-zig/zig build-exe \
    -target sbf-freestanding \
    host.o roc.o \
    -o program.so
```

**关键点：**
- solana-zig 的链接器原生支持 SBF
- 不需要外部工具
- 重定位问题由工具链正确处理

## 6. 测试和调试

### 挑战：Solana 环境中有限的可调试性
智能合约很难调试，混合语言增加了复杂性。

**症状：**
- 静默失败
- 错误归因困难
- 性能问题

### 解决方案：全面测试策略

**1. 测试每一层：**

```zig
// tests/effects_test.zig
test "log effect" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    // 模拟 solana.log 以捕获输出
    roc_fx_log("test message");
    try std.testing.expectEqualStrings("test message", fbs.getWritten());
}
```

**2. 集成测试：**

```zig
// tests/integration_test.zig
test "full contract execution" {
    // 模拟 Solana 运行时
    const input = createMockInput();
    const result = entrypoint(input.ptr);
    try std.testing.expectEqual(result, 0);
}
```

**3. 日志策略：**

```zig
// 开发时广泛日志记录
export fn roc_fx_log(msg: RocStr) void {
    // 开发中：记录一切
    sdk.log.log(msg.asSlice());

    // 生产中：条件日志记录
    if (is_development) {
        sdk.log.log(msg.asSlice());
    }
}
```

## 7. 性能优化

### 挑战：资源受限平台上的函数式开销
Roc 的函数式风格可能比命令式 Zig/Rust 引入性能开销。

**症状：**
- 更高的计算单元使用
- 较慢执行
- 内存膨胀

### 解决方案：编译器优化和剖析

**1. 启用优化：**

```zig
// build.zig - 积极优化
const lib = b.addSharedLibrary(.{
    .optimize = .ReleaseSmall, // 最小化尺寸
    // 启用 LTO
    .link_time_optimization = .full,
});
```

**2. 剖析和优化：**

- 使用 Solana 的计算单元计量
- 识别 Roc 代码中的热路径
- 考虑性能关键部分的命令式实现

**3. 内存布局优化：**

```zig
// 使用打包结构体最小化内存使用
pub const PackedAccount = packed struct {
    key: [32]u8,
    lamports: u64,
    data_len: u32,
    data_ptr: u32, // BPF 上使用 32 位指针
};
```

## 8. 工具链版本管理 [已通过新方案简化]

### 旧挑战：多个工具版本协调
需要协调 Zig、Roc、LLVM、sbpf-linker 等多个工具的版本。

### 新方案解决

使用 solana-zig-bootstrap 作为单一工具链：

```
solana-zig-bootstrap (Zig 0.15.2)
    └── 内置 LLVM 版本
    └── 内置 SBF 目标支持
    └── 内置链接器
        
用于编译：
    └── Roc 编译器
    └── 宿主代码
    └── 最终程序
```

**版本固定策略：**

```bash
# 项目中固定 solana-zig 版本
# 在 build.zig.zon 中指定
.dependencies = .{
    .solana_zig = .{
        .url = "https://github.com/joncinque/solana-zig-bootstrap/releases/download/v0.15.2/...",
        .hash = "...",
    },
},
```

## 9. 未来兼容性

### 挑战：Roc 和 Solana 演进
Roc 和 Solana 都在积极开发，可能破坏兼容性。

### 解决方案：版本固定和兼容层

- 固定特定 Roc、Zig 和 solana-zig-bootstrap 版本
- 为 API 变更维护兼容层
- 定期测试新版本
- 社区监控上游变更

### 升级检查清单

- [ ] 验证 solana-zig-bootstrap 新版本兼容性
- [ ] 重新编译 Roc 编译器
- [ ] 运行完整测试套件
- [ ] 更新文档

## 总结

### 当前进展 (2026-01-04)

| 阶段 | 状态 | 说明 |
|------|------|------|
| solana-zig 获取 | ✅ 完成 | Zig 0.15.2 + SBF 支持 |
| 纯 Zig 程序构建 | ✅ 完成 | v0.1.0, 可部署到 Solana |
| Roc 编译器编译 | ✅ 完成 | 使用 solana-zig 编译成功 |
| Roc SBF 目标修改 | ✅ 完成 | 添加 sbfsolana 到 target/mod.zig |
| SBF 宿主库 | ✅ 完成 | libhost.a 已生成 |
| Roc 平台配置 | ✅ 完成 | main.roc 添加 sbfsolana 目标 |
| **Roc LLVM SBF 支持** | ❌ **阻塞** | LLVM 不识别 sbf 目标 |

### 核心阻塞问题

**Roc 内部的 LLVM 不支持 SBF 目标**

即使 Roc 的目标系统添加了 sbfsolana，Roc 的 LLVM 代码生成器不识别 "sbf-solana-solana" 三元组。

### 解决方案评估

| 方案 | 可行性 | 工作量 | 推荐度 |
|------|--------|--------|--------|
| A: 修改 Roc LLVM 后端 | 中 | 高 | ⭐⭐ |
| B: Roc 解释器 | 低 | 低 | ⭐ |
| C: WASM 转 SBF | 中 | 中 | ⭐⭐ |
| D: 旧版 Rust Roc | 中 | 中 | ⭐⭐⭐ |
| E: 上游贡献 | 高 | 高 | ⭐⭐⭐⭐ (长期) |

### 下一步建议

1. **短期**: 探索旧版 Rust Roc 编译器的 `--emit-llvm-bc` 选项
2. **中期**: 研究 WASM 到 SBF 的转换可行性
3. **长期**: 与 Roc 社区合作贡献 SBF 目标支持

### 新方案优势（对于纯 Zig 部分）

1. **统一工具链**：solana-zig-bootstrap 解决了 Zig 编译 Solana 程序的所有问题
2. **原生 SBF 支持**：Zig 代码可以直接编译为 SBF
3. **简化构建**：一步编译链接
4. **v0.1.0 完整可用**：纯 Zig 的 Solana 程序已可部署

### 仍需解决的问题

1. **Roc LLVM SBF 支持**：核心阻塞问题
2. **ABI 边界**：Roc 和 Zig 之间的数据布局
3. **内存管理**：Solana 的 32KB 堆限制
4. **效果映射**：Roc 效果到 Solana syscall

### 实施进度

1. ✅ 获取并验证 solana-zig-bootstrap
2. ✅ 使用 solana-zig 重新编译 Roc 编译器
3. ✅ 修改 Roc 源码添加 SBF 目标
4. ✅ 更新 build.zig 使用新工具链
5. ✅ 编译 SBF 宿主库
6. ❌ **阻塞**: Roc LLVM 不支持 SBF 代码生成
7. ⏳ 需要选择替代方案
