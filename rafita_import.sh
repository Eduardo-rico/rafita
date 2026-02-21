#!/bin/bash

set -euo pipefail

usage() {
    cat << USAGE
Usage:
  rafita-import <requirements.md> [project_name] [--provider codex|kimi|claude]

Examples:
  rafita-import docs/prd.md my-project --provider codex
  rafita-import ../spec.md --provider kimi
USAGE
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

REQ_FILE=""
PROJECT_NAME=""
PROVIDER="codex"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

REQ_FILE=$1
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)
            PROVIDER=${2:-codex}
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            PROJECT_NAME=$1
            shift
            ;;
    esac
done

if [[ ! -f "$REQ_FILE" ]]; then
    echo "Requirements file not found: $REQ_FILE"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"
ENABLE_CI_SCRIPT="$SCRIPT_DIR/rafita_enable_ci.sh"
if [[ ! -x "$SETUP_SCRIPT" ]]; then
    SETUP_SCRIPT="$HOME/.rafita/setup.sh"
fi
if [[ ! -x "$ENABLE_CI_SCRIPT" ]]; then
    ENABLE_CI_SCRIPT="$HOME/.rafita/rafita_enable_ci.sh"
fi

if [[ -n "$PROJECT_NAME" ]]; then
    if [[ -d "$PROJECT_NAME" ]]; then
        cd "$PROJECT_NAME"
        "$ENABLE_CI_SCRIPT" --provider "$PROVIDER"
    else
        "$SETUP_SCRIPT" "$PROJECT_NAME" --provider "$PROVIDER"
        cd "$PROJECT_NAME"
    fi
else
    if [[ ! -d ".rafita" ]]; then
        "$ENABLE_CI_SCRIPT" --provider "$PROVIDER"
    fi
fi

mkdir -p .rafita/specs
cp "$REQ_FILE" .rafita/specs/requirements.md

if ! grep -q "Imported requirements" .rafita/fix_plan.md 2>/dev/null; then
    cat >> .rafita/fix_plan.md << 'EOF_PLAN'

## Imported requirements
- [ ] Review .rafita/specs/requirements.md and extract implementation tasks
EOF_PLAN
fi

echo "Imported requirements to .rafita/specs/requirements.md"
echo "Provider set to: $PROVIDER"
