#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOLANA_ZIG_VERSION="solana-v1.52.0"
SOLANA_ZIG_URL="https://github.com/joncinque/solana-zig-bootstrap/releases/download/${SOLANA_ZIG_VERSION}"

ROC_SBF_VERSION="sbf-v0.1.0"
ROC_SBF_REPO="DaviRain-Su/roc"
ROC_SBF_URL="https://github.com/${ROC_SBF_REPO}/releases/download/${ROC_SBF_VERSION}"

ROC_UPSTREAM_REPO="https://github.com/roc-lang/roc.git"
ROC_UPSTREAM_COMMIT="0e1cab9f87"

detect_arch() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) echo -e "${RED}Unsupported arch: $arch${NC}"; exit 1 ;;
    esac
    
    case "$os" in
        linux) os="linux" ;;
        darwin) os="macos" ;;
        *) echo -e "${RED}Unsupported OS: $os${NC}"; exit 1 ;;
    esac
    
    echo "${arch}-${os}"
}

show_help() {
    cat << 'EOF'
Roc on Solana 安装脚本

用法: ./install.sh [选项]

选项:
  --binary      优先下载预编译的 Roc (快速，推荐)
  --source      从源码编译 Roc (慢，但总是可用)
  --quick       仅安装 solana-zig，跳过 Roc
  --roc-only    仅安装/编译 Roc
  --help        显示帮助

默认行为: 尝试下载预编译版本，失败则从源码编译

前置要求:
  --binary 模式: 无额外要求
  --source 模式: LLVM 18, Rust
EOF
}

check_prerequisites_source() {
    echo -e "${BLUE}检查编译依赖...${NC}"
    local missing=()
    
    if ! command -v llvm-config-18 &> /dev/null && ! [ -d "/usr/lib/llvm-18" ]; then
        missing+=("LLVM 18: sudo apt install llvm-18 llvm-18-dev")
    fi
    
    if ! command -v cargo &> /dev/null; then
        missing+=("Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}缺少依赖:${NC}"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi
    echo -e "${GREEN}✓ 编译依赖已满足${NC}"
}

install_solana_zig() {
    echo -e "\n${BLUE}=== 安装 solana-zig ===${NC}"
    
    if [ -f "${SCRIPT_DIR}/solana-zig/zig" ]; then
        echo -e "${GREEN}✓ solana-zig 已存在${NC}"
        "${SCRIPT_DIR}/solana-zig/zig" version
        return
    fi
    
    local arch_os=$(detect_arch)
    local filename=""
    
    case "$arch_os" in
        x86_64-linux) filename="zig-x86_64-linux-musl.tar.bz2" ;;
        aarch64-linux) filename="zig-aarch64-linux-musl.tar.bz2" ;;
        x86_64-macos) filename="zig-x86_64-macos.tar.bz2" ;;
        aarch64-macos) filename="zig-aarch64-macos.tar.bz2" ;;
    esac
    
    echo "下载 ${filename}..."
    curl -L -o "/tmp/${filename}" "${SOLANA_ZIG_URL}/${filename}"
    
    echo "解压..."
    tar -xjf "/tmp/${filename}" -C "${SCRIPT_DIR}"
    
    local extracted_dir=$(tar -tjf "/tmp/${filename}" | head -1 | cut -d'/' -f1)
    mv "${SCRIPT_DIR}/${extracted_dir}" "${SCRIPT_DIR}/solana-zig"
    rm "/tmp/${filename}"
    
    echo -e "${GREEN}✓ solana-zig 安装完成${NC}"
    "${SCRIPT_DIR}/solana-zig/zig" version
}

install_roc_binary() {
    echo -e "\n${BLUE}=== 下载预编译 Roc (SBF) ===${NC}"
    
    local arch_os=$(detect_arch)
    local filename=""
    
    case "$arch_os" in
        x86_64-linux) filename="roc-sbf-linux-x86_64.tar.gz" ;;
        aarch64-linux) filename="roc-sbf-linux-aarch64.tar.gz" ;;
        x86_64-macos) filename="roc-sbf-macos-x86_64.tar.gz" ;;
        aarch64-macos) filename="roc-sbf-macos-aarch64.tar.gz" ;;
    esac
    
    local download_url="${ROC_SBF_URL}/${filename}"
    echo "尝试下载: ${download_url}"
    
    if curl -fsSL --head "${download_url}" &>/dev/null; then
        echo "下载 ${filename}..."
        mkdir -p "${SCRIPT_DIR}/roc-sbf"
        curl -L -o "/tmp/${filename}" "${download_url}"
        tar -xzf "/tmp/${filename}" -C "${SCRIPT_DIR}/roc-sbf"
        rm "/tmp/${filename}"
        
        if [ -f "${SCRIPT_DIR}/roc-sbf/roc" ]; then
            chmod +x "${SCRIPT_DIR}/roc-sbf/roc"
            echo -e "${GREEN}✓ Roc (SBF) 安装完成${NC}"
            "${SCRIPT_DIR}/roc-sbf/roc" version
            return 0
        fi
    fi
    
    echo -e "${YELLOW}预编译版本不可用${NC}"
    return 1
}

