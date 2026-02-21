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
    local live_output=${6:-false}

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
            if [[ "$live_output" == "true" ]]; then
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" exec \
                        --sandbox workspace-write \
                        --ask-for-approval never \
                        -C "$work_dir" \
                        "$prompt_text"
                ) 2>&1 | tee "$output_file"
                return ${PIPESTATUS[0]}
            else
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" exec \
                        --sandbox workspace-write \
                        --ask-for-approval never \
                        -C "$work_dir" \
                        "$prompt_text"
                ) > "$output_file" 2>&1
            fi
            ;;
        kimi)
            if [[ "$live_output" == "true" ]]; then
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                        --print \
                        --output-format text \
                        --final-message-only \
                        -w "$work_dir" \
                        -p "$prompt_text"
                ) 2>&1 | tee "$output_file"
                return ${PIPESTATUS[0]}
            else
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                        --print \
                        --output-format text \
                        --final-message-only \
                        -w "$work_dir" \
                        -p "$prompt_text"
                ) > "$output_file" 2>&1
            fi
            ;;
        claude)
            if [[ "$live_output" == "true" ]]; then
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                        --output-format text \
                        -p "$prompt_text"
                ) 2>&1 | tee "$output_file"
                return ${PIPESTATUS[0]}
            else
                (
                    cd "$work_dir"
                    portable_timeout "${timeout_seconds}s" "${cmd_parts[@]}" \
                        --output-format text \
                        -p "$prompt_text"
                ) > "$output_file" 2>&1
            fi
            ;;
        *)
            echo "Unsupported provider: $provider" > "$output_file"
            return 2
            ;;
    esac
}
