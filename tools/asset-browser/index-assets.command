#!/bin/bash
# Double-click me. Builds _index/index.html from your asset folders.
# Safe to re-run any time — only regenerates thumbnails for new/changed files.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "════════════════════════════════════════════════"
echo "  pitch.dog asset indexer"
echo "  $PROJECT_DIR"
echo "════════════════════════════════════════════════"

# Sanity checks — these all ship with macOS, so this should never fail.
for tool in python3 sips qlmanage; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ Missing required tool: $tool (should be on every Mac — odd)"
    exit 1
  fi
done

# ffmpeg is optional; warn but proceed
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "(ffmpeg not found — video bundles will be skipped. brew install ffmpeg to enable.)"
fi

python3 "$PROJECT_DIR/_index/_scripts/index_assets.py"

echo ""
echo "Tip: keep _index/index.html open in a browser tab while you work."
echo ""

# Keep Terminal window open so you can read output
read -n 1 -s -r -p "Press any key to close…"
echo ""
