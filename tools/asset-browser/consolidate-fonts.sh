#!/usr/bin/env bash
# Linux/macOS terminal launcher for collecting project fonts.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "$PROJECT_DIR/_index/_scripts/consolidate_fonts.py"
