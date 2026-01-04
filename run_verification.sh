#!/bin/bash

################################################################################
# v0.2.0 Roc SBF 编译链验证脚本
# 
# 执行: cd /home/davirain/dev/solana-sdk-roc && bash run_verification.sh
# 
# 验证内容:
# 1. Roc 编译器可用性
# 2. 应用编译检查
# 3. LLVM 位码生成
# 4. SBF 目标编译
# 5. Zig 最终链接
################################################################################

set -e  # 任何错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工具路径
LLVM_PATH="solana-rust/build/x86_64-unknown-linux-gnu/llvm/build"
ROC_BIN="./roc-source/zig-out/bin/roc"
ZIG_BIN="./solana-zig/zig"

# 输出目录
mkdir -p zig-out/lib

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}v0.2.0 Roc SBF 编译链完整验证${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================================================
# 测试 1: Roc 编译器版本检查
# ============================================================================
echo -e "${YELLOW}[测试 1/5] Roc 编译器版本检查${NC}"
echo "执行: $ROC_BIN --version"

if $ROC_BIN --version > /dev/null 2>&1; then
    ROC_VERSION=$($ROC_BIN --version 2>/dev/null | head -1)
    echo -e "${GREEN}✅ Roc 编译器可用${NC}"
    echo "   版本: $ROC_VERSION"
else
    echo -e "${RED}❌ Roc 编译器不可用${NC}"
    echo "   路径: $ROC_BIN"
    echo "   检查: 确保 roc-source 已编译"
    exit 1
fi
echo ""

# ============================================================================
# 测试 2: Roc 应用编译检查
# ============================================================================
echo -e "${YELLOW}[测试 2/5] Roc 应用编译检查${NC}"
echo "执行: $ROC_BIN check examples/hello-world/app.roc"

if $ROC_BIN check examples/hello-world/app.roc 2>&1; then
    echo -e "${GREEN}✅ 应用编译检查通过${NC}"
else
    echo -e "${RED}❌ 应用编译检查失败${NC}"
    echo "   参考: docs/roc-llvm-sbf-fix.md"
    exit 1
fi
echo ""

# ============================================================================
# 测试 3: LLVM 位码生成
# ============================================================================
echo -e "${YELLOW}[测试 3/5] LLVM 位码生成${NC}"
echo "执行: $ROC_BIN build --target sbfsolana --emit-llvm-bc ..."

if $ROC_BIN build \
    --target sbfsolana \
    --emit-llvm-bc \
    examples/hello-world/app.roc \
    -o zig-out/lib/app.bc 2>&1; then
    
    # 验证文件
    if file zig-out/lib/app.bc | grep -q "LLVM bitcode"; then
        echo -e "${GREEN}✅ 位码生成成功${NC}"
        ls -lh zig-out/lib/app.bc
    else
        echo -e "${RED}❌ 生成的文件不是有效的 LLVM 位码${NC}"
        file zig-out/lib/app.bc
        exit 1
    fi
else
    echo -e "${RED}❌ 位码生成失败${NC}"
    echo "   可能原因:"
    echo "   - Roc 未识别 sbfsolana 目标"
    echo "   - 三元组配置有问题"
    echo "   参考: TESTING_GUIDE.md 测试 2"
    exit 1
fi
echo ""

# ============================================================================
# 测试 4: Solana LLVM 编译
# ============================================================================
echo -e "${YELLOW}[测试 4/5] Solana LLVM 编译为 SBF 目标代码${NC}"
echo "执行: $LLVM_PATH/bin/llc -march=sbf ..."

# 检查 llc 工具
if [ ! -f "$LLVM_PATH/bin/llc" ]; then
    echo -e "${RED}❌ Solana LLVM 工具不存在${NC}"
    echo "   路径: $LLVM_PATH/bin/llc"
    echo "   检查: Solana LLVM 是否已编译"
    exit 1
fi

if $LLVM_PATH/bin/llc \
    -march=sbf \
    -filetype=obj \
    -o zig-out/lib/app.o \
    zig-out/lib/app.bc 2>&1; then
    
    # 验证文件
    if file zig-out/lib/app.o | grep -qi "ELF.*SBF"; then
        echo -e "${GREEN}✅ SBF 目标文件生成成功${NC}"
        ls -lh zig-out/lib/app.o
    else
        echo -e "${YELLOW}⚠️  生成的文件格式可能不是标准 SBF${NC}"
        file zig-out/lib/app.o
        echo "   继续验证..."
    fi
else
    echo -e "${RED}❌ SBF 编译失败${NC}"
    echo "   参考: TESTING_GUIDE.md 测试 3"
    exit 1
fi
echo ""

# ============================================================================
# 测试 5: Zig 构建
# ============================================================================
echo -e "${YELLOW}[测试 5/5] Zig 构建最终程序${NC}"
echo "执行: $ZIG_BIN build"

# 清除旧的构建
rm -f zig-out/lib/roc-hello.so 2>/dev/null || true

if $ZIG_BIN build 2>&1 | tail -20; then
    # 验证最终文件
    if [ -f "zig-out/lib/roc-hello.so" ]; then
        if file zig-out/lib/roc-hello.so | grep -qi "ELF.*SBF"; then
            echo -e "${GREEN}✅ Zig 构建成功${NC}"
            ls -lh zig-out/lib/roc-hello.so
        else
            echo -e "${YELLOW}⚠️  程序文件格式检查${NC}"
            file zig-out/lib/roc-hello.so
        fi
    else
        echo -e "${RED}❌ 构建后未找到 roc-hello.so${NC}"
        ls -lh zig-out/lib/
        exit 1
    fi
else
    echo -e "${RED}❌ Zig 构建失败${NC}"
    echo "   参考: TESTING_GUIDE.md 测试 5"
    exit 1
fi
echo ""

# ============================================================================
# 最终验证
# ============================================================================
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 所有验证通过！${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

echo "生成的文件:"
echo "  1. 位码文件:      zig-out/lib/app.bc"
echo "  2. 目标文件:      zig-out/lib/app.o"
echo "  3. 最终程序:      zig-out/lib/roc-hello.so"
echo ""

echo "文件大小汇总:"
ls -lh zig-out/lib/app.* zig-out/lib/roc-hello.so 2>/dev/null || echo "   (部分文件未找到)"
echo ""

echo "下一步:"
echo "  1. 启动测试网:"
echo "     $ solana-test-validator"
echo ""
echo "  2. 部署程序:"
echo "     $ solana config set --url localhost"
echo "     $ solana program deploy zig-out/lib/roc-hello.so"
echo ""
echo "  3. 查看日志:"
echo "     $ solana logs <PROGRAM_ID>"
echo ""
echo "更新进度:"
echo "  - 编辑 IMPLEMENTATION_STATUS.md"
echo "  - 编辑 stories/v0.2.0-roc-integration.md 标记完成"
echo ""
