#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAFITA_HOME="${RAFITA_HOME:-$HOME/.rafita}"

# Support both local repo execution and global installed execution.
if [[ -d "$SCRIPT_DIR/lib" ]]; then
    LIB_DIR="$SCRIPT_DIR/lib"
elif [[ -d "$RAFITA_HOME/lib" ]]; then
    LIB_DIR="$RAFITA_HOME/lib"
else
    echo "Error: could not find lib directory."
    exit 1
fi

if [[ -d "$SCRIPT_DIR/templates" ]]; then
    TEMPLATE_DIR="$SCRIPT_DIR/templates"
elif [[ -d "$RAFITA_HOME/templates" ]]; then
    TEMPLATE_DIR="$RAFITA_HOME/templates"
else
    TEMPLATE_DIR=""
fi

# shellcheck source=/dev/null
source "$LIB_DIR/date_utils.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/timeout_utils.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/status_parser.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/rate_limit.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/circuit_breaker.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/provider.sh"

RAFITA_DIR=".rafita"
PROMPT_FILE="$RAFITA_DIR/PROMPT.md"
FIX_PLAN_FILE="$RAFITA_DIR/fix_plan.md"
SPECS_DIR="$RAFITA_DIR/specs"
LOG_DIR="$RAFITA_DIR/logs"
STATUS_FILE="$RAFITA_DIR/status.json"
PROGRESS_FILE="$RAFITA_DIR/progress.json"
CALL_COUNT_FILE="$RAFITA_DIR/.call_count"
TIMESTAMP_FILE="$RAFITA_DIR/.last_reset"

# Defaults (can be overridden by .rafitarc)
PROVIDER="codex"
CODEX_CMD="codex"
KIMI_CMD="kimi"
CLAUDE_CMD="claude"
MAX_CALLS_PER_HOUR=100
TIMEOUT_MINUTES=20
MAX_LOOPS=0
SLEEP_BETWEEN_LOOPS=2
CB_NO_PROGRESS_THRESHOLD=3
CB_FAILURE_THRESHOLD=5
CB_SAME_ERROR_THRESHOLD=5
VERBOSE=false

FORWARD_ARGS=()
PROVIDER_OVERRIDE=""
MONITOR_MODE=false

usage() {
    cat << USAGE
Rafita - autonomous development loop

Usage: rafita [options]

Options:
  --provider <codex|kimi|claude>  Explicit provider selection (no automatic fallback)
  --monitor                        Run inside tmux with live monitor pane
  --max-loops <n>                  Stop after n loops (0 = unlimited)
  --timeout <minutes>              Timeout per provider invocation
  --verbose                        Verbose logs
  -h, --help                       Show help
USAGE
}

log_line() {
    local level=$1
    local msg=$2
    local ts
    ts=$(get_readable_timestamp)
    mkdir -p "$LOG_DIR"
    echo "[$ts] [$level] $msg" | tee -a "$LOG_DIR/rafita.log"
}

load_rafitarc() {
    if [[ -f ".rafitarc" ]]; then
        # shellcheck source=/dev/null
        source ".rafitarc"
    fi
}

ensure_rafita_structure() {
    mkdir -p "$RAFITA_DIR" "$SPECS_DIR" "$LOG_DIR" "$RAFITA_DIR/docs/generated"

    if [[ ! -f "$PROMPT_FILE" && -n "$TEMPLATE_DIR" && -f "$TEMPLATE_DIR/PROMPT.md" ]]; then
        cp "$TEMPLATE_DIR/PROMPT.md" "$PROMPT_FILE"
    fi
    if [[ ! -f "$FIX_PLAN_FILE" && -n "$TEMPLATE_DIR" && -f "$TEMPLATE_DIR/fix_plan.md" ]]; then
        cp "$TEMPLATE_DIR/fix_plan.md" "$FIX_PLAN_FILE"
    fi
}

write_status_json() {
    local loop_count=$1
    local status=$2
    local exit_signal=$3
    local tasks_completed=$4
    local files_modified=$5
    local tests_status=$6
    local work_type=$7
    local recommendation=$8
    local provider_exit=$9

    local rec_safe
    rec_safe=$(sanitize_json_string "$recommendation")

    cat > "$STATUS_FILE" << JSON
{
  "timestamp": "$(get_iso_timestamp)",
  "provider": "${PROVIDER}",
  "loop_count": ${loop_count},
  "status": "${status}",
  "exit_signal": ${exit_signal},
  "tasks_completed_this_loop": ${tasks_completed},
  "files_modified": ${files_modified},
  "tests_status": "${tests_status}",
  "work_type": "${work_type}",
  "recommendation": "${rec_safe}",
  "provider_exit_code": ${provider_exit},
  "calls_made_this_hour": $(rate_limit_current_calls),
  "max_calls_per_hour": ${MAX_CALLS_PER_HOUR}
}
JSON
}

