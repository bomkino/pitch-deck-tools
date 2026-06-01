#!/usr/bin/env bash
# Linux/macOS terminal launcher for the Deck Prototyper.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Starting Pitch Deck Prototyper"
echo "  $PROJECT_DIR"
echo "========================================"

exec python3 "$PROJECT_DIR/app.py"
