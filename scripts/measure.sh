#!/bin/bash
# Measure the running app against the budget and log the result.
#   scripts/measure.sh [seconds] [state]   state: idle | walking | asleep | chat (default: 60 idle)
# Put the app in that state first (e.g. leave it alone for idle). The first WARMUP seconds
# (default 5) are ignored so a launch or a state change settles first.
# Prints one line and appends a row to docs/perf-log.md. Budgets: docs/performance.md#budget
source "$(dirname "$0")/lib.sh"

SECS=${1:-60}
STATE=${2:-idle}
WARMUP=${WARMUP:-5}
case "$STATE" in
  idle)    CPU_MAX=0.5; WAKE_MAX=1;    MEM_MAX=30 ;;
  walking) CPU_MAX=2;   WAKE_MAX=12;   MEM_MAX=30 ;;
  asleep)  CPU_MAX=0.1; WAKE_MAX=0.2;  MEM_MAX=30 ;;
  chat)    CPU_MAX=100; WAKE_MAX=1000; MEM_MAX=50 ;;
  *) echo "usage: scripts/measure.sh [seconds] [idle|walking|asleep|chat]"; exit 2 ;;
esac

pid=$(pgrep -x Aash) || { echo "MEASURE FAIL · Aash isn't running (scripts/run.sh)"; exit 1; }

# One sample a second. IDLEW is cumulative, so the rate is (last - first) / seconds.
# Samples up to and including the warm-up are skipped; that also skips the very first
# sample, whose CPU has no previous sample to compare with.
samples=$(top -l $((WARMUP + SECS + 1)) -s 1 -pid "$pid" -stats pid,cpu,idlew,mem 2>/dev/null | awk -v p="$pid" '$1 == p')
[ -n "$samples" ] || { echo "MEASURE FAIL · Aash quit while measuring"; exit 1; }

read -r cpu wake mem <<<"$(echo "$samples" | awk -v secs="$SECS" -v skip="$WARMUP" '
  function mb(v,  n, u) {
    sub(/[+-]$/, "", v); n = v + 0; u = substr(v, length(v), 1)
    if (u == "K") return n / 1024; if (u == "G") return n * 1024; if (u == "B") return n / 1048576
    return n
  }
  NR <= skip + 1 { first = $3; next }
  { cpu += $2; n++; last = $3; mem = mb($4) }
  END { printf "%.2f %.2f %.1f", (n ? cpu / n : 0), (last - first) / secs, mem }')"

verdict=pass
mark() { awk -v v="$1" -v max="$2" 'BEGIN { exit !(v <= max) }' && echo "✓" || { echo "✗"; }; }
c=$(mark "$cpu" "$CPU_MAX"); w=$(mark "$wake" "$WAKE_MAX"); m=$(mark "$mem" "$MEM_MAX")
[[ "$c$w$m" == *"✗"* ]] && verdict=FAIL

echo "MEASURE $STATE ${SECS}s · cpu ${cpu}% (≤$CPU_MAX $c) · wake-ups ${wake}/s (≤$WAKE_MAX $w) · memory ${mem} MB (≤$MEM_MAX $m) · $verdict"

LOGFILE=docs/perf-log.md
if [ -f "$LOGFILE" ]; then
  sha=$(git rev-parse --short HEAD 2>/dev/null || echo "-")
  echo "| $(date '+%Y-%m-%d %H:%M') | $sha | $STATE ${SECS}s | ${cpu}% | ${wake}/s | ${mem} MB | $verdict |" >>"$LOGFILE"
fi
[ "$verdict" = pass ]
