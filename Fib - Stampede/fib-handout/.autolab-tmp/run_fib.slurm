#!/bin/bash
#SBATCH -J autolab-fib
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:02:00
#SBATCH --output=job.log



set -euo pipefail

if [ -x $WORK/opencilk/bin/clang ]; then
  $WORK/opencilk/bin/clang -fopencilk fib.c -o fib
else
  clang -fopencilk fib.c -o fib
fi

start_ns=$(date +%s%N)
fib_output=$(./fib 20)
end_ns=$(date +%s%N)
elapsed=$(awk "BEGIN {printf \"%.6f\", ($end_ns-$start_ns)/1000000000}")

printf "fib_output=%s\n" "$fib_output" > result.txt
printf "elapsed=%s\n" "$elapsed" >> result.txt
