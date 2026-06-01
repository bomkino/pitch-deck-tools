#!/usr/bin/env bash
# Linux/macOS terminal launcher for the Asset Browser.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$PROJECT_DIR/_index/index.html" ]; then
  echo "First run: building the asset index..."
  python3 "$PROJECT_DIR/_index/_scripts/index_assets.py"
fi

exec python3 "$PROJECT_DIR/_index/_scripts/server.py"
