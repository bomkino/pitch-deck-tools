#!/bin/bash
# Double-click to check export status.
#
# For now, final export happens inside the browser app:
#   1. Double-click start-prototyper.command
#   2. Open the Export tab
#   3. Use the export buttons there

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════"
echo "  Pitch Deck Prototyper Export"
echo "════════════════════════════════════════════════"

python3 "$PROJECT_DIR/app.py" --export

echo ""
read -n 1 -s -r -p "Press any key to close…"
echo ""