write_progress_json() {
    local phase=$1
    local detail=$2
    local detail_safe
    detail_safe=$(sanitize_json_string "$detail")

    cat > "$PROGRESS_FILE" << JSON
{
  "timestamp": "$(get_iso_timestamp)",
  "provider": "${PROVIDER}",
  "phase": "${phase}",
  "detail": "${detail_safe}"
}
JSON
}

build_runtime_prompt() {
    local loop_count=$1
    local out_file=$2

    cat "$PROMPT_FILE" > "$out_file"
    cat >> "$out_file" << EOF_PROMPT

## Rafita Runtime Context
- Provider: ${PROVIDER}
- Loop: ${loop_count}
- Timestamp: $(get_iso_timestamp)
- Read and apply: ${FIX_PLAN_FILE}
- Read and apply specs in: ${SPECS_DIR}

IMPORTANT:
1) Do exactly one highest-priority meaningful implementation step.
2) If tasks remain, keep EXIT_SIGNAL false.
3) If all work is complete, set EXIT_SIGNAL true.
4) Always include the status block exactly:

---RAFITA_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: <number>
FILES_MODIFIED: <number>
TESTS_STATUS: PASSING | FAILING | NOT_RUN
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION | REFACTORING | DEBUGGING
EXIT_SIGNAL: false | true
RECOMMENDATION: <one line>
---END_RAFITA_STATUS---
EOF_PROMPT
}

