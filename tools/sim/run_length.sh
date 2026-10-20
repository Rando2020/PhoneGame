#!/bin/sh
# Run-length variants on patched copies of the real JS engine (web/), nothing
# in the game changes: today's 5 rounds an act, and 3 rounds an act at several
# target growths. Prints one JSON line per variant (best and naive keeps).
#   tools/sim/run_length.sh [runs per deck, default 120]
N="${1:-120}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T=$(mktemp -d)
mk() { cp -r "$ROOT/web" "$T/$1"; }
mk today
for g in 1.25 1.29 1.31; do
  mk "r3_$g"
  sed -i 's/^const CRIB_ACTS = 5, CRIB_ROUNDS = 5;/const CRIB_ACTS = 5, CRIB_ROUNDS = 3;/' "$T/r3_$g/cribrogue.js"
  sed -i "s/^const CRIB_LADDER = { baseTarget: 36, growth: 1.19 };/const CRIB_LADDER = { baseTarget: 36, growth: $g };/" "$T/r3_$g/cribrogue.js"
done
for v in today r3_1.25 r3_1.29 r3_1.31; do
  NRUNS="$N" node "$ROOT/tools/sim/run_length.js" "$T/$v" "$v" &
done
wait
rm -rf "$T"
