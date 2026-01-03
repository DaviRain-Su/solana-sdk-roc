# Roc on Solana 平台架构

本文档概述了 Roc-Solana 平台的三层架构。

## 概述

Roc-Solana 平台使用三明治架构，利用现有的 Zig SDK 基础设施为 Roc 提供函数式编程接口。

```
┌─────────────────────────────────────┐
│         Roc 平台层                   │
│   （函数式接口 - app.roc）            │
├─────────────────────────────────────┤
│        宿主胶水层                    │
│   （Zig host.zig - 数据转换）         │
├─────────────────────────────────────┤
│       Zig SDK 层                     │
│  （solana-program-sdk-zig - 核心）    │
└─────────────────────────────────────┘
```

## 第一层：Zig SDK 层（基础）

**来源**：[solana-program-sdk-zig](https://github.com/DaviRain-Su/solana-program-sdk-zig)

该层提供低级 Solana 功能：
- 系统调用（sol_log、sol_invoke_signed 等）
- 内存管理（Solana 32KB 堆的 Bump 分配器）
- 数据序列化（Borsh 格式处理）
- 入口点管理

**关键组件**：
```zig
// SDK 中 sol_log 实现的示例
pub fn sol_log(message: []const u8) void {
    asm volatile ("call sol_log_"
        :
        : [message_ptr] "{r1}" (message.ptr),
          [message_len] "{r2}" (message.len)
    );
}
```

## 第二层：宿主胶水层（转换）

**文件**：`platform/host.zig`

该层充当 Roc 函数式世界和 Zig 命令式世界之间的桥梁。它处理：
- Roc 运行时内存分配（roc_alloc、roc_dealloc）
- 数据格式转换（RocStr ↔ []u8，Roc 结构体 ↔ Zig 结构体）
- 效果处理（将 Roc 效果转换为 Zig SDK 调用）

**实现示例**：
```zig
const sdk = @import("solana-program-sdk");

export fn roc_fx_log(msg: RocStr) void {
    const zig_slice = msg.asSlice();
    sdk.log.sol_log(zig_slice);
}

export fn roc_fx_transfer(from: *Pubkey, to: *Pubkey, amount: u64) void {
    const instruction = sdk.system_program.transfer(from, to, amount);
    sdk.invoke(&instruction, ...);
}
```

## 第三层：Roc 平台层（接口）

**文件**：`platform/main.roc`、`app.roc`

该层为开发者提供函数式编程接口：
- 镜像 Solana 数据结构的类型定义
- 副作用的效果声明
- 纯函数式合约逻辑

**平台定义示例**：
```elm
platform "solana"
    requires {} { main : Context -> Result Unit [Error Str] }
    exposes [ Context, Account, Pubkey, log, transfer ]
    packages {}
    imports []
    provides [ mainForHost ]

Pubkey : [ Pubkey (List U8) ]

Account : {
    key : Pubkey,
    lamports : U64,
    data : List U8,
    owner : Pubkey,
    is_signer : Bool,
}

log : Str -> Task {} []
log = \msg -> Effect.log msg

transfer : Pubkey -> Pubkey -> U64 -> Task {} []
transfer = \from to amount -> Effect.transfer from to amount
```

**用户合约示例**：
```elm
app "token-contract"
    packages { pf: "platform/main.roc" }
    imports [ pf.Context, pf.Account, pf.log, pf.transfer ]
    provides [ main ] to pf

main : Context -> Result {} [Error Str]
main = \ctx ->
    when List.first ctx.accounts is
        Ok account ->
            if account.is_signer then
                transfer account.key some_other_key 1000
                log "Transfer successful"
                Ok {}
            else
                Err (Error "First account must be signer")
        
        Err _ -> Err (Error "No accounts provided")
```

## 数据流

1. Solana 运行时调用 `entrypoint(input)` 在 host.zig 中
2. 宿主使用 Zig SDK 解析输入为结构化数据
3. 宿主将 Zig 结构体转换为 Roc 兼容格式
4. 宿主调用 Roc 的 `mainForHost` 函数
5. Roc 执行纯函数式逻辑，触发效果
6. 效果由宿主胶水函数处理，调用 Zig SDK
7. 结果序列化回并返回给 Solana

## 优势

- **性能**：Roc 的 Perceus 算法提供 GC 免费性能，无 GC 暂停
- **开发者体验**：函数式编程，强类型和模式匹配
- **重用性**：80% 的实现工作由现有的 Zig SDK 处理
- **可维护性**：各层之间有清晰的职责分离

## 挑战

- Roc 和 Zig 之间的 ABI 兼容性
- LLVM 目标兼容性（Roc → BPF via Zig 工具链）
- 构建系统集成用于混合语言编译