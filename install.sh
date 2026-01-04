#!/bin/bash
# roc-solana installer
# Usage: curl -sSf https://raw.githubusercontent.com/aspect-build/roc-solana/main/install.sh | sh

set -e

REPO="aspect-build/solana-sdk-roc"
CLI_VERSION="0.1.0"
INSTALL_DIR="${HOME}/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}info:${NC} $1"; }
success() { echo -e "${GREEN}success:${NC} $1"; }
warn() { echo -e "${YELLOW}warning:${NC} $1"; }
error() { echo -e "${RED}error:${NC} $1"; exit 1; }

# Detect OS and architecture
detect_platform() {
    local os arch

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

# Download and install CLI
install_cli() {
    local platform="$1"
    local artifact="roc-solana-${platform}"
    local url="https://github.com/${REPO}/releases/download/cli-v${CLI_VERSION}/${artifact}"
    local tmp_file="/tmp/${artifact}"

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

# Update PATH in shell config
update_path() {
    local shell_config=""
    local path_export="export PATH=\"\${HOME}/.local/bin:\${PATH}\""

    # Detect shell config file
    if [ -n "${BASH_VERSION}" ]; then
        if [ -f "${HOME}/.bashrc" ]; then
            shell_config="${HOME}/.bashrc"
        elif [ -f "${HOME}/.bash_profile" ]; then
            shell_config="${HOME}/.bash_profile"
        fi
    elif [ -n "${ZSH_VERSION}" ]; then
        shell_config="${HOME}/.zshrc"
    fi

    # Also check common config files
    if [ -z "${shell_config}" ]; then
        for f in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
            if [ -f "$f" ]; then
                shell_config="$f"
                break
            fi
        done
    fi

    # Check if PATH already includes install dir
    if echo "${PATH}" | grep -q "${INSTALL_DIR}"; then
        return 0
    fi

    # Add to shell config if found
    if [ -n "${shell_config}" ]; then
        if ! grep -q ".local/bin" "${shell_config}" 2>/dev/null; then
            echo "" >> "${shell_config}"
            echo "# roc-solana" >> "${shell_config}"
            echo "${path_export}" >> "${shell_config}"
            info "Added ${INSTALL_DIR} to PATH in ${shell_config}"
        fi
    fi
}

# Main installation
main() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     roc-solana installer v${CLI_VERSION}            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Detect platform
    local platform
    platform=$(detect_platform)

    # Install CLI
    install_cli "${platform}"

    # Update PATH
    update_path

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    success "roc-solana has been installed!"
    echo ""
    echo "To get started, run:"
    echo ""
    echo -e "  ${YELLOW}source ~/.bashrc${NC}  # or restart your terminal"
    echo -e "  ${YELLOW}roc-solana toolchain install${NC}"
    echo -e "  ${YELLOW}roc-solana init my-program${NC}"
    echo -e "  ${YELLOW}cd my-program${NC}"
    echo -e "  ${YELLOW}roc-solana build${NC}"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
}

main "$@"
