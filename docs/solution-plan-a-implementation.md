# 方案 A 实施：用 solana-zig-bootstrap 构建 LLVM 库重编译 Roc

> 创建日期: 2026-01-04  
> 更新日期: 2026-01-04  
> 状态: ❌ **阻塞** - LLVM 版本不兼容  
> 预计时间: N/A

---

## 🚨 阻塞问题

**2026-01-04 发现**: LLVM 版本不匹配导致 C++ API 不兼容。

| 组件 | LLVM 版本 |
|------|-----------|
| solana-zig-bootstrap (llvm-project-solana) | **20.1.7** |
| Zig 0.15.2 / Roc 期望 | **19.x** |

**错误现象**:
```
error: undefined symbol: _ZN4llvm14raw_fd_ostreamC1E...
error: undefined symbol: _ZN4llvm11PassBuilderC1E...
(142 个 C++ 符号未定义)
```

**根本原因**: Roc 的 `zig_llvm.cpp` 是为 LLVM 19 API 编写的，LLVM 20 有不兼容的 API 变更。

---

## 问题根源（原始）

Roc 编译器自带的 LLVM **没有 SBF 目标支持**：

```
LLVM error: No available targets are compatible with triple "sbf-solana-solana"
```

**关键问题**：我们之前尝试使用 `solana-rust` 的 LLVM，但它是用 **glibc** 编译的，与 solana-zig 编译的 Roc 存在 **ABI 不兼容** 问题。

---

## 尝试的解决方案（失败）

参照 `solana-zig-bootstrap` 的做法，用 **Zig 编译 LLVM**（产生 musl ABI 兼容的库）：

```
solana-zig-bootstrap 做法：
┌─────────────────────────────────────────────┐
│ 1. llvm-project-solana (LLVM 源码+SBF支持)  │
│ 2. 用 Zig 编译 LLVM → 静态库 (ABI 兼容)     │
│ 3. 链接进 Zig 编译器                         │
└─────────────────────────────────────────────┘

我们对 Roc 也这样做：
┌─────────────────────────────────────────────┐
│ 1. 获取 llvm-project-solana          ✅ 完成 │
│ 2. 用系统编译器编译 LLVM → 静态库    ✅ 完成 │
│ 3. 用这些库编译 Roc                  ❌ 失败 │
└─────────────────────────────────────────────┘
```

**失败原因**: LLVM 20 与 Roc/Zig 的 LLVM 19 C++ API 不兼容

---

## 替代方案评估

### 方案 B: 找到 LLVM 19 + SBF 支持

**可行性**: ⚠️ 未知

需要找到一个基于 LLVM 19 的 Solana LLVM 分支。可能的来源：
- 旧版本的 solana-zig-bootstrap (检查 git tags)
- 自行将 SBF 补丁移植到 LLVM 19

### 方案 C: Zig 代码生成器 (长期方案)

**可行性**: ✅ 可行但耗时

完全绕过 LLVM，为 Roc 实现 Zig 代码生成器。详见 `docs/v0.2.0-roc-zig-codegen-design.md`。

**优点**:
- 不依赖 LLVM 版本
- 利用现有 solana-zig 工具链
- 长期可维护

**缺点**:
- 需要数周开发时间
- 需要深入理解 Roc 编译器内部结构

### 方案 D: 修改 Roc 的 zig_llvm.cpp 适配 LLVM 20

**可行性**: ⚠️ 复杂

更新 Roc 的 C++ LLVM 包装器以兼容 LLVM 20 API。

**挑战**:
- 142 个未定义符号需要修复
- LLVM C++ API 变化可能较大
- 需要深入了解 LLVM API 差异

---

## 建议的下一步

1. **短期**: 检查 solana-zig-bootstrap 是否有基于 LLVM 19 的旧版本
2. **中期**: 评估方案 D（修改 zig_llvm.cpp）的工作量
3. **长期**: 考虑方案 C（Zig 代码生成器）

---

