#!/bin/bash
# Double-click to enable: re-runs the indexer every 60 seconds in the background.
# Drop new asset folders in, switch to your browser, hit reload.
# To stop, double-click live-updates-off.command.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$PROJECT_DIR/_index/_scripts/index_assets.py"
HASH=$(echo -n "$PROJECT_DIR" | md5 -q | cut -c1-10)
LABEL="dog.pitch.assetindex.$HASH"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$PROJECT_DIR/_index/_scripts/live-updates.log"

echo "════════════════════════════════════════════════"
echo "  Enabling live updates for"
echo "  $PROJECT_DIR"
echo "════════════════════════════════════════════════"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

# Reload (unload first in case it was already running)
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "✓ Watcher installed: $LABEL"
echo "  Re-indexes every 60 seconds"
echo "  Log: $LOG"
echo ""
echo "To stop: double-click live-updates-off.command"
echo ""
read -n 1 -s -r -p "Press any key to close…"
echo ""
