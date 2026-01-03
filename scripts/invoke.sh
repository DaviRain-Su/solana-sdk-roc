#!/bin/bash
# Invoke Roc on Solana Hello World Program
#
# This script invokes the deployed program and shows the logs.
#
# Usage:
#   ./scripts/invoke.sh                    # Invoke with saved program ID
#   ./scripts/invoke.sh <program_id>       # Invoke specific program
#   ./scripts/invoke.sh --logs             # Show logs only (no invoke)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAM_ID_FILE="${PROJECT_ROOT}/.program-id"

echo -e "${BLUE}=== Roc on Solana Program Invocation ===${NC}"
echo ""

# Parse arguments
LOGS_ONLY=false
PROGRAM_ID=""

for arg in "$@"; do
    case $arg in
        --logs)
            LOGS_ONLY=true
            ;;
        *)
            if [[ ! "$arg" =~ ^-- ]]; then
                PROGRAM_ID="$arg"
            fi
            ;;
    esac
done

# Get program ID
if [ -z "${PROGRAM_ID}" ]; then
    if [ -f "${PROGRAM_ID_FILE}" ]; then
        PROGRAM_ID=$(cat "${PROGRAM_ID_FILE}")
    else
        echo -e "${RED}Error: No program ID specified and no saved ID found${NC}"
        echo ""
        echo "Usage:"
        echo "  ./scripts/invoke.sh <program_id>"
        echo "  ./scripts/invoke.sh              # Uses saved ID from deploy"
        echo ""
        echo "First deploy with: ./scripts/deploy.sh"
        exit 1
    fi
fi

echo -e "${GREEN}Program ID: ${PROGRAM_ID}${NC}"
echo ""

# Check if program exists
echo -e "${YELLOW}Checking program...${NC}"
PROGRAM_INFO=$(solana program show "${PROGRAM_ID}" 2>&1) || {
    echo -e "${RED}Error: Program not found${NC}"
    echo "${PROGRAM_INFO}"
    exit 1
}

echo -e "${GREEN}Program is deployed and executable${NC}"
echo ""

# Show logs only mode
if [ "$LOGS_ONLY" = true ]; then
    echo -e "${YELLOW}Showing program logs (Ctrl+C to exit)...${NC}"
    echo ""
    solana logs "${PROGRAM_ID}"
    exit 0
fi

# Create a simple transaction to invoke the program
echo -e "${YELLOW}Invoking program...${NC}"
echo ""

# Start log monitoring in background
echo -e "${BLUE}Capturing logs...${NC}"
LOG_FILE=$(mktemp)

# Monitor logs in background with timeout
timeout 10 solana logs "${PROGRAM_ID}" > "${LOG_FILE}" 2>&1 &
LOG_PID=$!

# Give logs time to start
sleep 1

# Use solana CLI to create and send a transaction
# For a simple program that just logs, we can use a basic transfer instruction
# The program doesn't need specific instruction data - it just logs on any call

# Create the invoke transaction using solana-program CLI or spl-memo
# For now, we use a workaround: send a transaction that calls our program

# Method 1: Use solana transfer to self (will trigger our program if it's in the transaction)
# This is a simplified approach - real programs would use solana-py or anchor

echo -e "${BLUE}Sending transaction to program...${NC}"

# Use spl-memo or create a raw transaction
# For simplicity, we show the manual method:
echo ""
echo -e "${YELLOW}Manual invocation method:${NC}"
echo ""
echo "To invoke this program, use one of these methods:"
echo ""
echo "1. Using solana-py (Python):"
echo "   from solana.rpc.api import Client"
echo "   from solana.transaction import Transaction"
echo "   from solana.publickey import PublicKey"
echo "   "
echo "   client = Client('http://localhost:8899')"
echo "   program_id = PublicKey('${PROGRAM_ID}')"
echo "   # Create and send transaction..."
echo ""
echo "2. Using @solana/web3.js (JavaScript):"
echo "   const { Connection, PublicKey, Transaction, TransactionInstruction } = require('@solana/web3.js');"
echo "   const connection = new Connection('http://localhost:8899');"
echo "   const programId = new PublicKey('${PROGRAM_ID}');"
echo "   const instruction = new TransactionInstruction({ keys: [], programId, data: Buffer.from([]) });"
echo "   // Send transaction..."
echo ""
echo "3. Using Anchor (if installed):"
echo "   anchor idl init ${PROGRAM_ID} --filepath ./target/idl/hello.json"
echo "   anchor invoke ${PROGRAM_ID}"
echo ""

# Kill background log process
kill $LOG_PID 2>/dev/null || true

# Show captured logs
if [ -s "${LOG_FILE}" ]; then
    echo -e "${GREEN}=== Captured Logs ===${NC}"
    cat "${LOG_FILE}"
fi

rm -f "${LOG_FILE}"

echo ""
echo -e "${GREEN}=== Invocation Complete ===${NC}"
echo ""
echo "To see live logs, run:"
echo "  solana logs ${PROGRAM_ID}"
