#!/bin/bash

provider_validate() {
    local provider=$1
    case "$provider" in
        codex|kimi|claude) return 0 ;;
        *) return 1 ;;
    esac
}

provider_command_name() {
    local provider=$1
    case "$provider" in
        codex) echo "${CODEX_CMD:-codex}" ;;
        kimi) echo "${KIMI_CMD:-kimi}" ;;
        claude) echo "${CLAUDE_CMD:-claude}" ;;
    esac
}

provider_check_available() {
    local provider=$1
    local cmd
    cmd=$(provider_command_name "$provider")

    local -a cmd_parts=()
    read -r -a cmd_parts <<< "$cmd"

    if [[ ${#cmd_parts[@]} -eq 0 ]]; then
        return 1
    fi

    command -v "${cmd_parts[0]}" >/dev/null 2>&1
}

provider_exec() {
    local provider=$1
    local prompt_file=$2
    local output_file=$3
    local timeout_minutes=$4
    local work_dir=$5

    local timeout_seconds=$((timeout_minutes * 60))
    local prompt_text
    prompt_text=$(cat "$prompt_file")

    local cmd
    cmd=$(provider_command_name "$provider")
    local -a cmd_parts=()
    read -r -a cmd_parts <<< "$cmd"

    if [[ ${#cmd_parts[@]} -eq 0 ]]; then
        echo "Provider command not configured for '$provider'" > "$output_file"
        return 127
    fi

    case "$provider" in
        codex)
            (
                cd "$work_dir"
                portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" exec \
                    --sandbox workspace-write \
                    --ask-for-approval never \
                    -C "$work_dir" \
                    "$prompt_text"
            ) > "$output_file" 2>&1
            ;;
        kimi)
            (
                cd "$work_dir"
                portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                    --print \
                    --output-format text \
                    --final-message-only \
                    -w "$work_dir" \
                    -p "$prompt_text"
            ) > "$output_file" 2>&1
            ;;
        claude)
            (
                cd "$work_dir"
                portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                    --output-format text \
                    -p "$prompt_text"
            ) > "$output_file" 2>&1
            ;;
        *)
            echo "Unsupported provider: $provider" > "$output_file"
            return 2
            ;;
    esac
}
