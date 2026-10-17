#!/bin/bash
# Build a release copy, install it to ~/Applications/Aash.app, and open it.
# Use this for the copy you live with; scripts/run.sh is for development builds.
source "$(dirname "$0")/lib.sh"

out=$("$ROOT/scripts/build.sh" release) || { echo "$out"; exit 1; }
DEST="$HOME/Applications/Aash.app"
mkdir -p "$HOME/Applications"
pkill -x Aash 2>/dev/null && sleep 0.5
rm -rf "$DEST"
cp -R build/Aash.app "$DEST"
open "$DEST"
echo "INSTALLED · $DEST · ${out#BUILD OK }"
