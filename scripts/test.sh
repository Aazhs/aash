#!/bin/bash
# Run the Swift Testing suites at low priority.
#   scripts/test.sh                   all tests
#   scripts/test.sh --filter PATTERN  only tests whose name matches, e.g. --filter BehaviourEngineTests
#                                     (still builds every test target)
# Prints one result line plus failures. Full log: build/logs/test.log
source "$(dirname "$0")/lib.sh"

args=(-j "$JOBS")
case "${1:-}" in
  --filter) args+=(--filter "${2:?--filter needs a pattern}") ;;
  "") ;;
  *) echo "usage: scripts/test.sh [--filter PATTERN]"; exit 2 ;;
esac

LOG=build/logs/test.log
start=$(date +%s)
swift_calm test "${args[@]}" >"$LOG" 2>&1
status=$?

# Safety net for the toolchain quirk described in lib.sh: one retry fixes it.
if [ $status -ne 0 ] && grep -q "plugin for module 'TestingMacros' not found" "$LOG"; then
  swift_calm test "${args[@]}" >"$LOG" 2>&1
  status=$?
fi

out=$(clean <"$LOG")
total=$(echo "$out" | grep -oE 'Test run with [0-9]+ test' | grep -oE '[0-9]+' | awk '{ s += $1 } END { print s + 0 }')

if [ $status -eq 0 ]; then
  echo "TESTS PASS · $total test(s) · $(elapsed "$start")"
  exit 0
fi

echo "TESTS FAIL · $(elapsed "$start") · log: $LOG"
errors=$(diagnostics "$LOG" error)
failures=$(echo "$out" | grep -E '✘' | grep -v 'Test run with')
if [ -n "$errors" ]; then
  echo "$errors" | head -20
elif [ -n "$failures" ]; then
  echo "$failures" | head -20
else
  echo "$out" | grep -vE "$NOISE" | tail -15
fi
exit 1
