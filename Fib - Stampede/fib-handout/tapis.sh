#!/bin/bash

# tapis.sh - Tapis API client helpers and job management.
# Provides: token fetch, API calls, JSON parsing, job submission/polling/log retrieval.

# Helper: check if command exists
have_command() {
    command -v "$1" >/dev/null 2>&1
}

# Helper: detect python binary
detect_python_bin() {
    have_command python3 && { echo "python3"; return 0; }
    have_command python && { echo "python"; return 0; }
    have_command py && { echo "py"; return 0; }
    return 1
}

# Helper: strip carriage returns from strings (Windows line ending cleanup)
strip_carriage_returns() {
    printf '%s' "$1" | tr -d '\r'
}

# Initialize JSON parsing engine (jq or python)
tapis_init_json_engine() {
    JSON_ENGINE=""
    PYTHON_BIN=""

    if have_command jq; then
        JSON_ENGINE="jq"
        return 0
    fi

    if have_command python3; then
        JSON_ENGINE="python"
        PYTHON_BIN="python3"
        return 0
    fi

    if have_command python; then
        JSON_ENGINE="python"
        PYTHON_BIN="python"
        return 0
    fi

    if have_command py; then
        JSON_ENGINE="python"
        PYTHON_BIN="py"
        return 0
    fi

    return 1
}

# Fetch Tapis access token via multiple methods (helper script, CLI, tapipy inline)
tapis_fetch_access_token() {
    local script_dir token_out rc pybin token_helper
    script_dir="$SCRIPT_DIR"
    token_out=""
    rc=1
    pybin=""
    token_helper=""

    if [ -f "${script_dir}/get-tapis-token.py" ]; then
        token_helper="${script_dir}/get-tapis-token.py"
    fi

    pybin=$(detect_python_bin || true)

    # Try helper script + tapipy
    if [ -n "$token_helper" ] && [ -n "$pybin" ] && [ -n "${TAPIS_USERNAME:-}" ] && [ -n "${TAPIS_PASSWORD:-}" ]; then
        set +e
        token_out=$("$pybin" "$token_helper" 2>&1)
        rc=$?
        set -e

        if [ $rc -eq 0 ]; then
            TAPIS_ACCESS_TOKEN=$(echo "$token_out" | awk -F': ' '/^access_token:/ {print $2; exit}' | tr -d '\r')
            [ -n "${TAPIS_ACCESS_TOKEN}" ] && export TAPIS_ACCESS_TOKEN && echo "Successfully fetched token via helper script" && return 0
        fi
    fi

    if [ $rc -ne 0 ] && [ -n "$token_out" ]; then
        echo "$token_out" >&2
    fi

    # Try tapis CLI
    if command -v tapis >/dev/null 2>&1; then
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

    # Try inline tapipy with auto-install
    if [ -n "$pybin" ] && [ -n "${TAPIS_USERNAME:-}" ] && [ -n "${TAPIS_PASSWORD:-}" ]; then
        set +e
        TAPIS_ACCESS_TOKEN=$(TAPIS_BASE_URL="${TAPIS_BASE_URL:-https://tacc.tapis.io}" TAPIS_USERNAME="$TAPIS_USERNAME" TAPIS_PASSWORD="$TAPIS_PASSWORD" "$pybin" - <<'PY'
import os, subprocess, sys
try:
    from tapipy.tapis import Tapis
except ImportError:
    print("Error: tapipy not installed. Attempting to install...", file=sys.stderr)
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "tapipy", "-q"])
        from tapipy.tapis import Tapis
    except Exception as e:
        print(f"Failed to auto-install tapipy: {e}", file=sys.stderr)
        raise SystemExit(1)

tenant_url = os.environ.get("TAPIS_BASE_URL", "https://tacc.tapis.io")
username = os.environ.get("TAPIS_USERNAME", "").strip()
password = os.environ.get("TAPIS_PASSWORD", "").strip()

if not username or not password:
    print("Error: Username and password required", file=sys.stderr)
    raise SystemExit(1)

try:
    t = Tapis(base_url=tenant_url, username=username, password=password)
    t.get_tokens()
    print(t.access_token.access_token)
except Exception as e:
    print(f"Error: Authentication failed: {e}", file=sys.stderr)
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

    [ -n "${TAPIS_ACCESS_TOKEN:-}" ] && return 0
    return 1
}

