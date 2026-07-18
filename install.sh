#!/bin/bash
# Install the Claude Code statusline on this machine.
#
# 1. Copies statusline.sh → ~/.claude/statusline.sh
# 2. Points settings.json statusLine at it (backs up settings first).
set -euo pipefail

command -v jq >/dev/null || { echo "jq required (brew install jq)"; exit 1; }

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"
cp "$SRC_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"
echo "installed: $CLAUDE_DIR/statusline.sh"

CMD='bash "$HOME/.claude/statusline.sh"'

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-statusline"

PREV=$(jq -r '.statusLine.command // empty' "$SETTINGS")
if [ -n "$PREV" ] && [ "$PREV" != "$CMD" ]; then
    echo "note: replacing existing statusLine (saved in $SETTINGS.bak-statusline):"
    echo "      $PREV"
fi

TMP=$(mktemp)
jq --arg cmd "$CMD" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$TMP"
mv "$TMP" "$SETTINGS"

echo "statusLine set in $SETTINGS"
echo "restart Claude Code to see it."
