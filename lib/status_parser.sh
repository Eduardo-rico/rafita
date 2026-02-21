#!/bin/bash

extract_status_block() {
    local file=$1
    awk '/---RAFITA_STATUS---/{flag=1;next}/---END_RAFITA_STATUS---/{flag=0}flag' "$file"
}

has_status_block() {
    local file=$1
    if extract_status_block "$file" | grep -q '^[A-Z_][A-Z_0-9]*:'; then
        return 0
    fi
    return 1
}

get_status_value() {
    local file=$1
    local key=$2
    local default_value=${3:-""}

    local value
    value=$(extract_status_block "$file" | sed -n "s/^${key}:[[:space:]]*//p" | head -n 1)

    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

normalize_bool() {
    local v
    v=$(echo "$1" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ "$v" == "true" || "$v" == "1" || "$v" == "yes" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

sanitize_json_string() {
    local input=${1:-""}
    input=${input//$'\n'/ }
    input=${input//$'\r'/ }
    input=${input//"/\\"}
    echo "$input"
}