# Extract job UUID from Tapis API response
tapis_json_get_job_id() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.uuid // .result.id // empty'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c \
'import json, os, sys
s = (os.environ.get("JSON_INPUT") or "").strip()
if not s: print(""); sys.exit(0)
try:
    obj = json.loads(s)
except: print(""); sys.exit(0)
r = obj.get("result") or {}
print(r.get("uuid") or r.get("id") or "")'
    fi
}

# Extract job status from Tapis API response
tapis_json_get_status() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.status // ""'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c \
'import json, os, sys
s = (os.environ.get("JSON_INPUT") or "").strip()
if not s: print(""); sys.exit(0)
try:
    obj = json.loads(s)
except: print(""); sys.exit(0)
r = obj.get("result") or {}
print(r.get("status") or "")'
    fi
}

# Extract logs from Tapis API response
tapis_json_get_logs() {
    local json_text=$1
    if [ "$JSON_ENGINE" = "jq" ]; then
        echo "$json_text" | jq -r '.result.logs // .result // ""'
    else
        JSON_INPUT="$json_text" "$PYTHON_BIN" -c \
'import json, os, sys
s = (os.environ.get("JSON_INPUT") or "").strip()
if not s: print(""); sys.exit(0)
try:
    obj = json.loads(s)
except: print(""); sys.exit(0)
r = obj.get("result")
print((r.get("logs") if isinstance(r, dict) else r) or "")'
    fi
}

# Make authenticated JSON API call to Tapis
tapis_api_call_json() {
    local method=$1 endpoint=$2 payload=${3:-}
    local tmp http_code

    tmp=$(mktemp)
    trap "rm -f '$tmp'" RETURN

    if [ -n "$payload" ]; then
        http_code=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
            -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
            -H "Content-Type: application/json" \
            "${TAPIS_BASE_URL}${endpoint}" \
            -d "$payload") || return 1
    else
        http_code=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
            -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
            "${TAPIS_BASE_URL}${endpoint}") || return 1
    fi

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        echo "Tapis API error ($endpoint, HTTP $http_code):" >&2
        cat "$tmp" >&2
        return 1
    fi

    cat "$tmp"
}

# Download job stdout from archived output (fallback if logs endpoint empty)
tapis_download_job_stdout() {
    local job_id=$1
    local tmp_zip http_code pybin

    pybin="${PYTHON_BIN:-}"
    [ -z "$pybin" ] && pybin=$(command -v python3 || command -v python || true)
    [ -z "$pybin" ] && echo "" && return 0

    tmp_zip=$(mktemp)
    trap "rm -f '$tmp_zip'" RETURN

    http_code=$(curl -sS -o "$tmp_zip" -w "%{http_code}" -X GET \
        -H "Authorization: Bearer ${TAPIS_ACCESS_TOKEN}" \
        -H "X-Tapis-Token: ${TAPIS_ACCESS_TOKEN}" \
        "${TAPIS_BASE_URL}/v3/jobs/${job_id}/output/download//") || { echo ""; return 0; }

    [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ] && { echo ""; return 0; }

    ZIP_PATH="$tmp_zip" "$pybin" - <<'PY'
import io
import os
import zipfile
import sys

zip_path = os.environ.get("ZIP_PATH", "")
if not zip_path: print(""); sys.exit(0)

def decode_bytes(data):
    return data.decode("utf-8", errors="replace")

try:
    with open(zip_path, "rb") as fh:
        raw_data = fh.read()
    if not zipfile.is_zipfile(io.BytesIO(raw_data)):
        text = decode_bytes(raw_data).strip()
        print(text)
        sys.exit(0)

    with zipfile.ZipFile(io.BytesIO(raw_data)) as zf:
        names = [n for n in zf.namelist() if not n.endswith("/")]
        if not names:
            print("")
            sys.exit(0)

        preferred = []
        preferred.extend([n for n in names if os.path.basename(n) == "tapisjob.out"])
        preferred.extend([n for n in names if os.path.basename(n).endswith((".out", ".log", ".txt"))])
        preferred.extend([n for n in names if any(token in os.path.basename(n).lower() for token in ("stdout", "stderr", "log", "result", "output"))])

        target = preferred[0] if preferred else names[0]
        print(decode_bytes(zf.read(target)).strip())
except: print("")
PY
}
