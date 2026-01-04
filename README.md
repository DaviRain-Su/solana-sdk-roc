# Roc on Solana

使用 Roc 函数式编程语言在 Solana 区块链上编写智能合约。

## 项目状态

**当前版本**: v0.2.0 ✅ (核心功能完成)

### 已验证功能

| 功能 | 状态 | 计算单元 |
|------|------|----------|
| Hello World | ✅ | ~127 CU |
| 递归 Fibonacci(15) | ✅ | ~20,842 CU |
| 迭代 Fibonacci(50) | ✅ | ~831 CU |
| **字符串插值** | ✅ | ~2,339 CU |

### 示例输出

```
Program log: Fib(10) = 55
Program consumed 2339 of 200000 compute units
Program success
```

## 快速开始

### 前置条件

详细安装指南见 [docs/roc-build-guide.md](docs/roc-build-guide.md)

```bash
# 1. LLVM 18
sudo apt install llvm-18 llvm-18-dev

# 2. Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. Solana CLI
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

# 4. solana-zig (已包含或下载)
wget https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.52.0/zig-x86_64-linux-musl.tar.bz2
tar -xjf zig-x86_64-linux-musl.tar.bz2 && mv zig-x86_64-linux-musl solana-zig
```

### 编译 Roc 编译器

```bash
cd roc-source
git apply ../docs/roc-sbf-complete.patch
LLVM_SYS_180_PREFIX=/usr/lib/llvm-18 cargo build --release --features target-bpf -p roc_cli
```

### 构建和部署

```bash
# 编译 Roc 程序
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc

# 启动本地验证器 (另一个终端)
solana-test-validator

# 部署
solana config set --url localhost
solana airdrop 2
solana program deploy zig-out/lib/roc-hello.so

# 测试
node scripts/call-program.mjs
```

## 架构

```
Roc 源码 (.roc)
    │
    ▼ [Roc 编译器 (修改版)]
LLVM Bitcode
    │
    ▼ [solana-zig]
Solana SBF 程序 (.so)
    │
    ▼ [solana program deploy]
链上程序
```

## 项目结构

```
solana-sdk-roc/
├── solana-zig/          # Zig 0.15.2 + SBF 支持
├── roc-source/          # Roc 编译器 (需要打补丁)
├── src/host.zig         # Solana 宿主代码
├── test-roc/            # 测试程序
├── docs/
│   ├── journey-from-zero-to-success.md  # 完整历程
│   ├── roc-build-guide.md               # 编译指南
│   ├── roc-sbf-complete.md              # 修改说明
│   └── roc-sbf-complete.patch           # 补丁文件
└── build.zig
```

## 文档

| 文档 | 说明 |
|------|------|
| [journey-from-zero-to-success.md](docs/journey-from-zero-to-success.md) | 从零到成功的完整历程 |
| [roc-build-guide.md](docs/roc-build-guide.md) | 完整编译指南 |
| [roc-sbf-complete.md](docs/roc-sbf-complete.md) | Roc 修改详解 |
| [architecture.md](docs/architecture.md) | 架构说明 |

## 示例代码

**test-roc/fib_dynamic.roc**:
```roc
app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 10
    result = fib n
    "Fib(10) = $(Num.to_str result)"

fib : U64 -> U64
fib = \num ->
    if num <= 1 then num
    else fib (num - 1) + fib (num - 2)
```

## 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Roc | 开发版 + 补丁 | 函数式编程语言 |
| LLVM | 18.x | 编译器后端 |
| solana-zig | 0.15.2 | SBF 目标编译 |
| Solana CLI | 2.0+ | 部署测试 |

## 未来计划

- [ ] 账户读取支持
- [ ] 指令数据解析
- [ ] CPI (跨程序调用)
- [ ] SPL Token 集成

## 相关资源

- [Roc 语言](https://www.roc-lang.org/)
- [Solana 文档](https://docs.solana.com/)
- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)

## 许可证

MIT
