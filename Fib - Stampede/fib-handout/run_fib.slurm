#!/bin/bash

# run_fib.slurm - Remote job script executed by Tapis on Stampede

set -euo pipefail

# Decode FIB_SOURCE_B64 environment variable to fib.c
if [ -z "${FIB_SOURCE_B64:-}" ]; then
    echo "Error: FIB_SOURCE_B64 not set" >&2
    exit 1
fi

printf '%s' "$FIB_SOURCE_B64" | base64 -d > fib.c

# Compile fib with fallback: try $WORK/opencilk/bin/clang, then system clang/gcc
if [ -x "$WORK/opencilk/bin/clang" ]; then
    $WORK/opencilk/bin/clang -fopencilk fib.c -o fib
elif command -v clang >/dev/null 2>&1; then
    clang -fopencilk fib.c -o fib
else
    gcc -O2 fib.c -o fib  # Fallback to GCC (no cilk support, but compiles)
fi

# Run and time the program
start_ns=$(date +%s%N)
fib_output=$(./fib 20)
end_ns=$(date +%s%N)
elapsed=$(awk "BEGIN {printf \"%.6f\", ($end_ns-$start_ns)/1000000000}")

# Print to stdout (goes into tapisjob.out; faster to retrieve via /logs endpoint)
printf "fib_output=%s\n" "$fib_output"
printf "elapsed=%s\n" "$elapsed"

# Clean up build artifacts to reduce archive size (speeds job completion)
rm -f fib.c
rm -f fib

exit 0
