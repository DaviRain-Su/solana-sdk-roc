#!/bin/bash
# Build Solana program using solana-zig
# This script uses the correct linker options for SBF target

set -e

SOLANA_ZIG="./solana-zig/zig"
OUTPUT_DIR="zig-out/lib"
PROGRAM_NAME="roc-hello"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create BPF linker script
cat > "$OUTPUT_DIR/bpf.ld" << 'LDSCRIPT'
PHDRS
{
text PT_LOAD  ;
rodata PT_LOAD ;
data PT_LOAD ;
dynamic PT_DYNAMIC ;
}

SECTIONS
{
. = SIZEOF_HEADERS;
.text : { *(.text*) } :text
.rodata : { *(.rodata*) } :rodata
.data.rel.ro : { *(.data.rel.ro*) } :rodata
.dynamic : { *(.dynamic) } :dynamic
.dynsym : { *(.dynsym) } :data
.dynstr : { *(.dynstr) } :data
.rel.dyn : { *(.rel.dyn) } :data
/DISCARD/ : {
*(.eh_frame*)
*(.gnu.hash*)
*(.hash*)
}
}
LDSCRIPT

# Get SDK path
SDK_PATH="vendor/solana-program-sdk-zig/src/root.zig"
BASE58_PATH=$(find ~/.cache/zig -name "root.zig" -path "*base58*" 2>/dev/null | head -1)

if [ -z "$BASE58_PATH" ]; then
    echo "Error: base58 module not found. Run 'zig build test' first to fetch dependencies."
    exit 1
fi

echo "Building Solana program..."
echo "SDK: $SDK_PATH"
echo "Base58: $BASE58_PATH"

# Build with solana-zig
$SOLANA_ZIG build-lib \
    -target sbf-solana \
    -O ReleaseSmall \
    -dynamic \
    --dep solana_sdk \
    --dep base58 \
    -Mroot=src/host.zig \
    -Msolana_sdk="$SDK_PATH" \
    -Mbase58="$BASE58_PATH" \
    -T "$OUTPUT_DIR/bpf.ld" \
    -fentry=entrypoint \
    -z notext \
    -femit-bin="$OUTPUT_DIR/$PROGRAM_NAME.so"

echo "Build complete: $OUTPUT_DIR/$PROGRAM_NAME.so"
ls -la "$OUTPUT_DIR/$PROGRAM_NAME.so"
