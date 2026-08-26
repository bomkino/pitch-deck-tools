#!/bin/zsh
set -euo pipefail

APP_DIR="${0:A:h}"
PACKAGE_DIR="$APP_DIR/macos"
SUPPORT_DIR="$PACKAGE_DIR/Support"
INSTALL_APP=1
RUN_TESTS=1

while (( $# )); do
  case "$1" in
    --no-install) INSTALL_APP=0 ;;
    --skip-tests) RUN_TESTS=0 ;;
    *)
      echo "Usage: ${0:t} [--no-install] [--skip-tests]" >&2
      exit 64
      ;;
  esac
  shift
done

for tool in swift xcrun codesign ditto plutil iconutil shasum unzip file; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required macOS build tool: $tool" >&2
    exit 69
  fi
done

ARCHITECTURE="$(uname -m)"
case "$ARCHITECTURE" in
  arm64|x86_64) ;;
  *) echo "Unsupported macOS architecture: $ARCHITECTURE" >&2; exit 69 ;;
esac

TEMP_BASE="${TMPDIR:-/tmp}"
TEMP_BASE="${TEMP_BASE%/}"
BUILD_ROOT="$(mktemp -d "$TEMP_BASE/font-previewer-build.XXXXXX")"
INSTALL_STAGING=""

cleanup() {
  if [[ -n "$INSTALL_STAGING" && "$INSTALL_STAGING" == /Applications/.Font\ Previewer.install.* && -e "$INSTALL_STAGING" ]]; then
    rm -rf -- "$INSTALL_STAGING"
  fi
  if [[ -n "$BUILD_ROOT" && "$BUILD_ROOT" == "$TEMP_BASE"/font-previewer-build.* && -d "$BUILD_ROOT" ]]; then
    rm -rf -- "$BUILD_ROOT"
  fi
}
trap cleanup EXIT

if (( RUN_TESTS )); then
  swift test --package-path "$PACKAGE_DIR"
  swift run --package-path "$PACKAGE_DIR" -c release FontPreviewerSmoke --output "$BUILD_ROOT/smoke"
fi

SCRATCH="$BUILD_ROOT/swift-build"
swift build \
  --package-path "$PACKAGE_DIR" \
  --scratch-path "$SCRATCH" \
  -c release \
  --product FontPreviewer
BIN_PATH="$(swift build --package-path "$PACKAGE_DIR" --scratch-path "$SCRATCH" -c release --show-bin-path)"
EXECUTABLE="$BIN_PATH/FontPreviewer"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Swift did not produce the FontPreviewer executable." >&2
  exit 70
fi

BUNDLE="$BUILD_ROOT/Font Previewer.app"
CONTENTS="$BUNDLE/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
ditto "$EXECUTABLE" "$CONTENTS/MacOS/FontPreviewer"
cp "$SUPPORT_DIR/Info.plist" "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist" >/dev/null

ICONSET="$BUILD_ROOT/FontPreviewer.iconset"
xcrun swift "$SUPPORT_DIR/make_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/FontPreviewer.icns"

codesign --force --sign - --identifier dog.pitch.fontpreviewer "$BUNDLE"
codesign --verify --deep --strict --verbose=2 "$BUNDLE"

ARTIFACT_DIR="$APP_DIR/output/macos"
mkdir -p "$ARTIFACT_DIR"
ARCHIVE_TEMP="$BUILD_ROOT/Font Previewer.zip"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ARCHIVE_TEMP"
unzip -tq "$ARCHIVE_TEMP" >/dev/null
ditto "$ARCHIVE_TEMP" "$ARTIFACT_DIR/Font Previewer.zip"
shasum -a 256 "$ARTIFACT_DIR/Font Previewer.zip" > "$ARTIFACT_DIR/Font Previewer.zip.sha256"

VERIFY_DIR="$BUILD_ROOT/verify"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ARTIFACT_DIR/Font Previewer.zip" "$VERIFY_DIR"
VERIFY_APP="$VERIFY_DIR/Font Previewer.app"
test -x "$VERIFY_APP/Contents/MacOS/FontPreviewer"
plutil -lint "$VERIFY_APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$VERIFY_APP"

if (( INSTALL_APP )); then
  INSTALL_TARGET="/Applications/Font Previewer.app"
  if [[ -L "$INSTALL_TARGET" ]]; then
    echo "Refusing to replace symlink at $INSTALL_TARGET" >&2
    exit 73
  fi
  if pgrep -f '^/Applications/Font Previewer\.app/Contents/MacOS/FontPreviewer([[:space:]]|$)' >/dev/null 2>&1; then
    echo "Quit the installed Font Previewer app, then run this builder again." >&2
    exit 75
  fi

  INSTALL_STAGING="/Applications/.Font Previewer.install.$$"
  if [[ -e "$INSTALL_STAGING" ]]; then
    echo "Unexpected install staging path already exists: $INSTALL_STAGING" >&2
    exit 73
  fi
  if ! ditto "$BUNDLE" "$INSTALL_STAGING"; then
    echo "Could not write to /Applications. The ZIP remains in $ARTIFACT_DIR" >&2
    exit 73
  fi
  codesign --verify --deep --strict --verbose=2 "$INSTALL_STAGING"

  BACKUP=""
  if [[ -e "$INSTALL_TARGET" ]]; then
    BACKUP="/Applications/Font Previewer.backup-$(date +%Y%m%d-%H%M%S).app"
    mv "$INSTALL_TARGET" "$BACKUP"
  fi
  if ! mv "$INSTALL_STAGING" "$INSTALL_TARGET"; then
    if [[ -n "$BACKUP" && ! -e "$INSTALL_TARGET" && -e "$BACKUP" ]]; then mv "$BACKUP" "$INSTALL_TARGET"; fi
    echo "Install failed; the previous app was restored when present." >&2
    exit 73
  fi
  INSTALL_STAGING=""
  codesign --verify --deep --strict --verbose=2 "$INSTALL_TARGET"
  echo "Installed: $INSTALL_TARGET"
  [[ -n "$BACKUP" ]] && echo "Previous app preserved: $BACKUP"
fi

echo "Packaged: $ARTIFACT_DIR/Font Previewer.zip"
echo "Checksum: $ARTIFACT_DIR/Font Previewer.zip.sha256"
echo "Ad-hoc signed for local use. Not notarized."
