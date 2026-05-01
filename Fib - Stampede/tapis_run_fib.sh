#!/bin/bash
set -euo pipefail

# Prefer OpenCilk clang under $WORK unless overridden.
cc_default=""
if [ -n "${WORK:-}" ]; then
	cc_default="${WORK}/opencilk/bin/clang"
fi
cc="${TAPIS_CILK_CC:-$cc_default}"
require_opencilk="${TAPIS_REQUIRE_OPENCILK_CC:-1}"

if [ -z "$cc" ] || [ ! -x "$cc" ]; then
	if command -v clang >/dev/null 2>&1; then
		cc="$(command -v clang)"
	elif command -v gcc >/dev/null 2>&1; then
		cc="$(command -v gcc)"
	else
		cc=""
	fi
fi

echo "fib_cc_selected=${cc:-none}"

if [ "$require_opencilk" = "1" ]; then
	if [ -z "$cc_default" ] || [ ! -x "$cc_default" ]; then
		echo "fib_cc_required_path_missing=${cc_default:-unset}"
		exit 1
	fi
	cc="$cc_default"
	echo "fib_cc_enforced=$cc"
fi

if [ -z "$cc" ]; then
	echo "Failure: no compiler found for fib build"
	exit 1
fi

echo "fib_cc_path=$cc"
"$cc" --version 2>/dev/null | head -n 1 | sed 's/^/fib_cc_version=/' || true

echo "$FIB_SOURCE_B64" | base64 -d > fib.c
"$cc" -O2 -fopencilk fib.c -o fib

start=$(date +%s.%N)
out=$(./fib "${FIB_INPUT:-20}")
end=$(date +%s.%N)
elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN {printf "%.6f", e-s}')

echo "fib_output=$out"
echo "elapsed=$elapsed"
