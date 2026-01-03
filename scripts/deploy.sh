#!/bin/bash
# Deploy Roc on Solana Hello World Program
#
# This script handles the complete deployment process:
# 1. Builds the BPF program (if not already built)
# 2. Starts local validator (if not running)
# 3. Airdrops SOL for deployment
# 4. Deploys the program
# 5. Saves the program ID for later use
#
# Usage:
#   ./scripts/deploy.sh          # Full deployment
#   ./scripts/deploy.sh --build  # Build and deploy
#   ./scripts/deploy.sh --skip-validator  # Skip validator check

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAM_SO="${PROJECT_ROOT}/zig-out/lib/roc-hello.so"
PROGRAM_ID_FILE="${PROJECT_ROOT}/.program-id"
KEYPAIR_FILE="${HOME}/.config/solana/id.json"

echo -e "${BLUE}=== Roc on Solana Deployment ===${NC}"
echo ""

# Parse arguments
BUILD_FIRST=false
SKIP_VALIDATOR=false
for arg in "$@"; do
    case $arg in
        --build)
            BUILD_FIRST=true
            ;;
        --skip-validator)
            SKIP_VALIDATOR=true
            ;;
    esac
done

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

if ! command -v solana &> /dev/null; then
    echo -e "${RED}Error: Solana CLI not installed${NC}"
    echo "Install from: https://docs.solana.com/cli/install-solana-cli-tools"
    exit 1
fi

if ! command -v zig &> /dev/null; then
    echo -e "${RED}Error: Zig not installed${NC}"
    echo "Install from: https://ziglang.org/download/"
    exit 1
fi

echo -e "${GREEN}  Solana CLI: $(solana --version)${NC}"
echo -e "${GREEN}  Zig: $(zig version)${NC}"

# Step 2: Build if requested
if [ "$BUILD_FIRST" = true ]; then
    echo ""
    echo -e "${YELLOW}Step 2: Building BPF program...${NC}"
    cd "${PROJECT_ROOT}"
    zig build bpf
    
    if command -v sbpf-linker &> /dev/null; then
        echo -e "${BLUE}  Running sbpf-linker...${NC}"
        zig build link
    else
        echo -e "${YELLOW}  Warning: sbpf-linker not installed${NC}"
        echo "  Install with: cargo install --git https://github.com/blueshift-gg/sbpf-linker.git"
    fi
fi

# Step 3: Check program exists
echo ""
echo -e "${YELLOW}Step 3: Checking program binary...${NC}"

if [ ! -f "${PROGRAM_SO}" ]; then
    echo -e "${RED}Error: Program not found at ${PROGRAM_SO}${NC}"
    echo "Run: zig build bpf && zig build link"
    exit 1
fi

echo -e "${GREEN}  Program: ${PROGRAM_SO}${NC}"
echo -e "${GREEN}  Size: $(ls -lh "${PROGRAM_SO}" | awk '{print $5}')${NC}"

# Step 4: Check local validator
if [ "$SKIP_VALIDATOR" = false ]; then
    echo ""
    echo -e "${YELLOW}Step 4: Checking local validator...${NC}"
    
    if ! solana cluster-version &> /dev/null; then
        echo -e "${BLUE}  Starting local validator...${NC}"
        echo "  Run in separate terminal: solana-test-validator"
        echo ""
        echo "  Waiting for validator to start..."
        
        # Wait for validator with timeout
        TIMEOUT=30
        COUNTER=0
        while ! solana cluster-version &> /dev/null; do
            sleep 1
            COUNTER=$((COUNTER + 1))
            if [ $COUNTER -ge $TIMEOUT ]; then
                echo -e "${RED}Error: Validator did not start within ${TIMEOUT}s${NC}"
                echo "Please start manually: solana-test-validator"
                exit 1
            fi
            echo -n "."
        done
        echo ""
    fi
    
    echo -e "${GREEN}  Validator: $(solana cluster-version)${NC}"
fi

# Step 5: Configure for localhost
echo ""
echo -e "${YELLOW}Step 5: Configuring for localhost...${NC}"
solana config set --url localhost > /dev/null 2>&1
echo -e "${GREEN}  RPC URL: $(solana config get | grep 'RPC URL' | awk '{print $3}')${NC}"

# Step 6: Check/create keypair
echo ""
echo -e "${YELLOW}Step 6: Checking keypair...${NC}"

if [ ! -f "${KEYPAIR_FILE}" ]; then
    echo -e "${BLUE}  Creating new keypair...${NC}"
    solana-keygen new --no-bip39-passphrase -o "${KEYPAIR_FILE}" > /dev/null 2>&1
fi

WALLET_ADDRESS=$(solana address)
echo -e "${GREEN}  Wallet: ${WALLET_ADDRESS}${NC}"

# Step 7: Airdrop SOL
echo ""
echo -e "${YELLOW}Step 7: Checking balance...${NC}"

BALANCE=$(solana balance | awk '{print $1}')
echo -e "${BLUE}  Current balance: ${BALANCE} SOL${NC}"

if (( $(echo "$BALANCE < 1" | bc -l) )); then
    echo -e "${BLUE}  Requesting airdrop...${NC}"
    solana airdrop 2 > /dev/null 2>&1 || true
    sleep 2
    BALANCE=$(solana balance | awk '{print $1}')
    echo -e "${GREEN}  New balance: ${BALANCE} SOL${NC}"
fi

# Step 8: Deploy program
echo ""
echo -e "${YELLOW}Step 8: Deploying program...${NC}"

DEPLOY_OUTPUT=$(solana program deploy "${PROGRAM_SO}" 2>&1)

if echo "${DEPLOY_OUTPUT}" | grep -q "Program Id"; then
    PROGRAM_ID=$(echo "${DEPLOY_OUTPUT}" | grep "Program Id" | awk '{print $3}')
    echo "${PROGRAM_ID}" > "${PROGRAM_ID_FILE}"
    
    echo ""
    echo -e "${GREEN}=== Deployment Successful ===${NC}"
    echo -e "${GREEN}Program ID: ${PROGRAM_ID}${NC}"
    echo ""
    echo "Program ID saved to: ${PROGRAM_ID_FILE}"
    echo ""
    echo "Next steps:"
    echo "  1. View logs: solana logs ${PROGRAM_ID}"
    echo "  2. Invoke program: ./scripts/invoke.sh"
else
    echo -e "${RED}Deployment failed:${NC}"
    echo "${DEPLOY_OUTPUT}"
    exit 1
fi
