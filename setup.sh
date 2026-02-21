#!/bin/bash

set -euo pipefail

PROJECT_NAME="my-project"
PROVIDER="codex"

usage() {
    cat << USAGE
Usage: rafita-setup [project_name] [--provider codex|kimi|claude]
USAGE
}

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

case "$PROVIDER" in
    codex|kimi|claude) ;;
    *)
        echo "Invalid provider: $PROVIDER"
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/templates" ]]; then
    TEMPLATE_DIR="$SCRIPT_DIR/templates"
else
    TEMPLATE_DIR="$HOME/.rafita/templates"
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Templates directory not found: $TEMPLATE_DIR"
    echo "Run ./install.sh first or execute this script from repository root."
    exit 1
fi

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

mkdir -p src .rafita/specs .rafita/logs .rafita/docs/generated

cp "$TEMPLATE_DIR/PROMPT.md" .rafita/PROMPT.md
cp "$TEMPLATE_DIR/fix_plan.md" .rafita/fix_plan.md
cp "$TEMPLATE_DIR/AGENT.md" .rafita/AGENT.md

if [[ -f "$TEMPLATE_DIR/rafitarc.template" ]]; then
    sed \
        -e "s/__PROJECT_NAME__/${PROJECT_NAME}/g" \
        -e "s/__PROVIDER__/${PROVIDER}/g" \
        "$TEMPLATE_DIR/rafitarc.template" > .rafitarc
else
    cat > .rafitarc << RC
PROJECT_NAME="${PROJECT_NAME}"
PROVIDER="${PROVIDER}"
CODEX_CMD="codex"
KIMI_CMD="kimi"
CLAUDE_CMD="claude"
MAX_CALLS_PER_HOUR=100
TIMEOUT_MINUTES=20
MAX_LOOPS=0
MIN_LOOPS=5
LIVE_OUTPUT=false
COMPLETION_INDICATOR_THRESHOLD=2
RC
fi

if [[ ! -f README.md ]]; then
    cat > README.md << README
# ${PROJECT_NAME}

Initialized with Rafita.
README
fi

if [[ ! -f .gitignore ]]; then
    cat > .gitignore << GITIGNORE
.rafita/logs/
.rafita/progress.json
.rafita/status.json
.rafita/runtime_prompt_*.md
GITIGNORE
fi

if [[ ! -d .git ]]; then
    git init >/dev/null 2>&1 || true
fi

echo "Rafita project created: $PROJECT_NAME"
echo "Provider: $PROVIDER"
echo "Next: cd $PROJECT_NAME && rafita"
