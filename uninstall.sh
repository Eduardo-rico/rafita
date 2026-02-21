#!/bin/bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
RAFITA_HOME="$HOME/.rafita"
PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
    PURGE=true
fi

rm -f "$INSTALL_DIR/rafita" "$INSTALL_DIR/rafita-monitor" "$INSTALL_DIR/rafita-setup" \
    "$INSTALL_DIR/rafita-import" "$INSTALL_DIR/rafita-enable" "$INSTALL_DIR/rafita-enable-ci"

echo "Removed global Rafita command wrappers from $INSTALL_DIR"

if [[ "$PURGE" == "true" ]]; then
    rm -rf "$RAFITA_HOME"
    echo "Removed $RAFITA_HOME"
else
    echo "Kept $RAFITA_HOME (use --purge to remove it)."
fi
