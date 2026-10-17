#!/bin/bash
# Build Aash at low priority and assemble build/Aash.app.
#   scripts/build.sh                 debug build + signed app bundle
#   scripts/build.sh release         release build + signed app bundle
#   scripts/build.sh --target NAME   compile one target only (no app bundle)
# Prints one result line (plus the first errors or warnings). Full log: build/logs/build.log
source "$(dirname "$0")/lib.sh"

CONFIG=debug
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    debug | release) CONFIG=$1 ;;
    --target) TARGET=${2:?--target needs a name}; shift ;;
    *) echo "usage: scripts/build.sh [debug|release] [--target NAME]"; exit 2 ;;
  esac
  shift
done

LOG=build/logs/build.log
start=$(date +%s)
args=(build -c "$CONFIG" -j "$JOBS")
[ -n "$TARGET" ] && args+=(--target "$TARGET")

if ! swift_calm "${args[@]}" >"$LOG" 2>&1; then
  echo "BUILD FAIL ($CONFIG${TARGET:+, $TARGET}) · $(elapsed "$start") · log: $LOG"
  errors=$(diagnostics "$LOG" error)
  if [ -n "$errors" ]; then
    echo "$errors" | head -20
  else
    clean <"$LOG" | grep -vE "$NOISE" | tail -15
  fi
  exit 1
fi

warnings=$(diagnostics "$LOG" warning)
summary="$(elapsed "$start") · $(count_lines "$warnings") warning(s)"

if [ -n "$TARGET" ]; then
  echo "BUILD OK ($CONFIG, $TARGET) · $summary"
  [ -n "$warnings" ] && echo "$warnings" | head -10
  exit 0
fi

# Assemble the app bundle from the SwiftPM binary.
BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)
APP=build/Aash.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Aash" "$APP/Contents/MacOS/Aash"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Sign with the stable local certificate so macOS keeps granted permissions
# between builds; fall back to ad-hoc. See docs/WORKFLOW.md#signing
IDENTITY="Aash Local"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1 &&
  codesign --force --sign "$IDENTITY" "$APP" >>"$LOG" 2>&1; then
  signed=$IDENTITY
elif codesign --force --sign - "$APP" >>"$LOG" 2>&1; then
  signed="ad-hoc (macOS may re-ask for permissions after each build)"
else
  echo "BUILD FAIL (signing) · log: $LOG"
  exit 1
fi

echo "BUILD OK ($CONFIG) · $summary · $APP · signed: $signed"
[ -n "$warnings" ] && echo "$warnings" | head -10
exit 0