start_tmux_monitor_mode() {
    if ! command -v tmux >/dev/null 2>&1; then
        echo "tmux not found; running without --monitor mode."
        MONITOR_MODE=false
        return 1
    fi

    local session_name="rafita-$(date +%s)"
    local self_cmd
    self_cmd=$(command -v rafita || true)
    if [[ -z "$self_cmd" ]]; then
        self_cmd="$0"
    fi

    local loop_cmd
    loop_cmd="cd $(printf '%q' "$PWD") && $(printf '%q' "$self_cmd")"
    for arg in "${FORWARD_ARGS[@]}"; do
        loop_cmd+=" $(printf '%q' "$arg")"
    done

    local monitor_cmd
    if [[ -x "$RAFITA_HOME/rafita_monitor.sh" ]]; then
        monitor_cmd="cd $(printf '%q' "$PWD") && $(printf '%q' "$RAFITA_HOME/rafita_monitor.sh")"
    elif [[ -x "$SCRIPT_DIR/rafita_monitor.sh" ]]; then
        monitor_cmd="cd $(printf '%q' "$PWD") && $(printf '%q' "$SCRIPT_DIR/rafita_monitor.sh")"
    else
        echo "Monitor script not found; running without tmux monitor."
        return 1
    fi

    tmux new-session -d -s "$session_name" "$loop_cmd"
    tmux split-window -h -t "$session_name" "$monitor_cmd"
    tmux select-layout -t "$session_name" even-horizontal >/dev/null 2>&1 || true
    tmux attach -t "$session_name"
    return 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                PROVIDER_OVERRIDE=${2:-""}
                FORWARD_ARGS+=("--provider" "$PROVIDER_OVERRIDE")
                shift 2
                ;;
            --monitor)
                MONITOR_MODE=true
                shift
                ;;
            --max-loops)
                MAX_LOOPS=${2:-0}
                FORWARD_ARGS+=("--max-loops" "$MAX_LOOPS")
                shift 2
                ;;
            --timeout)
                TIMEOUT_MINUTES=${2:-20}
                FORWARD_ARGS+=("--timeout" "$TIMEOUT_MINUTES")
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                FORWARD_ARGS+=("--verbose")
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    load_rafitarc

    if [[ -n "$PROVIDER_OVERRIDE" ]]; then
        PROVIDER="$PROVIDER_OVERRIDE"
    fi

    if ! provider_validate "$PROVIDER"; then
        echo "Invalid provider '$PROVIDER'. Use codex, kimi, or claude."
        exit 1
    fi

    if ! provider_check_available "$PROVIDER"; then
        echo "Provider command for '$PROVIDER' is not available in PATH."
        echo "Set ${PROVIDER^^}_CMD in .rafitarc if needed."
        exit 1
    fi

    if [[ "$MONITOR_MODE" == "true" ]]; then
        if start_tmux_monitor_mode; then
            exit 0
        fi
    fi

    ensure_rafita_structure
    rate_limit_init "$CALL_COUNT_FILE" "$TIMESTAMP_FILE"
    cb_init "$CB_NO_PROGRESS_THRESHOLD" "$CB_FAILURE_THRESHOLD" "$CB_SAME_ERROR_THRESHOLD"

    log_line "INFO" "Starting Rafita loop with provider '$PROVIDER'"

    local loop_count=0
    local finished=false

    while [[ "$finished" == "false" ]]; do
        if (( MAX_LOOPS > 0 && loop_count >= MAX_LOOPS )); then
            log_line "INFO" "Reached max loops ($MAX_LOOPS). Stopping."
            break
        fi

        rate_limit_reset_if_needed
        if ! rate_limit_can_call "$MAX_CALLS_PER_HOUR"; then
            local wait_seconds
            wait_seconds=$(rate_limit_seconds_until_reset)
            write_progress_json "rate_limited" "Call cap reached; waiting ${wait_seconds}s"
            log_line "WARN" "Rate limit reached (${MAX_CALLS_PER_HOUR}/hour). Waiting ${wait_seconds}s."
            sleep "$wait_seconds"
            continue
        fi

        loop_count=$((loop_count + 1))
        local ts output_file runtime_prompt provider_exit
        ts=$(date '+%Y-%m-%d_%H-%M-%S')
        output_file="$LOG_DIR/provider_output_${ts}.log"
        runtime_prompt="$RAFITA_DIR/runtime_prompt_${ts}.md"

        build_runtime_prompt "$loop_count" "$runtime_prompt"
        write_progress_json "executing" "Loop ${loop_count}: running provider"

        rate_limit_increment
        set +e
        provider_exec "$PROVIDER" "$runtime_prompt" "$output_file" "$TIMEOUT_MINUTES" "$PWD"
        provider_exit=$?
        set -e

        local status exit_signal tasks_completed files_modified tests_status work_type recommendation
        if has_status_block "$output_file"; then
            status=$(get_status_value "$output_file" "STATUS" "IN_PROGRESS")
            exit_signal=$(normalize_bool "$(get_status_value "$output_file" "EXIT_SIGNAL" "false")")
            tasks_completed=$(get_status_value "$output_file" "TASKS_COMPLETED_THIS_LOOP" "0")
            files_modified=$(get_status_value "$output_file" "FILES_MODIFIED" "0")
            tests_status=$(get_status_value "$output_file" "TESTS_STATUS" "NOT_RUN")
            work_type=$(get_status_value "$output_file" "WORK_TYPE" "IMPLEMENTATION")
            recommendation=$(get_status_value "$output_file" "RECOMMENDATION" "Continue with next task")
        else
            status="BLOCKED"
            exit_signal="false"
            tasks_completed=0
            files_modified=0
            tests_status="NOT_RUN"
            work_type="DEBUGGING"
            recommendation="Missing RAFITA_STATUS block in provider response"
        fi

        if [[ "$provider_exit" -eq 0 ]]; then
            cb_on_success
        else
            cb_on_failure "provider_exit_${provider_exit}"
        fi

        if [[ "$status" == "BLOCKED" ]]; then
            cb_on_failure "status_blocked"
        fi

        if [[ "$tasks_completed" =~ ^[0-9]+$ && "$files_modified" =~ ^[0-9]+$ ]]; then
            if (( tasks_completed > 0 || files_modified > 0 )); then
                cb_on_progress
            else
                cb_on_no_progress
            fi
        else
            cb_on_no_progress
        fi

        write_status_json "$loop_count" "$status" "$exit_signal" "$tasks_completed" "$files_modified" "$tests_status" "$work_type" "$recommendation" "$provider_exit"
        write_progress_json "completed" "Loop ${loop_count} finished with status ${status}"

        log_line "LOOP" "#${loop_count} status=${status} exit_signal=${exit_signal} tasks=${tasks_completed} files=${files_modified} provider_exit=${provider_exit}"

        if cb_is_open; then
            local reason
            reason=$(cb_reason)
            log_line "ERROR" "Circuit breaker opened: $reason"
            write_progress_json "circuit_open" "$reason"
            break
        fi

        if [[ "$status" == "COMPLETE" && "$exit_signal" == "true" ]]; then
            log_line "SUCCESS" "Exit conditions met. Rafita is done."
            finished=true
            break
        fi

        sleep "$SLEEP_BETWEEN_LOOPS"
    done

    log_line "INFO" "Rafita loop finished."
}

main "$@"
