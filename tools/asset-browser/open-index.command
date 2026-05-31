#!/bin/bash
# Double-click me. Opens the asset index in your browser, served from
# a tiny local web server so "Open in Finder" works natively.
#
# Keep this Terminal window open while you work. Close it (or Ctrl+C)
# to stop the server.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If the indexer hasn't been run yet, run it now
if [ ! -f "$PROJECT_DIR/_index/index.html" ]; then
    echo "First time? Building the index…"
    /usr/bin/python3 "$PROJECT_DIR/_index/_scripts/index_assets.py"
fi

# Start the server (this stays in the foreground)
exec /usr/bin/python3 "$PROJECT_DIR/_index/_scripts/server.py"
