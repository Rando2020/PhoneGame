#!/bin/sh
# Run-length variants on patched copies of the real JS engine (web/), nothing
# in the game changes: the game as it is (3 rounds an act, x1.29 since
# 2026-10-20) and the old 5 rounds an act at x1.19, for comparison.
# Prints one JSON line per variant (best and naive keeps).
#   tools/sim/run_length.sh [runs per deck, default 120]
N="${1:-120}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T=$(mktemp -d)
mk() { cp -r "$ROOT/web" "$T/$1"; }
mk now
mk was_5x1.19
sed -i 's/^const CRIB_ACTS = 5, CRIB_ROUNDS = 3;.*/const CRIB_ACTS = 5, CRIB_ROUNDS = 5;/' "$T/was_5x1.19/cribrogue.js"
sed -i 's/^const CRIB_LADDER = { baseTarget: 36, growth: 1.29 };.*/const CRIB_LADDER = { baseTarget: 36, growth: 1.19 };/' "$T/was_5x1.19/cribrogue.js"
sed -i 's/^const ENDLESS_FROM = 16;.*/const ENDLESS_FROM = 26;/' "$T/was_5x1.19/meta.js"
for v in now was_5x1.19; do
  NRUNS="$N" node "$ROOT/tools/sim/run_length.js" "$T/$v" "$v" &
done
wait
rm -rf "$T"
