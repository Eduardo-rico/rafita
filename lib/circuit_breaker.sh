#!/bin/bash

CB_NO_PROGRESS_THRESHOLD=${CB_NO_PROGRESS_THRESHOLD:-3}
CB_FAILURE_THRESHOLD=${CB_FAILURE_THRESHOLD:-5}
CB_SAME_ERROR_THRESHOLD=${CB_SAME_ERROR_THRESHOLD:-5}

CB_CONSECUTIVE_NO_PROGRESS=0
CB_CONSECUTIVE_FAILURES=0
CB_LAST_ERROR=""
CB_SAME_ERROR_COUNT=0
CB_OPEN_REASON=""

cb_init() {
    CB_NO_PROGRESS_THRESHOLD=${1:-$CB_NO_PROGRESS_THRESHOLD}
    CB_FAILURE_THRESHOLD=${2:-$CB_FAILURE_THRESHOLD}
    CB_SAME_ERROR_THRESHOLD=${3:-$CB_SAME_ERROR_THRESHOLD}
}

cb_on_success() {
    CB_CONSECUTIVE_FAILURES=0
}

cb_on_failure() {
    local err_msg=${1:-"unknown error"}
    CB_CONSECUTIVE_FAILURES=$((CB_CONSECUTIVE_FAILURES + 1))

    if [[ "$err_msg" == "$CB_LAST_ERROR" ]]; then
        CB_SAME_ERROR_COUNT=$((CB_SAME_ERROR_COUNT + 1))
    else
        CB_SAME_ERROR_COUNT=1
        CB_LAST_ERROR="$err_msg"
    fi
}

cb_on_progress() {
    CB_CONSECUTIVE_NO_PROGRESS=0
}

cb_on_no_progress() {
    CB_CONSECUTIVE_NO_PROGRESS=$((CB_CONSECUTIVE_NO_PROGRESS + 1))
}

cb_is_open() {
    if (( CB_CONSECUTIVE_FAILURES >= CB_FAILURE_THRESHOLD )); then
        CB_OPEN_REASON="too many consecutive failures ($CB_CONSECUTIVE_FAILURES)"
        return 0
    fi

    if (( CB_CONSECUTIVE_NO_PROGRESS >= CB_NO_PROGRESS_THRESHOLD )); then
        CB_OPEN_REASON="no progress for $CB_CONSECUTIVE_NO_PROGRESS loops"
        return 0
    fi

    if (( CB_SAME_ERROR_COUNT >= CB_SAME_ERROR_THRESHOLD )); then
        CB_OPEN_REASON="same error repeated $CB_SAME_ERROR_COUNT times"
        return 0
    fi

    return 1
}

cb_reason() {
    echo "$CB_OPEN_REASON"
}