## 已完成的工作

1. ✅ **solana-zig-bootstrap 仓库克隆**
   - 位置: `solana-zig-bootstrap/`
   - 浅克隆完成

2. ✅ **solana-zig 编译器可用**
   - 位置: `solana-zig/zig`
   - 版本: 0.15.2
   - 支持 SBF 目标

3. ✅ **Roc 编译器编译**
   - 位置: `roc-source/zig-out/bin/roc`
   - 编译工具: solana-zig
   - 版本: debug-0e1cab9f
   - 状态: ✓ 可执行，但 LLVM 后端不支持 SBF

## 待执行步骤

### 步骤 1: 初始化 LLVM 子模块

```bash
cd /home/davirain/dev/solana-sdk-roc/solana-zig-bootstrap

# 初始化 llvm-project-solana 子模块
git submodule update --init --recursive llvm-project-solana
```

**预计时间**: 5-10 分钟（下载约 2GB）

**验证**:
```bash
ls solana-zig-bootstrap/llvm-project-solana/llvm/
# 应该看到 CMakeLists.txt, include/, lib/ 等目录
```

### 步骤 2: 构建 LLVM 库（完整方式）

使用 solana-zig-bootstrap 的 build 脚本：

```bash
cd /home/davirain/dev/solana-sdk-roc/solana-zig-bootstrap

# 设置并行构建加速
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

# 构建目标: x86_64-linux-musl (与 Roc 兼容)
./build x86_64-linux-musl baseline
```

**预计时间**: 30-60 分钟

**输出位置**: `solana-zig-bootstrap/out/x86_64-linux-musl-baseline/`

### 步骤 2 (替代): 只构建 LLVM 库

如果只需要 LLVM 库（不需要完整的 Zig 编译器），可以手动执行 build 脚本的前半部分：

```bash
cd /home/davirain/dev/solana-sdk-roc/solana-zig-bootstrap

ROOTDIR=$(pwd)
mkdir -p out/build-llvm-host
cd out/build-llvm-host

# 配置 LLVM（使用系统 C++ 编译器）
cmake "$ROOTDIR/llvm-project-solana/llvm" \
  -DCMAKE_INSTALL_PREFIX="$ROOTDIR/out/host" \
  -DCMAKE_PREFIX_PATH="$ROOTDIR/out/host" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_C_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF

# 构建和安装
cmake --build . --target install -j$(nproc)
```

**输出位置**: `solana-zig-bootstrap/out/host/`

### 步骤 3: 用 LLVM 库编译 Roc

```bash
cd /home/davirain/dev/solana-sdk-roc/roc-source

# 清除旧缓存
rm -rf .zig-cache zig-out

# 使用 solana-zig-bootstrap 的 LLVM 库
../solana-zig/zig build \
    -Dllvm-path=../solana-zig-bootstrap/out/host
```

**预计时间**: 10-20 分钟

### 步骤 4: 验证 SBF 支持

```bash
cd /home/davirain/dev/solana-sdk-roc

# 1. 检查 Roc 版本
./roc-source/zig-out/bin/roc --version

# 2. 检查应用
./roc-source/zig-out/bin/roc check examples/hello-world/app.roc

# 3. 测试 SBF 编译
./roc-source/zig-out/bin/roc build \
    --target=sbfsolana \
    examples/hello-world/app.roc
```

### 步骤 5: 链接和构建最终程序

```bash
cd /home/davirain/dev/solana-sdk-roc

# 使用 solana-zig 构建完整程序
./solana-zig/zig build
```

### 步骤 6: 部署和验证

```bash
# 1. 验证目标文件格式
file zig-out/lib/roc-hello.so

# 2. 启动本地测试网（如需）
solana-test-validator &

# 3. 配置和部署
solana config set --url localhost
solana airdrop 2
solana program deploy zig-out/lib/roc-hello.so

# 4. 验证程序运行
solana logs | grep "Program log:"
```

---

## LLVM 库输出位置

