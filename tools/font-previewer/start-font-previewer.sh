#!/usr/bin/env bash
# Linux/macOS terminal launcher for the Font Previewer.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8020}"

echo "Font Previewer is running at http://localhost:${PORT}/typeboards.html"
echo "Keep this terminal window open while you work."

cd "$PROJECT_DIR"
python3 -m http.server "$PORT" --bind 127.0.0.1
