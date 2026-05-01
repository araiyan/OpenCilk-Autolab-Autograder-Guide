#!/bin/bash

# driver.sh - The simplest autograder we could think of. It checks
#   that students can write a C program that compiles, and then
#   executes with an exit status of zero.
#   Usage: ./driver.sh

# Function to calculate performance score dynamically
# Uses: score = 100 / (1 + elapsed_time)
# This penalizes slower solutions smoothly and naturally
calculate_performance_score() {
    local elapsed=$1
    local score=$(echo "scale=1; 100 / (1 + $elapsed)" | bc -l)
    echo "$score"
}

# Compile the code
echo "Compiling fib.c"
(make clean; make)
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failure: Unable to compile fib.c (return status = ${status})"
    echo "{\"scores\": {\"Correctness\": 0, \"Performance\": 0}}"
    exit
fi

# Run the code and measure performance
echo "Running ./fib 20"
start_time=$(date +%s%N)
output=$(./fib 20)
end_time=$(date +%s%N)
status=$?
elapsed=$(echo "scale=6; ($end_time - $start_time) / 1000000000" | bc -l)

if [ ${status} -ne 0 ]; then
    echo "Failure: ./fib fails or returns nonzero exit status of ${status}"
    echo "{\"scores\": {\"Correctness\": 0, \"Performance\": 0}}"
    exit
fi

echo "Output from ./fib 20: $output"
echo "Execution time: ${elapsed} seconds"

# Check if output matches the expected format: fib(20)=<number>
if echo "$output" | grep -qE '^fib\(20\)=[0-9]+$'; then
    correctness=100
    echo "Success: Output matches expected format: $output"
else
    correctness=0
    echo "Failure: Output does not match expected format 'fib(20)=<number>'"
    echo "  Expected format: fib(20)=<number>"
    echo "  Actual output: $output"
fi

# Calculate performance score
performance=$(calculate_performance_score "$elapsed")

echo "{\"scores\": {\"Correctness\": ${correctness}, \"Performance\": ${performance}}}"

exit

