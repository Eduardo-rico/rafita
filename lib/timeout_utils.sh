#!/bin/bash

# portable_timeout <duration> <cmd...>
portable_timeout() {
    local duration=$1
    shift

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$duration" "$@"
        return $?
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout "$duration" "$@"
        return $?
    fi

    "$@"
}
