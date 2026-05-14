#!/usr/bin/env bash

# driver.sh - Thin Tapis grader wrapper for Autolab

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$DOTENV_FILE" ]; then
    set -a
    . "$DOTENV_FILE"
    set +a
fi

source "${SCRIPT_DIR}/tapis.sh"
source "${SCRIPT_DIR}/assignment.sh"

assignment_main

