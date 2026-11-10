// Round the Bend: runs wrap K-A-2 with the charm, and nothing changes without it.
// usage: node web/wrap_check.js [web-folder]
const path = require("path"); const dir = path.resolve(process.argv[2] || __dirname);
global.SUIT_SYM = {}; Object.assign(global, require(path.join(dir, "cribbage.js")));
let checks = 0, fails = 0; const ok = (c, m) => { checks++; if (!c) { fails++; console.log("FAIL", m); } };
const H = (s) => s.split(" ").map((t) => ({ rank: { A: 1, J: 11, Q: 12, K: 13 }[t.slice(0, -1)] || +t.slice(0, -1), suit: t.slice(-1) }));
const runs = (hand, st, mods) => countHand(H(hand), st && H(st)[0], false, mods).events.filter((e) => e.kind === "run").map((e) => e.label + "=" + e.points);
const W = { wrapRuns: true };
const cases = [
  ["QS KH AC 7D", "9S", ["Run of 3=3"], []],                 // Q-K-A
  ["KS AH 2C 8D", "5S", ["Run of 3=3"], []],                 // K-A-2
  ["QS KH AC 2D", "8S", ["Run of 4=4"], []],                 // Q-K-A-2
  ["JS QH KC AD", "2S", ["Run of 5=5"], ["Run of 3=3"]],      // J-Q-K + A-2 merge, not double count
  ["QS KH AC AD", "9S", ["2 runs of 3=6"], []],              // multiplicity across the bend
  ["3S 4H 5C 9D", "KS", ["Run of 3=3"], ["Run of 3=3"]],      // no bend: unchanged
  ["KS AH 7C 8D", "2S", ["Run of 3=3"], []],                 // starter completes the bend
  ["QS KH 5C 6D", "AS", ["Run of 3=3"], []],
];
for (const [h, st, withW, without] of cases) {
  ok(JSON.stringify(runs(h, st, W)) === JSON.stringify(withW), `${h} | ${st} with wrap: ${runs(h, st, W)} want ${withW}`);
  ok(JSON.stringify(runs(h, st, {})) === JSON.stringify(without), `${h} | ${st} without: ${runs(h, st, {})} want ${without}`);
}
// a crib needs no special handling; runNeed applies across the bend
ok(JSON.stringify(runs("KS AH 7C 9D", "4S", { wrapRuns: true, runNeed: 2 })) === JSON.stringify(["Run of 2=2"]), "runNeed 2 across the bend");
console.log(`wrap checks: ${checks}, failures: ${fails}`); console.log(fails === 0 && checks >= 17 ? "WRAP OK" : "WRAP FAILED");
process.exit(fails === 0 && checks >= 17 ? 0 : 1);
