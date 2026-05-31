#!/bin/bash
# Double-click me to start the Prototyper App.
# Keep this Terminal window open while you work. Close it to stop the server.

set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════"
echo "  Starting Pitch Deck Prototyper"
echo "  $PROJECT_DIR"
echo "════════════════════════════════════════════════"

# Start the Python server using the active environment
exec python3 "$PROJECT_DIR/app.py"
