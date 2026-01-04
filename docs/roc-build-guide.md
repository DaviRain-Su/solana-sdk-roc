# Roc on Solana 完整编译指南

> 本文档详细记录了编译支持 Solana SBF 目标的 Roc 编译器所需的所有前置条件和步骤。

## 目录

1. [系统要求](#系统要求)
2. [前置依赖安装](#前置依赖安装)
3. [项目结构](#项目结构)
4. [Roc 编译器编译](#roc-编译器编译)
5. [Solana 程序编译](#solana-程序编译)
6. [部署和测试](#部署和测试)
7. [故障排除](#故障排除)

---

## 系统要求

### 操作系统

- **推荐**: Ubuntu 24.04 LTS (x86_64)
- **支持**: 其他 Linux 发行版 (需要手动安装依赖)
- **内存**: 至少 16GB RAM (编译 Roc 需要大量内存)
- **磁盘**: 至少 20GB 可用空间

### 验证过的环境

```
OS: Ubuntu 24.04 (Linux 6.14.0)
CPU: x86_64
RAM: 16GB+
Disk: 50GB+ available
```

---

## 前置依赖安装

### 1. 系统基础工具

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    pkg-config \
    libssl-dev \
    zlib1g-dev
```

### 2. LLVM 18 (必需)

Roc 编译器依赖 LLVM 18。必须安装开发包。

```bash
# 安装 LLVM 18
sudo apt install -y \
    llvm-18 \
    llvm-18-dev \
    llvm-18-tools \
    llvm-18-runtime \
    llvm-18-linker-tools \
    libpolly-18-dev \
    liblld-18-dev \
    libclang-18-dev

# 验证安装
/usr/lib/llvm-18/bin/llvm-config --version
# 应输出: 18.1.3 或类似版本

# 设置环境变量 (添加到 ~/.bashrc)
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18
```

**重要**: `LLVM_SYS_180_PREFIX` 环境变量必须在编译 Roc 时设置！

### 3. Rust 工具链

```bash
# 安装 Rust (如果没有)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 更新到最新稳定版
rustup update stable

# 验证版本 (需要 Rust 1.70+)
rustc --version
# 应输出: rustc 1.92.0 或更高

cargo --version
# 应输出: cargo 1.92.0 或更高
```

### 4. Node.js (可选，用于测试脚本)

```bash
# 使用 nvm 安装 Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts

# 验证
node --version
# 应输出: v20.x 或更高

npm --version
```

### 5. Solana CLI

```bash
# 安装 Solana CLI
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

# 添加到 PATH (添加到 ~/.bashrc)
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# 验证
solana --version
# 应输出: solana-cli 2.0.x 或更高

# 配置本地开发
solana config set --url localhost
solana-keygen new --no-bip39-passphrase  # 如果没有密钥
```

### 6. solana-zig-bootstrap (必需)

**重要**: 标准 Zig 不支持 SBF 目标，必须使用 solana-zig！

```bash
# 在项目目录下载 solana-zig
cd /path/to/solana-sdk-roc

# 下载预编译版本 (推荐)
# Linux x86_64:
wget https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.52.0/zig-x86_64-linux-musl.tar.bz2
tar -xjf zig-x86_64-linux-musl.tar.bz2
mv zig-x86_64-linux-musl solana-zig

# macOS ARM (M1/M2):
# wget https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.52.0/zig-aarch64-macos-none.tar.bz2
# tar -xjf zig-aarch64-macos-none.tar.bz2
# mv zig-aarch64-macos-none solana-zig

# macOS Intel:
# wget https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.52.0/zig-x86_64-macos-none.tar.bz2
# tar -xjf zig-x86_64-macos-none.tar.bz2
# mv zig-x86_64-macos-none solana-zig

# 或者从源码编译 (需要很长时间，约 1-2 小时)
git clone --recursive https://github.com/joncinque/solana-zig-bootstrap.git
cd solana-zig-bootstrap
./build
cd ..
ln -s solana-zig-bootstrap/out/zig-* solana-zig

# 验证
./solana-zig/zig version
# 应输出: 0.15.2

# 验证 SBF 支持
./solana-zig/zig targets | grep -i sbf
# 应该看到 sbf 相关目标
```

**所有可用下载**:
- `zig-x86_64-linux-musl.tar.bz2` - Linux x86_64
- `zig-aarch64-linux-musl.tar.bz2` - Linux ARM64
- `zig-x86_64-macos-none.tar.bz2` - macOS Intel
- `zig-aarch64-macos-none.tar.bz2` - macOS ARM (M1/M2)

---

## 项目结构

```
solana-sdk-roc/
├── solana-zig/                 # solana-zig-bootstrap (Zig 0.15.2 + SBF)
│   └── zig                     # 编译器可执行文件
├── roc-source/                 # Roc 编译器源码 (需要修改)
│   ├── crates/                 # Rust crates
│   │   ├── cli/               # CLI 入口
│   │   ├── compiler/          # 编译器核心
│   │   │   ├── build/         # 构建系统
│   │   │   ├── gen_llvm/      # LLVM 代码生成
│   │   │   ├── builtins/      # 内置函数 (Zig)
│   │   │   └── roc_target/    # 目标平台定义
│   │   └── ...
│   ├── src/                    # Zig 源码
│   │   ├── target/            # 目标定义
│   │   └── cli/               # CLI 实现
│   ├── Cargo.toml
│   └── build.zig
├── src/
│   └── host.zig               # Solana 宿主代码
├── test-roc/                   # 测试 Roc 程序
│   ├── fib_dynamic.roc        # 字符串插值测试
│   └── ...
├── vendor/
│   └── solana-program-sdk-zig/ # Solana SDK
├── docs/
│   ├── roc-sbf-complete.patch # 完整补丁
│   └── ...
├── build.zig                   # 项目构建配置
└── build.zig.zon              # 依赖配置
```

---

## Roc 编译器编译

### 步骤 1: 获取 Roc 源码

```bash
cd /path/to/solana-sdk-roc

# 克隆 Roc 源码 (如果没有)
git clone https://github.com/roc-lang/roc.git roc-source
cd roc-source

# 或者更新现有源码
cd roc-source
git fetch origin
git checkout main
git pull
```

### 步骤 2: 应用 SBF 支持补丁

```bash
cd roc-source

# 确保工作目录干净
git status

# 应用完整补丁
git apply ../docs/roc-sbf-complete.patch

# 如果有冲突，使用 --reject 选项
git apply --reject ../docs/roc-sbf-complete.patch
# 然后手动解决 .rej 文件

# 验证修改
git diff --stat
# 应显示约 33 个文件被修改
```

### 步骤 3: 编译 Roc 编译器

```bash
cd roc-source

# 设置 LLVM 环境变量 (重要!)
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18

# 编译 (仅 CLI，节省时间)
cargo build --release --features target-bpf -p roc_cli

# 编译时间约 5-15 分钟，取决于机器性能
# 首次编译会下载依赖，可能需要更长时间

# 验证编译成功
./target/release/roc version
# 应输出类似: roc debug-xxxxxxxx

# 验证 SBF 目标支持
./target/release/roc --help | grep -i target
```

### 编译选项说明

| 选项 | 说明 |
|------|------|
| `--release` | Release 模式编译，优化性能 |
| `--features target-bpf` | 启用 BPF/SBF 目标支持 |
| `-p roc_cli` | 仅编译 CLI 包，节省时间 |

### 常见编译错误

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `LLVM_SYS_180_PREFIX not set` | 未设置环境变量 | `export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18` |
| `llvm-config not found` | LLVM 未安装或路径错误 | 安装 `llvm-18-dev` |
| `linking with cc failed` | 缺少链接库 | 安装 `build-essential` |
| `memory allocation failed` | 内存不足 | 关闭其他程序，或添加 swap |

---

## Solana 程序编译

### 步骤 1: 安装项目依赖

```bash
cd /path/to/solana-sdk-roc

# 安装 npm 依赖 (用于测试脚本)
npm install

# 验证 solana-zig
./solana-zig/zig version
```

### 步骤 2: 编译 Roc 程序到 Solana

```bash
# 完整编译流程: Roc → LLVM BC → SBF Object → .so
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc

# 编译流程说明:
# 1. roc build --target sbf --no-link  → 生成 .o (LLVM bitcode)
# 2. cp .o .bc                          → 重命名为 .bc
# 3. solana-zig build-obj .bc           → 编译为 SBF 目标代码
# 4. solana-zig build-lib               → 链接生成 .so
```

### 步骤 3: 验证输出

```bash
# 检查生成的文件
ls -la zig-out/lib/roc-hello.so

# 验证 ELF 格式
file zig-out/lib/roc-hello.so
# 应输出: ELF 64-bit LSB shared object, eBPF
```

### 编译选项

```bash
# 使用不同的 Roc 应用
./solana-zig/zig build roc -Droc-app=path/to/app.roc

# 指定 Roc 编译器路径
./solana-zig/zig build roc -Droc-compiler=./custom/roc

# 仅编译 Roc 部分 (不链接)
./solana-zig/zig build roc
```

---

## 部署和测试

### 启动本地验证器

```bash
# 在单独的终端运行
solana-test-validator

# 等待启动完成 (看到 "Ledger location:" 消息)
```

### 配置和充值

```bash
# 配置使用本地网络
solana config set --url localhost

# 检查余额
solana balance

# 如果余额不足，空投 SOL
solana airdrop 10
```

### 部署程序

```bash
# 部署
solana program deploy zig-out/lib/roc-hello.so

# 记录输出的 Program Id
# 例如: Program Id: CPXHpK5aQhzvwU1ysw3D7F9VMcdyt7iY2N8eieiVsvbN

# 保存 Program Id 供测试使用
echo "CPXHpK5aQhzvwU1ysw3D7F9VMcdyt7iY2N8eieiVsvbN" > .program-id
```

### 调用程序

```bash
# 使用 Node.js 脚本调用
node scripts/call-program.mjs

# 预期输出:
# Program log: Fib(10) = 55
# Program consumed 2339 of 200000 compute units
# Program success
```

---

## 故障排除

### 问题 1: LLVM 版本不匹配

**症状**: 编译时报 LLVM 版本错误

**解决**:
```bash
# 检查 LLVM 版本
/usr/lib/llvm-18/bin/llvm-config --version

# 确保环境变量正确
echo $LLVM_SYS_180_PREFIX
# 应输出: /usr/lib/llvm-18
```

### 问题 2: 补丁应用失败

**症状**: `git apply` 报冲突

**解决**:
```bash
# 使用 3-way 合并
git apply --3way ../docs/roc-sbf-complete.patch

# 或者查看拒绝的部分
git apply --reject ../docs/roc-sbf-complete.patch
# 手动编辑 .rej 文件指示的冲突
```

### 问题 3: memcpy_c 未定义

**症状**: 部署时报 `Unresolved symbol (memcpy_c)`

**解决**: 确保 `src/host.zig` 中导出了这些函数:
```zig
pub export fn memcpy_c(dest: [*]u8, src: [*]const u8, count: usize) callconv(.c) [*]u8 {
    @memcpy(dest[0..count], src[0..count]);
    return dest;
}

pub export fn memset_c(dest: [*]u8, val: i32, count: usize) callconv(.c) [*]u8 {
    @memset(dest[0..count], @intCast(val));
    return dest;
}
```

### 问题 4: SBF 目标不支持

**症状**: `enum 'Target.Cpu.Arch' has no member named 'sbf'`

**解决**: 使用 solana-zig 而不是系统 zig:
```bash
# 错误
zig build

# 正确
./solana-zig/zig build
```

### 问题 5: 内存不足

**症状**: 编译时崩溃或报内存错误

**解决**:
```bash
# 添加 swap 空间
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 减少并行编译
cargo build --release --features target-bpf -p roc_cli -j 2
```

---

## 环境变量汇总

添加到 `~/.bashrc`:

```bash
# LLVM 18
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18

# Solana CLI
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# 项目目录 (可选)
export ROC_SOLANA_DIR=/path/to/solana-sdk-roc
alias solana-zig='$ROC_SOLANA_DIR/solana-zig/zig'
```

---

## 快速参考

### 编译 Roc 编译器

```bash
cd roc-source
export LLVM_SYS_180_PREFIX=/usr/lib/llvm-18
cargo build --release --features target-bpf -p roc_cli
```

### 编译 Solana 程序

```bash
./solana-zig/zig build roc -Droc-app=test-roc/fib_dynamic.roc
```

### 部署和测试

```bash
solana program deploy zig-out/lib/roc-hello.so
node scripts/call-program.mjs
```

---

## 版本兼容性矩阵

| 组件 | 版本 | 备注 |
|------|------|------|
| Ubuntu | 24.04 LTS | 推荐 |
| LLVM | 18.x | 必需 |
| Rust | 1.70+ | 推荐最新稳定版 |
| solana-zig | 0.15.2 | 必需 |
| Solana CLI | 2.0+ | 推荐最新版 |
| Node.js | 20+ | 可选，用于测试 |

---

## 相关文档

- `docs/roc-sbf-complete.md` - 完整修改说明
- `docs/roc-sbf-complete.patch` - 完整补丁文件
- `docs/roc-sbf-string-fix.md` - 字符串 ABI 修复详解
- `docs/architecture.md` - 架构文档
- `README.md` - 项目简介
