#!/bin/bash

# driver.sh - Autolab grader using Tapis Jobs API.
# Expects a preconfigured Tapis app that can compile/run fib.c from
# FIB_SOURCE_B64 and print:
#   fib_output=fib(20)=<number>
#   elapsed=<seconds>

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$DOTENV_FILE" ]; then
    set -a
    . "$DOTENV_FILE"
    set +a
fi

strip_carriage_returns() {
    printf '%s' "$1" | tr -d '\r'
}

# Uses: score = 100 / (1 + elapsed_time)
calculate_performance_score() {
    local elapsed=$1
    local score
    score=$(awk -v e="$elapsed" 'BEGIN { printf "%.1f", 100 / (1 + e) }')
    echo "$score"
}

fail_with_zero_scores() {
    local message=$1
    echo "Failure: ${message}"
    echo "{\"scores\": {\"Correctness\": 0, \"Performance\": 0}}"
    exit 0
}

require_command() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail_with_zero_scores "Required command '$cmd' not found"
    fi
}

have_command() {
    command -v "$1" >/dev/null 2>&1
}

detect_python_bin() {
    local windows_python="/mnt/c/Users/Raiya/AppData/Local/Programs/Python/Python313/python.exe"

    if [ -x "$windows_python" ]; then
        echo "$windows_python"
        return 0
    fi

    if have_command py; then
        echo "py"
        return 0
    fi

    if have_command python; then
        echo "python"
        return 0
    fi

    if have_command python3; then
        echo "python3"
        return 0
    fi

    return 1
}

fetch_tapis_access_token() {
    local script_dir
    local token_out=""
    local rc=1
    local pybin=""
    local token_helper=""

    script_dir="$SCRIPT_DIR"

    if [ -f "$./get-tapis-token.py" ]; then
        token_helper="$./get-tapis-token.py"
    elif [ -f "${script_dir}/get-tapis-token.py" ]; then
        token_helper="${script_dir}/get-tapis-token.py"
    fi

    pybin=$(detect_python_bin || true)

    if [ -z "$pybin" ]; then
        pybin=""
    fi

    if [ -n "$token_helper" ] && [ -n "$pybin" ] && [ -n "${TAPIS_USERNAME:-}" ] && [ -n "${TAPIS_PASSWORD:-}" ]; then
        token_helper_arg="$token_helper"
        set +e
        token_out=$("$pybin" "$token_helper_arg" 2>&1)
        rc=$?
        set -e

        if [ $rc -eq 0 ]; then
            TAPIS_ACCESS_TOKEN=$(echo "$token_out" | awk -F': ' '/^access_token:/ {print $2; exit}' | tr -d '\r')
            if [ -n "${TAPIS_ACCESS_TOKEN}" ]; then
                export TAPIS_ACCESS_TOKEN
                echo "Successfully fetched token via tapipy"
                return 0
            fi
        fi
    fi

    if [ $rc -ne 0 ] && [ -n "$token_out" ]; then
        echo "$token_out"
    fi

    if command -v tapis >/dev/null 2>&1; then
        echo "Trying tapis CLI..."
        set +e
        TAPIS_ACCESS_TOKEN=$(tapis tokens create --quiet 2>/dev/null || true)
        rc=$?
        set -e
        if [ $rc -eq 0 ] && [ -n "${TAPIS_ACCESS_TOKEN}" ]; then
            export TAPIS_ACCESS_TOKEN
            echo "Successfully fetched token via tapis CLI"
            return 0
        fi
    fi

    if [ -n "$pybin" ] && [ -n "${TAPIS_USERNAME:-}" ] && [ -n "${TAPIS_PASSWORD:-}" ]; then
        set +e
        TAPIS_ACCESS_TOKEN=$(TAPIS_BASE_URL="$TAPIS_BASE_URL" TAPIS_USERNAME="$TAPIS_USERNAME" TAPIS_PASSWORD="$TAPIS_PASSWORD" "$pybin" - <<'PY'
import os
import subprocess
import sys

try:
    from tapipy.tapis import Tapis
except ImportError:
    print("Error: tapipy not installed. Install with: pip install tapipy", file=sys.stderr)
    print("Attempting to install tapipy...", file=sys.stderr)
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "tapipy", "-q"])
        from tapipy.tapis import Tapis
        print("Successfully installed tapipy", file=sys.stderr)
    except Exception as install_err:
        print(f"Failed to auto-install tapipy: {install_err}", file=sys.stderr)
        raise SystemExit(1)

tenant_url = os.environ.get("TAPIS_BASE_URL", "https://tacc.tapis.io")
username = os.environ.get("TAPIS_USERNAME", "").strip()
password = os.environ.get("TAPIS_PASSWORD", "").strip()

if not username or not password:
    print("Error: Username and password are required", file=sys.stderr)
    raise SystemExit(1)

