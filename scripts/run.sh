#!/bin/bash
# Quit any running Aash, build the debug app, and open it.
#   scripts/run.sh             build, then run
#   scripts/run.sh --no-build  run the last build
source "$(dirname "$0")/lib.sh"

if [ "${1:-}" != "--no-build" ]; then
  out=$("$ROOT/scripts/build.sh") || { echo "$out"; exit 1; }
fi
[ -d build/Aash.app ] || { echo "RUN FAIL · no build/Aash.app yet (run scripts/build.sh)"; exit 1; }

if pgrep -x Aash >/dev/null; then
  pkill -x Aash
  sleep 0.5
fi
open build/Aash.app

pid=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pid=$(pgrep -x Aash) && break
  sleep 0.3
done
if [ -n "$pid" ]; then
  echo "RUNNING · pid $pid · look at your menu bar"
else
  echo "RUN FAIL · Aash did not start. Open Console.app and search for Aash."
  exit 1
fi