构建完成后，LLVM 库位于：

```
solana-zig-bootstrap/out/host/       # 步骤 2 替代方式
├── bin/           # LLVM 工具 (llc, llvm-ar 等)
├── lib/           # 静态库 (libLLVM*.a, libclang*.a)
└── include/       # 头文件

# 或者完整构建后
solana-zig-bootstrap/out/x86_64-linux-musl-baseline/
├── bin/
├── lib/
└── include/
```

**关键库文件**:
- `libLLVMSBFCodeGen.a` - SBF 代码生成
- `libLLVMSBFAsmParser.a` - SBF 汇编解析
- `libLLVMSBFDesc.a` - SBF 目标描述
- `libLLVMSBFInfo.a` - SBF 目标信息

---

## 资源需求

| 资源 | 需求 |
|------|------|
| 磁盘空间 | ~15GB (LLVM 源码 + 构建产物) |
| 内存 | 8GB+ 推荐 |
| CPU | 多核推荐 (使用 `CMAKE_BUILD_PARALLEL_LEVEL`) |
| 时间 | 30-60 分钟 |

---

## 并行构建加速

```bash
# 设置并行构建数量（使用 CPU 核心数）
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

# 或使用 Ninja 构建系统（更快）
export CMAKE_GENERATOR=Ninja
```

---

## 关键检查清单

### 前置检查
- [x] solana-zig-bootstrap 仓库克隆
- [ ] llvm-project-solana 子模块初始化
- [x] solana-zig 编译器可用
- [x] Roc 源码可用

### LLVM 构建检查
- [ ] LLVM 配置成功: `cmake` 无错误
- [ ] LLVM 构建完成: `cmake --build .` 成功
- [ ] 关键库存在: `ls out/host/lib/libLLVMSBFCodeGen.a`

### Roc 编译检查
- [ ] Roc 编译成功: `../solana-zig/zig build -Dllvm-path=...`
- [ ] Roc 可执行: `./zig-out/bin/roc --version`
- [ ] SBF 目标支持: `roc build --target=sbfsolana ...` 无错误

### 部署检查
- [ ] 程序文件有效: `file zig-out/lib/roc-hello.so`
- [ ] 部署成功: `solana program deploy ...`
- [ ] 程序执行成功: 检查日志输出

---

## 常见问题排查

### 问题 1: 子模块下载缓慢

```bash
# 使用浅克隆
git submodule update --init --recursive --depth 1 llvm-project-solana
```

### 问题 2: 构建内存不足

```bash
# 减少并行任务数
export CMAKE_BUILD_PARALLEL_LEVEL=2
```

### 问题 3: Roc 不识别 LLVM 路径

检查路径结构是否正确：

```bash
ls solana-zig-bootstrap/out/host/
# 应该包含: bin/ lib/ include/
```

### 问题 4: "LLVM error: No available targets are compatible with triple"

**原因**: LLVM 库未包含 SBF 支持

**解决方案**: 确保使用 llvm-project-solana（而非标准 LLVM）

---

## 时间估计

| 阶段 | 任务 | 时间 |
|------|------|------|
| 1 | 初始化 LLVM 子模块 | 5-10 分钟 |
| 2 | 构建 LLVM | 30-60 分钟 |
| 3 | 编译 Roc | 10-20 分钟 |
| 4-6 | 验证和部署 | 10 分钟 |
| **总计** | | **1-2 小时** |

---

## 下一步行动

1. **立即**: 执行步骤 1 - 初始化 LLVM 子模块
2. **然后**: 执行步骤 2 - 构建 LLVM（后台运行）
3. **完成后**: 执行步骤 3-6 - 编译 Roc 并验证

---

## 参考资源

- [solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap)
- [llvm-project-solana](https://github.com/joncinque/llvm-project-solana)
- [Roc build.zig LLVM 配置](../roc-source/build.zig)

---

**进度追踪**: 详见 `stories/v0.2.0-roc-integration.md`