try:
    t = Tapis(base_url=tenant_url, username=username, password=password)
    t.get_tokens()
    print(t.access_token.access_token)
except Exception as exc:
    print(f"Error: Authentication failed: {exc}", file=sys.stderr)
    raise SystemExit(1)
PY
)
        rc=$?
        set -e
        if [ $rc -eq 0 ] && [ -n "${TAPIS_ACCESS_TOKEN}" ]; then
            export TAPIS_ACCESS_TOKEN
            echo "Successfully fetched token via tapipy"
            return 0
        fi
    fi

    if [ -n "${TAPIS_ACCESS_TOKEN:-}" ]; then
        return 0
    fi

    return 1
}

require_command curl
require_command awk
require_command base64
require_command grep
require_command sed

JSON_ENGINE=""
PYTHON_BIN=""

if have_command jq; then
    JSON_ENGINE="jq"
elif have_command python || have_command py; then
    JSON_ENGINE="python"
    PYTHON_BIN=$(detect_python_bin || true)
elif have_command python3; then
    JSON_ENGINE="python"
    PYTHON_BIN="python3"
else
    fail_with_zero_scores "Need either 'jq' or 'python3/python' for JSON handling"
fi

TAPIS_BASE_URL=${TAPIS_BASE_URL:-https://tacc.tapis.io}
TAPIS_ACCESS_TOKEN=${TAPIS_ACCESS_TOKEN:-}
TAPIS_APP_ID=${TAPIS_APP_ID:-fibonacci-fork-app}
TAPIS_APP_VERSION=${TAPIS_APP_VERSION:-1.0.1}
TAPIS_JOB_TIMEOUT_SECONDS=${TAPIS_JOB_TIMEOUT_SECONDS:-300}
TAPIS_POLL_INTERVAL_SECONDS=${TAPIS_POLL_INTERVAL_SECONDS:-5}
FIB_INPUT=${FIB_INPUT:-20}

STAMPEDE_PARTITION=${STAMPEDE_PARTITION:-}
STAMPEDE_ACCOUNT=${STAMPEDE_ACCOUNT:-}

TAPIS_BASE_URL=$(strip_carriage_returns "$TAPIS_BASE_URL")
TAPIS_ACCESS_TOKEN=$(strip_carriage_returns "$TAPIS_ACCESS_TOKEN")
TAPIS_APP_ID=$(strip_carriage_returns "$TAPIS_APP_ID")
TAPIS_APP_VERSION=$(strip_carriage_returns "$TAPIS_APP_VERSION")
TAPIS_JOB_TIMEOUT_SECONDS=$(strip_carriage_returns "$TAPIS_JOB_TIMEOUT_SECONDS")
TAPIS_POLL_INTERVAL_SECONDS=$(strip_carriage_returns "$TAPIS_POLL_INTERVAL_SECONDS")
FIB_INPUT=$(strip_carriage_returns "$FIB_INPUT")
STAMPEDE_PARTITION=$(strip_carriage_returns "$STAMPEDE_PARTITION")
STAMPEDE_ACCOUNT=$(strip_carriage_returns "$STAMPEDE_ACCOUNT")

export TAPIS_BASE_URL TAPIS_ACCESS_TOKEN TAPIS_APP_ID TAPIS_APP_VERSION TAPIS_JOB_TIMEOUT_SECONDS TAPIS_POLL_INTERVAL_SECONDS FIB_INPUT STAMPEDE_PARTITION STAMPEDE_ACCOUNT

if ! fetch_tapis_access_token; then
    fail_with_zero_scores "Set TAPIS_ACCESS_TOKEN or TAPIS_USERNAME/TAPIS_PASSWORD for Tapis API authentication"
fi

if [ ! -f "fib.c" ]; then
    fail_with_zero_scores "fib.c not found in working directory"
fi

if ! [[ "$TAPIS_JOB_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [ "$TAPIS_JOB_TIMEOUT_SECONDS" -le 0 ]; then
    fail_with_zero_scores "TAPIS_JOB_TIMEOUT_SECONDS must be a positive integer"
fi

if ! [[ "$TAPIS_POLL_INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [ "$TAPIS_POLL_INTERVAL_SECONDS" -le 0 ]; then
    fail_with_zero_scores "TAPIS_POLL_INTERVAL_SECONDS must be a positive integer"
fi

json_build_submit_payload() {
    if [ "$JSON_ENGINE" = "jq" ]; then
        jq -n \
            --arg name "$JOB_NAME" \
            --arg appId "$TAPIS_APP_ID" \
            --arg appVersion "$TAPIS_APP_VERSION" \
            --arg fibSource "$FIB_SOURCE_B64" \
            --arg fibInput "$FIB_INPUT" \
            --arg partition "$STAMPEDE_PARTITION" \
            --arg account "$STAMPEDE_ACCOUNT" \
            '{
                name: $name,
                appId: $appId,
                maxMinutes: 5,
                parameterSet: {
                    envVariables: [
                        {key: "FIB_SOURCE_B64", value: $fibSource},
                        {key: "FIB_INPUT", value: $fibInput}
                    ]
                }
            }
            | if ($appVersion | length) > 0 then .appVersion = $appVersion else . end
            | if ($partition | length) > 0 then
                  .parameterSet.envVariables += [{key: "STAMPEDE_PARTITION", value: $partition}]
              else . end
            | if ($account | length) > 0 then
                  .parameterSet.envVariables += [{key: "STAMPEDE_ACCOUNT", value: $account}]
              else . end'
    else
        "$PYTHON_BIN" - <<'PY'
import json
import os

payload = {
    "name": os.environ["JOB_NAME"],
    "appId": os.environ["TAPIS_APP_ID"],
    "maxMinutes": 5,
    "parameterSet": {
        "envVariables": [
            {"key": "FIB_SOURCE_B64", "value": os.environ["FIB_SOURCE_B64"]},
            {"key": "FIB_INPUT", "value": os.environ["FIB_INPUT"]},
        ]
    },
}

app_version = os.environ.get("TAPIS_APP_VERSION", "")
partition = os.environ.get("STAMPEDE_PARTITION", "")
account = os.environ.get("STAMPEDE_ACCOUNT", "")

if app_version:
    payload["appVersion"] = app_version
if partition:
    payload["parameterSet"]["envVariables"].append({"key": "STAMPEDE_PARTITION", "value": partition})
if account:
    payload["parameterSet"]["envVariables"].append({"key": "STAMPEDE_ACCOUNT", "value": account})

print(json.dumps(payload, separators=(",", ":")))
PY
    fi
}

json_get_job_id() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.uuid // .result.id // empty'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c 'import json, os, sys; s=(os.environ.get("JSON_INPUT") or "").strip();
if not s:
    print("")
    sys.exit(0)
try:
    obj=json.loads(s)
except Exception:
    print("")
    sys.exit(0)
r=obj.get("result") or {}
print(r.get("uuid") or r.get("id") or "")'
    fi
}

json_get_status() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.status // ""'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c 'import json, os, sys; s=(os.environ.get("JSON_INPUT") or "").strip();
if not s:
    print("")
    sys.exit(0)
try:
    obj=json.loads(s)
except Exception:
    print("")
    sys.exit(0)
r=obj.get("result") or {}
print(r.get("status") or "")'
    fi
}

json_get_logs() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.logs // .result // ""'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c 'import json, os, sys; s=(os.environ.get("JSON_INPUT") or "").strip();
if not s:
    print("")
    sys.exit(0)
try:
    obj=json.loads(s)
except Exception:
    print("")
    sys.exit(0)
r=obj.get("result")
print((r.get("logs") if isinstance(r, dict) else r) or "")'
    fi
}

api_call_json() {
    local method=$1
    local endpoint=$2
    local payload=${3:-}
    local tmp
    local http_code
    tmp=$(mktemp)

    if [ -n "$payload" ]; then
        http_code=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
            -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
            -H "Content-Type: application/json" \
            "$TAPIS_BASE_URL$endpoint" \
            -d "$payload") || {
            rm -f "$tmp"
            fail_with_zero_scores "Tapis API request failed for $endpoint"
        }
    else
        http_code=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
            -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
            "$TAPIS_BASE_URL$endpoint") || {
            rm -f "$tmp"
            fail_with_zero_scores "Tapis API request failed for $endpoint"
        }
    fi

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        echo "Tapis API error for $endpoint (HTTP $http_code):"
        cat "$tmp"
        rm -f "$tmp"
        fail_with_zero_scores "Tapis API returned non-success status"
    fi

    cat "$tmp"
    rm -f "$tmp"
}

