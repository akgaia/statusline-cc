#!/bin/bash
# Installer for statusline-cc.
# Copies statusline.sh into the Claude Code config dir and merges the
# statusLine setting into settings.json (backing it up first).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v node >/dev/null 2>&1 || { echo "error: node is required but not found in PATH." >&2; exit 1; }

mkdir -p "$CLAUDE_DIR"

# 1. Install the script.
install -m 0755 "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
echo "✓ installed $CLAUDE_DIR/statusline.sh"

# 2. Merge the statusLine setting into settings.json without clobbering anything.
if [ -f "$SETTINGS" ]; then
    BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS" "$BACKUP"
    echo "✓ backed up existing settings to $BACKUP"
else
    echo '{}' > "$SETTINGS"
fi

SETTINGS="$SETTINGS" node -e '
const fs = require("fs");
const path = process.env.SETTINGS;
let s = {};
try { s = JSON.parse(fs.readFileSync(path, "utf8") || "{}"); }
catch (e) { console.error("error: could not parse " + path + ": " + e.message); process.exit(1); }
s.statusLine = { type: "command", command: "~/.claude/statusline.sh" };
fs.writeFileSync(path, JSON.stringify(s, null, 2) + "\n");
'
echo "✓ wrote statusLine setting to $SETTINGS"
echo
echo "Done. Restart Claude Code (or start a new session) to see the status line."
