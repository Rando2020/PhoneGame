#!/bin/sh
# The soak: SOAK_RUNS full runs (default 200) through RunFlow, then fail on
# any script error in the log (GDScript can't catch its own errors).
#   tools/soak.sh [runs]
RUNS="${1:-200}"
LOG="/tmp/soak_${RUNS}_$$.log"
cd "$(dirname "$0")/../godot" || exit 2
SOAK_RUNS="$RUNS" SOAK_STRONG="${SOAK_STRONG:-0}" SOAK_FREE="${SOAK_FREE:-0}" godot --headless --path . --script res://tests/soak_test.gd > "$LOG" 2>&1
CODE=$?
# any script or engine error, except the exit-time leak/resource notes
ERRS=$(grep -E "SCRIPT ERROR|^ERROR" "$LOG" | grep -vcE "resources still in use at exit|ObjectDB instances leaked")
grep -E "^soak|FAIL" "$LOG"
grep -E "SCRIPT ERROR|^ERROR" "$LOG" | grep -vE "resources still in use at exit|ObjectDB instances leaked" | sort | uniq -c | head -5
echo "errors: $ERRS"
[ "$CODE" -eq 0 ] && [ "$ERRS" -eq 0 ]
