# Roc on Solana

使用 Roc 函数式编程语言在 Solana 区块链上编写智能合约。

## 快速开始

```bash
# 1. 克隆项目
git clone https://github.com/YourRepo/solana-sdk-roc.git
cd solana-sdk-roc

# 2. 一键安装工具链
./install.sh

# 3. 编译 Roc 程序
./roc-solana build test-roc/fib_dynamic.roc

# 4. 部署到本地测试网
solana-test-validator  # 另一个终端
./roc-solana deploy

# 5. 测试
./roc-solana test
```

## 项目状态

**当前版本**: v0.2.0 ✅

| 功能 | 状态 | 计算单元 |
|------|------|----------|
| Hello World | ✅ | ~127 CU |
| 递归 Fibonacci(15) | ✅ | ~20,842 CU |
| 迭代 Fibonacci(50) | ✅ | ~831 CU |
| 字符串插值 | ✅ | ~2,339 CU |

## 安装选项

### 完整安装 (推荐)

```bash
./install.sh
```

自动安装:
- solana-zig (Zig 0.15.2 + SBF 支持)
- Roc 编译器 (带 SBF 补丁)
- Node.js 依赖

### 快速安装 (仅下载工具链)

```bash
./install.sh --quick
# 稍后编译 Roc:
./install.sh --roc-only
```

### 手动安装

参见 [docs/roc-build-guide.md](docs/roc-build-guide.md)

## 使用方法

### roc-solana 命令

```bash
./roc-solana build [app.roc]  # 编译 Roc 应用
./roc-solana deploy           # 部署到 Solana
./roc-solana test             # 调用程序
./roc-solana clean            # 清理缓存
```

### 直接使用 zig build

```bash
# 编译
./solana-zig/zig build roc -Droc-app=your-app.roc

# 测试
./solana-zig/zig build test
```

## 编写 Roc 程序

创建新的 Roc 应用:

```roc
# my-app.roc
app [main] { pf: platform "platform/main.roc" }

main : Str
main = "Hello from Roc on Solana!"
```

编译并部署:

```bash
./roc-solana build my-app.roc
./roc-solana deploy
./roc-solana test
```

## 项目结构

```
solana-sdk-roc/
├── install.sh           # 一键安装脚本
├── roc-solana           # 便捷命令工具
├── build.zig            # 构建配置
├── platform/            # Roc 平台定义
│   ├── main.roc
│   └── targets/
├── src/host.zig         # Solana 宿主代码
├── test-roc/            # 示例程序
│   └── fib_dynamic.roc
├── scripts/
│   └── call-program.mjs # 测试脚本
├── docs/
│   ├── roc-build-guide.md
│   ├── roc-sbf-complete.patch
│   └── ...
├── solana-zig/          # (安装后) Zig + SBF
└── roc-source/          # (安装后) Roc 编译器
```

## 前置要求

| 依赖 | 版本 | 安装命令 |
|------|------|----------|
| LLVM | 18.x | `sudo apt install llvm-18 llvm-18-dev` |
| Rust | latest | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Solana CLI | 2.0+ | `sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"` |
| Node.js | 18+ | `sudo apt install nodejs npm` |

## 架构

```
Roc 源码 (.roc)
    │
    ▼ [Roc 编译器 + SBF 补丁]
LLVM Bitcode (.bc)
    │
    ▼ [solana-zig]
Solana SBF 程序 (.so)
    │
    ▼ [solana program deploy]
链上程序
```

## 文档

| 文档 | 说明 |
|------|------|
| [roc-build-guide.md](docs/roc-build-guide.md) | 完整编译指南 |
| [journey-from-zero-to-success.md](docs/journey-from-zero-to-success.md) | 开发历程 |
| [roc-sbf-complete.md](docs/roc-sbf-complete.md) | Roc 修改详解 |
| [architecture.md](docs/architecture.md) | 架构说明 |

## 常见问题

### 编译错误: `enum 'Target.Cpu.Arch' has no member named 'sbf'`

必须使用 `./solana-zig/zig` 而不是系统 zig:

```bash
# ❌ 错误
zig build

# ✅ 正确
./solana-zig/zig build
```

### Roc 编译器找不到

运行 `./install.sh --roc-only` 重新编译 Roc。

### 部署失败

确保本地验证器运行中:
```bash
solana-test-validator
solana config set --url localhost
solana airdrop 2
```

## 相关资源

- [Roc 语言](https://www.roc-lang.org/)
- [Solana 文档](https://docs.solana.com/)
- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)

## 许可证

MIT
