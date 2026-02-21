#!/bin/bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
RAFITA_HOME="$HOME/.rafita"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Rafita globally..."

mkdir -p "$INSTALL_DIR" "$RAFITA_HOME" "$RAFITA_HOME/lib" "$RAFITA_HOME/templates"

for file in rafita_loop.sh rafita_monitor.sh setup.sh rafita_import.sh rafita_enable.sh rafita_enable_ci.sh; do
    cp "$SCRIPT_DIR/$file" "$RAFITA_HOME/"
done

cp -R "$SCRIPT_DIR/lib/"* "$RAFITA_HOME/lib/"
cp -R "$SCRIPT_DIR/templates/"* "$RAFITA_HOME/templates/"

cat > "$INSTALL_DIR/rafita" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/rafita_loop.sh" "$@"
WRAP

cat > "$INSTALL_DIR/rafita-monitor" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/rafita_monitor.sh" "$@"
WRAP

cat > "$INSTALL_DIR/rafita-setup" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/setup.sh" "$@"
WRAP

cat > "$INSTALL_DIR/rafita-import" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/rafita_import.sh" "$@"
WRAP

cat > "$INSTALL_DIR/rafita-enable" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/rafita_enable.sh" "$@"
WRAP

cat > "$INSTALL_DIR/rafita-enable-ci" << 'WRAP'
#!/bin/bash
exec "$HOME/.rafita/rafita_enable_ci.sh" "$@"
WRAP

chmod +x "$RAFITA_HOME"/*.sh
chmod +x "$RAFITA_HOME"/lib/*.sh
chmod +x "$INSTALL_DIR/rafita" "$INSTALL_DIR/rafita-monitor" "$INSTALL_DIR/rafita-setup" \
    "$INSTALL_DIR/rafita-import" "$INSTALL_DIR/rafita-enable" "$INSTALL_DIR/rafita-enable-ci"

echo "Rafita installed in $RAFITA_HOME"
echo "Commands installed in $INSTALL_DIR"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "Add this to your shell profile if needed:"
    echo "export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "Done. Try: rafita-setup demo --provider codex"
