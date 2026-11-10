#!/bin/bash
# Remove the custom GitHub Copilot CLI status line.
set -euo pipefail

COPILOT_DIR="${COPILOT_HOME:-$HOME/.copilot}"
SETTINGS="$COPILOT_DIR/settings.json"

if [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq 'del(.statusLine) | if .footer then .footer.showCustom = false else . end' \
        "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "statusLine removed from $SETTINGS"
fi

rm -f "$COPILOT_DIR/statusline.sh" "$COPILOT_DIR/copilot-statusline.sh"
echo "removed $COPILOT_DIR/statusline.sh"