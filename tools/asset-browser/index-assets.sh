#!/usr/bin/env bash
# Linux/macOS terminal launcher for rebuilding the Asset Browser index.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "$PROJECT_DIR/_index/_scripts/index_assets.py"
