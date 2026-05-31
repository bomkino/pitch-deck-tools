#!/bin/bash
# Double-click me. Copies the best version of every font into
# _index/fonts-to-install/ — open that folder, Cmd+A, drag into Font Book.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "════════════════════════════════════════════════"
echo "  pitch.dog font consolidator"
echo "  $PROJECT_DIR"
echo "════════════════════════════════════════════════"

python3 "$PROJECT_DIR/_index/_scripts/consolidate_fonts.py"

# Helpful: open the output folder automatically
open "$PROJECT_DIR/_index/fonts-to-install"

read -n 1 -s -r -p "Press any key to close…"
echo ""
