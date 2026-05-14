#!/bin/bash

# assignment.sh - Assignment-specific grading logic for Fibonacci job.
# Edit this file when the assignment requirements change.

strip_carriage_returns() {
    printf '%s' "$1" | tr -d '\r'
}

have_command() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail_with_zero_scores "Required command '$1' not found"
    fi
}

detect_python_bin() {
    have_command python3 && { echo "python3"; return 0; }
    have_command python && { echo "python"; return 0; }
    have_command py && { echo "py"; return 0; }
    return 1
}

# Output zero scores with optional debug info
fail_with_zero_scores() {
    local message=$1 raw=${2:-}
    echo "Failure: ${message}"
    if [ -n "${raw:-}" ]; then
        local raw_json
        raw_json=$(printf '%s' "$raw" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
        echo "{\"scores\": {\"Correctness\": 0, \"Performance\": 0}, \"debug\": ${raw_json}}"
    else
        echo "{\"scores\": {\"Correctness\": 0, \"Performance\": 0}}"
    fi
    exit 0
}

# Calculate performance score: 100 / (1 + elapsed_seconds)
calculate_performance_score() {
    local elapsed=$1
    awk -v e="$elapsed" 'BEGIN { printf "%.1f", 100 / (1 + e) }'
}

# Build Tapis job submission payload with FIB_SOURCE_B64 and environment
assignment_build_submit_payload() {
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
import json, os
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
if app_version := os.environ.get("TAPIS_APP_VERSION", ""):
    payload["appVersion"] = app_version
if partition := os.environ.get("STAMPEDE_PARTITION", ""):
    payload["parameterSet"]["envVariables"].append({"key": "STAMPEDE_PARTITION", "value": partition})
if account := os.environ.get("STAMPEDE_ACCOUNT", ""):
    payload["parameterSet"]["envVariables"].append({"key": "STAMPEDE_ACCOUNT", "value": account})
print(json.dumps(payload, separators=(",", ":")))
PY
    fi
}

# Main grading function: submit job, poll status, fetch logs, parse result, score
assignment_main() {
    local output elapsed correctness performance submit_payload submit_response job_id
    local job_response status deadline log_response log_text

    # Set defaults and strip whitespace
    TAPIS_BASE_URL=$(strip_carriage_returns "${TAPIS_BASE_URL:-https://tacc.tapis.io}")
    TAPIS_ACCESS_TOKEN=$(strip_carriage_returns "${TAPIS_ACCESS_TOKEN:-}")
    TAPIS_APP_ID=$(strip_carriage_returns "${TAPIS_APP_ID:-fibonacci-fork-app}")
    TAPIS_APP_VERSION=$(strip_carriage_returns "${TAPIS_APP_VERSION:-1.0.2}")
    TAPIS_JOB_TIMEOUT_SECONDS=$(strip_carriage_returns "${TAPIS_JOB_TIMEOUT_SECONDS:-300}")
    TAPIS_POLL_INTERVAL_SECONDS=$(strip_carriage_returns "${TAPIS_POLL_INTERVAL_SECONDS:-5}")
    FIB_INPUT=$(strip_carriage_returns "${FIB_INPUT:-20}")
    STAMPEDE_PARTITION=$(strip_carriage_returns "${STAMPEDE_PARTITION:-}")
    STAMPEDE_ACCOUNT=$(strip_carriage_returns "${STAMPEDE_ACCOUNT:-}")

    export TAPIS_BASE_URL TAPIS_ACCESS_TOKEN TAPIS_APP_ID TAPIS_APP_VERSION TAPIS_JOB_TIMEOUT_SECONDS TAPIS_POLL_INTERVAL_SECONDS FIB_INPUT STAMPEDE_PARTITION STAMPEDE_ACCOUNT

    # Validate environment
    require_command curl awk base64 grep sed

    if ! tapis_init_json_engine; then
        fail_with_zero_scores "Need jq or python for JSON parsing"
    fi

    if ! tapis_fetch_access_token; then
        fail_with_zero_scores "Set TAPIS_ACCESS_TOKEN or TAPIS_USERNAME/PASSWORD"
    fi

    [ -f "fib.c" ] || fail_with_zero_scores "fib.c not found"
    [[ "$TAPIS_JOB_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] && [ "$TAPIS_JOB_TIMEOUT_SECONDS" -gt 0 ] || \
        fail_with_zero_scores "TAPIS_JOB_TIMEOUT_SECONDS must be positive"
    [[ "$TAPIS_POLL_INTERVAL_SECONDS" =~ ^[0-9]+$ ]] && [ "$TAPIS_POLL_INTERVAL_SECONDS" -gt 0 ] || \
        fail_with_zero_scores "TAPIS_POLL_INTERVAL_SECONDS must be positive"

    # Submit job
    echo "Encoding submission source for Tapis job"
    FIB_SOURCE_B64=$(base64 < fib.c | tr -d '\n')
    JOB_NAME="autolab-fib-$(date +%s)-$$"
    export FIB_SOURCE_B64 JOB_NAME

    submit_payload=$(assignment_build_submit_payload)

    echo "Submitting Tapis job"
    submit_response=$(tapis_api_call_json POST "/v3/jobs/submit" "$submit_payload") || \
        fail_with_zero_scores "Job submission failed" "$submit_response"
    job_id=$(tapis_json_get_job_id "$submit_response")

    [ -z "$job_id" ] || [ "$job_id" = "null" ] && \
        fail_with_zero_scores "Could not parse job ID" "$submit_response"

    echo "Submitted Tapis job: $job_id"
    echo "Polling job status"

    deadline=$(( $(date +%s) + TAPIS_JOB_TIMEOUT_SECONDS ))
    status=""

    # Poll for completion
    while :; do
        job_response=$(tapis_api_call_json GET "/v3/jobs/${job_id}") || break
        status=$(tapis_json_get_status "$job_response")

        [ -n "$status" ] && echo "Job status: $status"

        case "$status" in
            FINISHED) break ;;
            FAILED|CANCELLED|BLOCKED)
                log_response=$(tapis_api_call_json GET "/v3/jobs/${job_id}/logs" || true)
                log_text=$(tapis_json_get_logs "$log_response")
                echo "Job ended with status $status"
                [ -n "$log_text" ] && echo "$log_text" || echo "(no logs)"
                fail_with_zero_scores "Job failed: $status" "$log_text"
                ;;
        esac

        [ "$(date +%s)" -ge "$deadline" ] && fail_with_zero_scores "Job timeout"
        sleep "$TAPIS_POLL_INTERVAL_SECONDS"
    done

    # Fetch logs (prefer /logs endpoint; fall back to archive)
    echo "Fetching Tapis job logs"
    log_response=$(tapis_api_call_json GET "/v3/jobs/${job_id}/logs") || true
    log_text=$(tapis_json_get_logs "$log_response")

    if [ -z "$log_text" ]; then
        echo "Logs endpoint empty; downloading archive..."
        log_text=$(tapis_download_job_stdout "$job_id")
    fi

    [ -z "$log_text" ] && fail_with_zero_scores "No logs returned" "$job_response"

    echo "Tapis job output (last 40 lines):"
    echo "$log_text" | tail -n 40

    # Parse results
    output=$(echo "$log_text" | grep '^fib_output=' | tail -1 | sed 's/^fib_output=//' || true)
    elapsed=$(echo "$log_text" | grep '^elapsed=' | tail -1 | sed 's/^elapsed=//' || true)

    [ -z "$output" ] && output=$(echo "$log_text" | grep -E '^fib\(20\)=[0-9]+$' | tail -1 || true)

    if [ -z "${output:-}" ] || [ -z "${elapsed:-}" ]; then
        fail_with_zero_scores "Could not parse fib_output/elapsed" "$log_text"
    fi

    echo "Output: $output"
    echo "Elapsed: ${elapsed}s"

    # Score correctness
    if echo "$output" | grep -qE '^fib\(20\)=[0-9]+$'; then
        correctness=100
        echo "Correctness: PASS (output format valid)"
    else
        correctness=0
        echo "Correctness: FAIL (expected fib(20)=<number>)"
    fi

    performance=$(calculate_performance_score "$elapsed")

    echo "{\"scores\": {\"Correctness\": ${correctness}, \"Performance\": ${performance}}}"
}