install_roc_source() {
    echo -e "\n${BLUE}=== 从源码编译 Roc ===${NC}"
    
    check_prerequisites_source || exit 1
    
    if [ -f "${SCRIPT_DIR}/roc-source/target/release/roc" ]; then
        echo -e "${YELLOW}Roc 已编译${NC}"
        "${SCRIPT_DIR}/roc-source/target/release/roc" version
        read -p "重新编译? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
    fi
    
    if [ ! -d "${SCRIPT_DIR}/roc-source" ]; then
        echo "克隆 Roc 源码..."
        git clone --depth 1 "${ROC_UPSTREAM_REPO}" "${SCRIPT_DIR}/roc-source"
        cd "${SCRIPT_DIR}/roc-source"
        git fetch --depth 1 origin "${ROC_UPSTREAM_COMMIT}"
        git checkout "${ROC_UPSTREAM_COMMIT}"
    fi
    
    cd "${SCRIPT_DIR}/roc-source"
    
    if [ -f "${SCRIPT_DIR}/docs/roc-sbf-complete.patch" ]; then
        echo "应用 SBF 补丁..."
        git apply "${SCRIPT_DIR}/docs/roc-sbf-complete.patch" 2>/dev/null || echo "补丁可能已应用"
    fi
    
    echo "编译 Roc (约 10-30 分钟)..."
    export LLVM_SYS_180_PREFIX="${LLVM_SYS_180_PREFIX:-/usr/lib/llvm-18}"
    cargo build --release --features target-bpf -p roc_cli
    
    echo -e "${GREEN}✓ Roc 编译完成${NC}"
    "${SCRIPT_DIR}/roc-source/target/release/roc" version
}

install_npm_deps() {
    if command -v npm &> /dev/null; then
        echo -e "\n${BLUE}安装 Node.js 依赖...${NC}"
        cd "${SCRIPT_DIR}" && npm install --silent
        echo -e "${GREEN}✓ 完成${NC}"
    fi
}

create_roc_solana_command() {
    cat > "${SCRIPT_DIR}/roc-solana" << 'SCRIPT'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROC_BIN=""
if [ -f "${SCRIPT_DIR}/roc-sbf/roc" ]; then
    ROC_BIN="${SCRIPT_DIR}/roc-sbf/roc"
elif [ -f "${SCRIPT_DIR}/roc-source/target/release/roc" ]; then
    ROC_BIN="${SCRIPT_DIR}/roc-source/target/release/roc"
fi

case "$1" in
    build)
        ROC_APP="${2:-test-roc/fib_dynamic.roc}"
        echo "编译: ${ROC_APP}"
        "${SCRIPT_DIR}/solana-zig/zig" build roc -Droc-app="${ROC_APP}" ${ROC_BIN:+-Droc-compiler="${ROC_BIN}"}
        ;;
    deploy)
        PROGRAM_ID=$(solana program deploy "${SCRIPT_DIR}/zig-out/lib/roc-hello.so" 2>&1 | grep "Program Id" | awk '{print $3}')
        echo "${PROGRAM_ID}" > "${SCRIPT_DIR}/.program-id"
        echo "Program ID: ${PROGRAM_ID}"
        ;;
    test)
        node "${SCRIPT_DIR}/scripts/call-program.mjs"
        ;;
    clean)
        rm -rf "${SCRIPT_DIR}/.zig-cache" "${SCRIPT_DIR}/zig-out"
        echo "已清理"
        ;;
    version)
        echo "solana-zig: $("${SCRIPT_DIR}/solana-zig/zig" version 2>/dev/null || echo 'not installed')"
        echo "roc: $(${ROC_BIN:-echo 'not installed'} version 2>/dev/null | head -1 || echo 'not installed')"
        ;;
    *)
        echo "用法: roc-solana <build|deploy|test|clean|version> [args]"
        ;;
esac
SCRIPT
    chmod +x "${SCRIPT_DIR}/roc-solana"
}

verify_installation() {
    echo -e "\n${BLUE}=== 验证安装 ===${NC}"
    
    [ -f "${SCRIPT_DIR}/solana-zig/zig" ] && \
        echo -e "${GREEN}✓ solana-zig${NC}" || echo -e "${RED}✗ solana-zig${NC}"
    
    if [ -f "${SCRIPT_DIR}/roc-sbf/roc" ]; then
        echo -e "${GREEN}✓ roc (预编译)${NC}"
    elif [ -f "${SCRIPT_DIR}/roc-source/target/release/roc" ]; then
        echo -e "${GREEN}✓ roc (源码编译)${NC}"
    else
        echo -e "${RED}✗ roc${NC}"
    fi
    
    echo -e "\n${GREEN}快速开始:${NC}"
    echo "  ./roc-solana build test-roc/fib_dynamic.roc"
    echo "  ./roc-solana deploy"
    echo "  ./roc-solana test"
}

main() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Roc on Solana Installer v0.2.0      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    
    local mode="auto"
    local quick=false
    local roc_only=false
    
    for arg in "$@"; do
        case $arg in
            --binary) mode="binary" ;;
            --source) mode="source" ;;
            --quick) quick=true ;;
            --roc-only) roc_only=true ;;
            --help) show_help; exit 0 ;;
        esac
    done
    
    cd "${SCRIPT_DIR}"
    
    if $roc_only; then
        [[ "$mode" == "source" ]] && install_roc_source || { install_roc_binary || install_roc_source; }
        create_roc_solana_command
        verify_installation
        exit 0
    fi
    
    $quick || install_solana_zig
    
    if ! $quick; then
        case "$mode" in
            binary) install_roc_binary || { echo -e "${YELLOW}回退到源码编译...${NC}"; install_roc_source; } ;;
            source) install_roc_source ;;
            auto) install_roc_binary || install_roc_source ;;
        esac
    fi
    
    install_npm_deps
    create_roc_solana_command
    verify_installation
}

main "$@"
