#!/bin/bash
# Double-click to stop the background indexer.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASH=$(echo -n "$PROJECT_DIR" | md5 -q | cut -c1-10)
LABEL="dog.pitch.assetindex.$HASH"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "════════════════════════════════════════════════"
echo "  Disabling live updates for"
echo "  $PROJECT_DIR"
echo "════════════════════════════════════════════════"

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "✓ Watcher removed: $LABEL"
else
    echo "(No watcher was running for this project.)"
fi

echo ""
echo "You can still double-click index-assets.command any time"
echo "for a manual rebuild."
echo ""
read -n 1 -s -r -p "Press any key to close…"
echo ""