download_job_stdout_from_archive() {
    local job_id=$1
    local tmp_zip
    local http_code
    local pybin="${PYTHON_BIN:-}"

    if [ -z "$pybin" ]; then
        if command -v python3 >/dev/null 2>&1; then
            pybin="python3"
        elif command -v python >/dev/null 2>&1; then
            pybin="python"
        else
            echo ""
            return 0
        fi
    fi

    tmp_zip=$(mktemp)
    http_code=$(curl -sS -o "$tmp_zip" -w "%{http_code}" -X GET \
        -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
        -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
        "$TAPIS_BASE_URL/v3/jobs/${job_id}/output/download//") || {
        rm -f "$tmp_zip"
        echo ""
        return 0
    }

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        rm -f "$tmp_zip"
        echo ""
        return 0
    fi

    ZIP_PATH="$tmp_zip" "$pybin" - <<'PY'
import os
import zipfile

zip_path = os.environ.get("ZIP_PATH", "")
if not zip_path:
    print("")
    raise SystemExit(0)

try:
    with zipfile.ZipFile(zip_path) as zf:
        target = "tapisjob.out"
        if target not in zf.namelist():
            out_files = [n for n in zf.namelist() if n.endswith('.out')]
            if not out_files:
                print("")
                raise SystemExit(0)
            target = out_files[0]
        print(zf.read(target).decode("utf-8", errors="replace"))
except Exception:
    print("")
PY

    rm -f "$tmp_zip"
}

