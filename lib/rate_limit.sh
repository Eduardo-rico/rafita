#!/bin/bash

RATE_CALL_COUNT_FILE=""
RATE_TIMESTAMP_FILE=""

rate_limit_init() {
    RATE_CALL_COUNT_FILE=$1
    RATE_TIMESTAMP_FILE=$2

    mkdir -p "$(dirname "$RATE_CALL_COUNT_FILE")"
    [[ -f "$RATE_CALL_COUNT_FILE" ]] || echo "0" > "$RATE_CALL_COUNT_FILE"
    [[ -f "$RATE_TIMESTAMP_FILE" ]] || date +%s > "$RATE_TIMESTAMP_FILE"
}

rate_limit_reset_if_needed() {
    local now last_reset elapsed
    now=$(date +%s)
    last_reset=$(cat "$RATE_TIMESTAMP_FILE" 2>/dev/null || echo "$now")
    elapsed=$((now - last_reset))

    if (( elapsed >= 3600 )); then
        echo "0" > "$RATE_CALL_COUNT_FILE"
        echo "$now" > "$RATE_TIMESTAMP_FILE"
    fi
}

rate_limit_current_calls() {
    cat "$RATE_CALL_COUNT_FILE" 2>/dev/null || echo "0"
}

rate_limit_can_call() {
    local max_calls=$1
    local current
    current=$(rate_limit_current_calls)
    (( current < max_calls ))
}

rate_limit_increment() {
    local current
    current=$(rate_limit_current_calls)
    echo $((current + 1)) > "$RATE_CALL_COUNT_FILE"
}

rate_limit_seconds_until_reset() {
    local now last_reset remaining
    now=$(date +%s)
    last_reset=$(cat "$RATE_TIMESTAMP_FILE" 2>/dev/null || echo "$now")
    remaining=$((3600 - (now - last_reset)))
    if (( remaining < 0 )); then
        remaining=0
    fi
    echo "$remaining"
}
