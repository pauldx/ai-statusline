#!/bin/bash
# Remove the statusline: deletes the statusLine key from settings.json
# and removes ~/.claude/statusline.sh. Settings backup kept from install.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "statusLine removed from $SETTINGS"
fi

rm -f "$HOME/.claude/statusline.sh"
echo "removed ~/.claude/statusline.sh"
