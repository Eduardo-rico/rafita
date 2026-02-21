#!/bin/bash

set -euo pipefail

STATUS_FILE=".rafita/status.json"
LOG_FILE=".rafita/logs/rafita.log"
PROGRESS_FILE=".rafita/progress.json"
REFRESH_INTERVAL=2

hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

cleanup() {
    show_cursor
    echo
    echo "Rafita monitor stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

json_value() {
    local file=$1
    local key=$2
    local fallback=$3

    if command -v jq >/dev/null 2>&1; then
        jq -r ".${key} // \"${fallback}\"" "$file" 2>/dev/null || echo "$fallback"
    else
        sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\).*/\1/p" "$file" | head -n 1 || echo "$fallback"
    fi
}

display() {
    clear
    echo "=============================================================="
    echo " RAFITA MONITOR"
    echo "=============================================================="

    if [[ -f "$STATUS_FILE" ]]; then
        local provider status loop_count calls max_calls exit_signal recommendation tests
        provider=$(json_value "$STATUS_FILE" "provider" "unknown")
        status=$(json_value "$STATUS_FILE" "status" "unknown")
        loop_count=$(json_value "$STATUS_FILE" "loop_count" "0")
        calls=$(json_value "$STATUS_FILE" "calls_made_this_hour" "0")
        max_calls=$(json_value "$STATUS_FILE" "max_calls_per_hour" "100")
        exit_signal=$(json_value "$STATUS_FILE" "exit_signal" "false")
        tests=$(json_value "$STATUS_FILE" "tests_status" "NOT_RUN")
        recommendation=$(json_value "$STATUS_FILE" "recommendation" "-")

        echo "Provider:      $provider"
        echo "Loop:          $loop_count"
        echo "Status:        $status"
        echo "Exit Signal:   $exit_signal"
        echo "Tests:         $tests"
        echo "API Calls:     $calls/$max_calls"
        echo "Recommendation:$recommendation"
    else
        echo "Status file not found. Start rafita first."
    fi

    echo
    echo "------------------------ Progress ----------------------------"
    if [[ -f "$PROGRESS_FILE" ]]; then
        tail -n 20 "$PROGRESS_FILE" 2>/dev/null || true
    else
        echo "No progress file yet."
    fi

    echo
    echo "---------------------- Recent Logs ---------------------------"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 12 "$LOG_FILE"
    else
        echo "No logs yet."
    fi

    echo
    echo "Refresh: ${REFRESH_INTERVAL}s | Ctrl+C to exit | $(date '+%H:%M:%S')"
}

main() {
    hide_cursor
    while true; do
        display
        sleep "$REFRESH_INTERVAL"
    done
}

main
