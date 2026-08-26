#!/bin/zsh
set -euo pipefail
APP_DIR="${0:A:h}"
cd "$APP_DIR/macos"
exec swift run FontPreviewer
