#!/bin/bash
# The one command that decides "done": build, then tests. Three short lines.
#   scripts/check.sh                 everything; a card is done only when this passes
#   scripts/check.sh --target NAME   compile one library only (AashSprites, AashCore or AashAI).
#                                    For parallel cards while they work: another card's
#                                    half-finished module can't break it. Runs no tests.
source "$(dirname "$0")/lib.sh"

start=$(date +%s)
if [ "${1:-}" = "--target" ]; then
  T=${2:?--target needs a name}
  "$ROOT/scripts/build.sh" --target "$T" || { echo "CHECK FAIL · build ($T)"; exit 1; }
  echo "CHECK PASS (build only, $T) · $(elapsed "$start") · the full scripts/check.sh still decides done"
  exit 0
fi

"$ROOT/scripts/build.sh" || { echo "CHECK FAIL · build"; exit 1; }
"$ROOT/scripts/test.sh" || { echo "CHECK FAIL · tests"; exit 1; }
echo "CHECK PASS · $(elapsed "$start")"
