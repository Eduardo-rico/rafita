#!/bin/bash

set -euo pipefail

PROVIDER=""
ASSUME_YES=false

usage() {
    cat << USAGE
Usage: rafita-enable [--provider codex|kimi|claude] [--yes]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)
            PROVIDER=${2:-}
            shift 2
            ;;
        --yes|-y)
            ASSUME_YES=true
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/templates" ]]; then
    TEMPLATE_DIR="$SCRIPT_DIR/templates"
else
    TEMPLATE_DIR="$HOME/.rafita/templates"
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Templates directory not found: $TEMPLATE_DIR"
    exit 1
fi

if [[ -z "$PROVIDER" ]]; then
    if [[ "$ASSUME_YES" == "true" ]]; then
        PROVIDER="codex"
    else
        echo "Select provider for this project:"
        echo "1) codex"
        echo "2) kimi"
        echo "3) claude"
        read -r -p "Choice [1-3]: " choice
        case "$choice" in
            1) PROVIDER="codex" ;;
            2) PROVIDER="kimi" ;;
            3) PROVIDER="claude" ;;
            *) echo "Invalid choice"; exit 1 ;;
        esac
    fi
fi

case "$PROVIDER" in
    codex|kimi|claude) ;;
    *)
        echo "Invalid provider: $PROVIDER"
        exit 1
        ;;
esac

if [[ -d ".rafita" && "$ASSUME_YES" != "true" ]]; then
    read -r -p ".rafita already exists. Overwrite template files? [y/N] " overwrite
    overwrite=${overwrite:-N}
else
    overwrite="y"
fi

mkdir -p .rafita/specs .rafita/logs .rafita/docs/generated

if [[ "$overwrite" =~ ^[Yy]$ ]]; then
    cp "$TEMPLATE_DIR/PROMPT.md" .rafita/PROMPT.md
    cp "$TEMPLATE_DIR/fix_plan.md" .rafita/fix_plan.md
    cp "$TEMPLATE_DIR/AGENT.md" .rafita/AGENT.md
else
    [[ -f .rafita/PROMPT.md ]] || cp "$TEMPLATE_DIR/PROMPT.md" .rafita/PROMPT.md
    [[ -f .rafita/fix_plan.md ]] || cp "$TEMPLATE_DIR/fix_plan.md" .rafita/fix_plan.md
    [[ -f .rafita/AGENT.md ]] || cp "$TEMPLATE_DIR/AGENT.md" .rafita/AGENT.md
fi

project_name=$(basename "$PWD")
if [[ -f .rafitarc ]]; then
    cp .rafitarc ".rafitarc.bak.$(date +%s)"
fi

sed \
    -e "s/__PROJECT_NAME__/${project_name}/g" \
    -e "s/__PROVIDER__/${PROVIDER}/g" \
    "$TEMPLATE_DIR/rafitarc.template" > .rafitarc

echo "Rafita enabled for $(basename "$PWD")"
echo "Provider: $PROVIDER"
echo "Run: rafita"
