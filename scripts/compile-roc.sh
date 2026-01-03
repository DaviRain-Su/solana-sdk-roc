#!/bin/bash
set -e

ROC_APP="$1"
OUTPUT="$2"

if [ -z "$ROC_APP" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 <roc_app.roc> <output.o>"
    exit 1
fi

ROC="${ROC:-$(ls -d /tmp/roc_nightly*/roc 2>/dev/null | head -1)}"
if [ ! -x "$ROC" ]; then
    echo "Error: Roc compiler not found. Set ROC environment variable."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

APP_DIR=$(dirname "$ROC_APP")
APP_NAME=$(basename "$ROC_APP" .roc)
ROC_LL="$APP_DIR/$APP_NAME.ll"

echo "Step 1: Compiling Roc to LLVM IR..."
$ROC build --emit-llvm-ir --no-link --output "$TMPDIR/app_obj" "$ROC_APP"

echo "Step 2: Optimizing LLVM IR..."
opt-18 "$ROC_LL" -O2 -S -o "$TMPDIR/app_opt.ll"

echo "Step 3: Converting to BPF target..."
sed -e 's|target datalayout = .*|target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128"|' \
    -e 's|target triple = .*|target triple = "bpfel-unknown-unknown"|' \
    "$TMPDIR/app_opt.ll" > "$TMPDIR/app_target.ll"

echo "Step 4: Extracting BPF-compatible functions..."
awk '
BEGIN { keep = 0; in_func = 0 }
/^define.*@roc__main_for_host_1_exposed_generic/ { keep = 1; in_func = 1 }
/^define.*@roc__main_for_host_1_exposed_size/ { keep = 1; in_func = 1 }
/^define/ && !keep { in_func = 1; next }
in_func && /^}$/ { if (keep) { print; keep = 0 }; in_func = 0; next }
in_func && !keep { next }
{ print }
' "$TMPDIR/app_target.ll" > "$TMPDIR/app_bpf.ll"

echo "Step 5: Compiling to BPF object..."
llc-18 "$TMPDIR/app_bpf.ll" -march=bpfel -filetype=obj -o "$OUTPUT"

echo "Done: $OUTPUT"
file "$OUTPUT"
