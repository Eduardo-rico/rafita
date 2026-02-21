#!/bin/bash

set -euo pipefail

PROVIDER="codex"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)
            PROVIDER=${2:-codex}
            shift 2
            ;;
        -h|--help)
            echo "Usage: rafita-enable-ci [--provider codex|kimi|claude]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/rafita_enable.sh" ]]; then
    "$SCRIPT_DIR/rafita_enable.sh" --provider "$PROVIDER" --yes
elif [[ -x "$HOME/.rafita/rafita_enable.sh" ]]; then
    "$HOME/.rafita/rafita_enable.sh" --provider "$PROVIDER" --yes
else
    echo "rafita_enable.sh not found"
    exit 1
fi
