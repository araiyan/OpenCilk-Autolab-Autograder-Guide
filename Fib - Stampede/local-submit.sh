#!/bin/bash

# local-submit.sh - Local helper to run the same Tapis grading path as Autolab.
# Usage: ./local-submit.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HANDOUT_DIR="${SCRIPT_DIR}/fib-handout"
SOURCE_FIB="${SCRIPT_DIR}/fib.c"
DEST_FIB="${HANDOUT_DIR}/fib.c"

if [ ! -f "$SOURCE_FIB" ]; then
    echo "Failure: Missing source file at $SOURCE_FIB"
    exit 1
fi

if [ ! -d "$HANDOUT_DIR" ]; then
    echo "Failure: Missing handout directory at $HANDOUT_DIR"
    exit 1
fi

cp "$SOURCE_FIB" "$DEST_FIB"

if [ -z "${TAPIS_ACCESS_TOKEN:-}" ]; then
    token_fetched=0
    token_out=""
    rc=1

    if [ -f "${SCRIPT_DIR}/get-tapis-token.py" ]; then
        set +e
        if [ -f "/mnt/c/Users/Raiya/AppData/Local/Programs/Python/Python313/python.exe" ]; then
            script_path_windows=$(printf '%s\n' "$SCRIPT_DIR" | sed 's|^/mnt/c/|C:/|' | tr '/' '\\')
            token_out=$("/mnt/c/Users/Raiya/AppData/Local/Programs/Python/Python313/python.exe" "${script_path_windows}\\get-tapis-token.py" </dev/tty 2>&1)
            rc=$?
        elif command -v python >/dev/null 2>&1; then
            token_out=$(python "${SCRIPT_DIR}/get-tapis-token.py" </dev/tty 2>&1)
            rc=$?
        elif command -v python3 >/dev/null 2>&1; then
            token_out=$(python3 "${SCRIPT_DIR}/get-tapis-token.py" </dev/tty 2>&1)
            rc=$?
        fi
        set -e

        if [ $rc -eq 0 ]; then
            TAPIS_ACCESS_TOKEN=$(echo "$token_out" | awk -F': ' '/^access_token:/ {print $2; exit}' | tr -d '\r')
            if [ -n "${TAPIS_ACCESS_TOKEN}" ]; then
                export TAPIS_ACCESS_TOKEN
                token_fetched=1
                echo "Successfully fetched token via tapipy"
            fi
        fi
    fi

    if [ $token_fetched -eq 0 ] && command -v tapis >/dev/null 2>&1; then
        echo "Trying tapis CLI..."
        set +e
        TAPIS_ACCESS_TOKEN=$(tapis tokens create --quiet 2>/dev/null || true)
        rc=$?
        set -e
        if [ $rc -eq 0 ] && [ -n "${TAPIS_ACCESS_TOKEN}" ]; then
            export TAPIS_ACCESS_TOKEN
            token_fetched=1
            echo "Successfully fetched token via tapis CLI"
        fi
    fi

    if [ $token_fetched -eq 0 ]; then
        echo "Error: Failed to fetch TAPIS token"
        if [ -n "$token_out" ]; then
            echo "Output: $token_out"
        fi
        echo ""
        echo "To fix this, set your TACC credentials before running:"
        echo "  export TAPIS_USERNAME='your_tacc_username'"
        echo "  export TAPIS_PASSWORD='your_tacc_password'"
        echo "  bash ./local-submit.sh"
        echo ""
        echo "Or provide the token directly:"
        echo "  export TAPIS_ACCESS_TOKEN='your_token_here'"
        echo "  bash ./local-submit.sh"
        exit 1
    fi
fi

# Default to the currently registered Stampede3 app unless overridden by env.
TAPIS_APP_ID="${TAPIS_APP_ID:-fibonacci-fork-app}"
TAPIS_APP_VERSION="${TAPIS_APP_VERSION:-1.0.1}"
FIB_INPUT="${FIB_INPUT:-20}"
export TAPIS_APP_ID TAPIS_APP_VERSION FIB_INPUT

echo "Using Tapis app: ${TAPIS_APP_ID} (version: ${TAPIS_APP_VERSION})"

echo "Running local submission test via fib-handout/driver.sh"
(
    cd "$HANDOUT_DIR"
    bash ./driver.sh
)