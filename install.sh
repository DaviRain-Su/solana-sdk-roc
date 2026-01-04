#!/bin/sh
# roc-solana installer
# Usage: curl -sSf https://raw.githubusercontent.com/DaviRain-Su/solana-sdk-roc/main/install.sh | sh

set -e

REPO="DaviRain-Su/solana-sdk-roc"
CLI_VERSION="0.1.0"
INSTALL_DIR="${HOME}/.local/bin"

# Colors (using printf for POSIX compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}info:${NC} %s\n" "$1"; }
success() { printf "${GREEN}success:${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}warning:${NC} %s\n" "$1"; }
error() { printf "${RED}error:${NC} %s\n" "$1"; exit 1; }

detect_platform() {
    os=""
    arch=""

    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="macos" ;;
        *)       error "Unsupported OS: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac

    echo "${os}-${arch}"
}

install_cli() {
    platform="$1"
    artifact="roc-solana-${platform}"
    url="https://github.com/${REPO}/releases/download/cli-v${CLI_VERSION}/${artifact}"
    tmp_file="/tmp/${artifact}"

    info "Downloading roc-solana CLI v${CLI_VERSION}..."
    info "Platform: ${platform}"

    if command -v curl &> /dev/null; then
        curl -fsSL "${url}" -o "${tmp_file}" || error "Failed to download from ${url}"
    elif command -v wget &> /dev/null; then
        wget -q "${url}" -O "${tmp_file}" || error "Failed to download from ${url}"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi

    # Create install directory
    mkdir -p "${INSTALL_DIR}"

    # Install binary
    mv "${tmp_file}" "${INSTALL_DIR}/roc-solana"
    chmod +x "${INSTALL_DIR}/roc-solana"

    success "Installed roc-solana to ${INSTALL_DIR}/roc-solana"
}

update_path() {
    shell_config=""
    path_export="export PATH=\"\${HOME}/.local/bin:\${PATH}\""

    if [ -n "${BASH_VERSION}" ]; then
        if [ -f "${HOME}/.bashrc" ]; then
            shell_config="${HOME}/.bashrc"
        elif [ -f "${HOME}/.bash_profile" ]; then
            shell_config="${HOME}/.bash_profile"
        fi
    elif [ -n "${ZSH_VERSION}" ]; then
        shell_config="${HOME}/.zshrc"
    fi

    if [ -z "${shell_config}" ]; then
        for f in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
            if [ -f "$f" ]; then
                shell_config="$f"
                break
            fi
        done
    fi

    if echo "${PATH}" | grep -q "${INSTALL_DIR}"; then
        return 0
    fi

    if [ -n "${shell_config}" ]; then
        if ! grep -q ".local/bin" "${shell_config}" 2>/dev/null; then
            echo "" >> "${shell_config}"
            echo "# roc-solana" >> "${shell_config}"
            echo "${path_export}" >> "${shell_config}"
            info "Added ${INSTALL_DIR} to PATH in ${shell_config}"
        fi
    fi
}

main() {
    echo ""
    printf "${GREEN}╔═══════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║     roc-solana installer v${CLI_VERSION}            ║${NC}\n"
    printf "${GREEN}╚═══════════════════════════════════════════╝${NC}\n"
    echo ""

    platform=$(detect_platform)

    # Install CLI
    install_cli "${platform}"

    update_path

    echo ""
    printf "${GREEN}════════════════════════════════════════════${NC}\n"
    success "roc-solana has been installed!"
    echo ""
    echo "To get started, run:"
    echo ""
    printf "  ${YELLOW}source ~/.bashrc${NC}  (or restart your terminal)\n"
    printf "  ${YELLOW}roc-solana toolchain install${NC}\n"
    printf "  ${YELLOW}roc-solana init my-program${NC}\n"
    printf "  ${YELLOW}cd my-program${NC}\n"
    printf "  ${YELLOW}roc-solana build${NC}\n"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    printf "${GREEN}════════════════════════════════════════════${NC}\n"
}

main "$@"
