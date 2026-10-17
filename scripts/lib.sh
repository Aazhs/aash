# Shared helpers for the scripts in this folder. Source it; don't run it.
# Written for macOS's built-in bash 3.2.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
mkdir -p build/logs

JOBS="${JOBS:-4}"             # parallel compile jobs; lower = calmer Mac, slower build
QOS="${BUILD_QOS:-utility}"   # utility (default) or background (calmest, slowest)

# With only the Command Line Tools installed, SwiftPM sometimes drops Swift
# Testing's macro plugin and test builds fail with "plugin for module
# 'TestingMacros' not found". Passing the plugin path on every command keeps
# builds consistent. See docs/decisions.md (2026-10-18).
TESTING_PLUGINS="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing"
SWIFT_FLAGS=()
[ -d "$TESTING_PLUGINS" ] && SWIFT_FLAGS=(-Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS")

# Run a swift subcommand at low priority so builds yield the CPU to whatever you're doing.
swift_calm() {
  local cmd=$1
  shift
  taskpolicy -c "$QOS" swift "$cmd" ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} "$@"
}

# Strip colour codes and the repo prefix so output is short and plain.
clean() { sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g' | sed "s|$ROOT/||g"; }

# Harmless linker noise from the Command Line Tools install.
NOISE='search path .*CommandLineTools/Developer.* not found'

# Unique compiler diagnostics from a log. $1 = log file, $2 = error | warning
diagnostics() {
  clean <"$1" | grep -E "^[^ ].*\.swift:[0-9]+:[0-9]+: $2:" | grep -vE "$NOISE" | sort -u
}

# Lines in $1 that aren't empty, as a number.
count_lines() { printf '%s' "$1" | grep -c . || true; }

elapsed() { echo "$(( $(date +%s) - $1 ))s"; }