echo "Encoding submission source for Tapis job"
FIB_SOURCE_B64=$(base64 < fib.c | tr -d '\n')
JOB_NAME="autolab-fib-$(date +%s)-$$"
export FIB_SOURCE_B64 JOB_NAME

SUBMIT_PAYLOAD=$(json_build_submit_payload)

echo "Submitting Tapis job"
SUBMIT_RESPONSE=$(api_call_json POST "/v3/jobs/submit" "$SUBMIT_PAYLOAD")
JOB_ID=$(json_get_job_id "$SUBMIT_RESPONSE")

if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
    echo "Unexpected submit response:"
    echo "$SUBMIT_RESPONSE"
    fail_with_zero_scores "Could not parse Tapis job id"
fi

echo "Submitted Tapis job: $JOB_ID"
echo "Polling job status"

deadline=$(( $(date +%s) + TAPIS_JOB_TIMEOUT_SECONDS ))
status=""

while :; do
    JOB_RESPONSE=$(api_call_json GET "/v3/jobs/${JOB_ID}")
    status=$(json_get_status "$JOB_RESPONSE")

    if [ -n "$status" ]; then
        echo "Job status: $status"
    fi

    case "$status" in
        FINISHED)
            break
            ;;
        FAILED|CANCELLED|BLOCKED)
            LOG_RESPONSE=$(api_call_json GET "/v3/jobs/${JOB_ID}/logs" || true)
            HISTORY_RESPONSE=$(api_call_json GET "/v3/jobs/${JOB_ID}/history" || true)
            echo "Tapis job logs:"
            LOG_TEXT=$(json_get_logs "$LOG_RESPONSE")
            if [ -n "$LOG_TEXT" ]; then
                echo "$LOG_TEXT"
            else
                echo "(no logs returned)"
                echo "Tapis job details response:"
                echo "$JOB_RESPONSE"
            fi
            echo "Tapis job history response:"
            echo "$HISTORY_RESPONSE"
            fail_with_zero_scores "Tapis job ended with status $status"
            ;;
    esac

    if [ "$(date +%s)" -ge "$deadline" ]; then
        fail_with_zero_scores "Timed out waiting for Tapis job completion"
    fi

    sleep "$TAPIS_POLL_INTERVAL_SECONDS"
done

echo "Fetching Tapis job logs"
LOG_RESPONSE=$(api_call_json GET "/v3/jobs/${JOB_ID}/logs")
LOG_TEXT=$(json_get_logs "$LOG_RESPONSE")

if [ -z "$LOG_TEXT" ]; then
    echo "No logs returned from logs endpoint; trying archived output"
    LOG_TEXT=$(download_job_stdout_from_archive "$JOB_ID")
fi

if [ -z "$LOG_TEXT" ]; then
    fail_with_zero_scores "No logs returned from completed Tapis job or archived output"
fi

echo "Tapis job log excerpt:"
echo "$LOG_TEXT" | tail -n 40

output=$(echo "$LOG_TEXT" | grep '^fib_output=' | tail -1 | sed 's/^fib_output=//' || true)
elapsed=$(echo "$LOG_TEXT" | grep '^elapsed=' | tail -1 | sed 's/^elapsed=//' || true)

if [ -z "$output" ]; then
    output=$(echo "$LOG_TEXT" | grep -E '^fib\(20\)=[0-9]+$' | tail -1 || true)
fi

if [ -z "${output:-}" ] || [ -z "${elapsed:-}" ]; then
    fail_with_zero_scores "Could not parse fib_output/elapsed from Tapis job logs"
fi

echo "Output from remote ./fib ${FIB_INPUT}: $output"
echo "Execution time from remote job: ${elapsed} seconds"

if echo "$output" | grep -qE '^fib\(20\)=[0-9]+$'; then
    correctness=100
    echo "Success: Output matches expected format: $output"
else
    correctness=0
    echo "Failure: Output does not match expected format 'fib(20)=<number>'"
    echo "  Expected format: fib(20)=<number>"
    echo "  Actual output: $output"
fi

performance=$(calculate_performance_score "$elapsed")

echo "{\"scores\": {\"Correctness\": ${correctness}, \"Performance\": ${performance}}}"

exit 0

