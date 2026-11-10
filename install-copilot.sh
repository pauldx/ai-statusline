#!/bin/bash
# Install the custom GitHub Copilot CLI status line.
set -euo pipefail

command -v jq >/dev/null || { echo "jq required (brew install jq)"; exit 1; }

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
COPILOT_DIR="${COPILOT_HOME:-$HOME/.copilot}"
SETTINGS="$COPILOT_DIR/settings.json"
TARGET="$COPILOT_DIR/statusline.sh"

mkdir -p "$COPILOT_DIR"
# Install the generic statusline which auto-detects Copilot vs Claude
cp "$SRC_DIR/statusline.sh" "$TARGET"
chmod +x "$TARGET"
echo "installed: $TARGET"
cp "$SRC_DIR/copilot-statusline.sh" "$COPILOT_DIR/copilot-statusline.sh"
chmod +x "$COPILOT_DIR/copilot-statusline.sh"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-statusline"

CMD='bash "${COPILOT_HOME:-$HOME/.copilot}/statusline.sh"'
PREV=$(jq -r '.statusLine.command // empty' "$SETTINGS")
if [ -n "$PREV" ] && [ "$PREV" != "$CMD" ]; then
    echo "note: replacing existing statusLine (saved in $SETTINGS.bak-statusline):"
    echo "      $PREV"
fi

TMP=$(mktemp)
jq --arg cmd "$CMD" '
    .statusLine = {type: "command", command: $cmd, padding: 0}
    | .footer.showCustom = true
' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

echo "statusLine set in $SETTINGS"
echo "restart Copilot CLI to see it. Use /statusline to toggle other footer items."