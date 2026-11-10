// Balance decisions: Clover Ascended's Mimic joins the largest suit under
// flushPairs; Usury is x2. usage: node web/balance_check.js [web-folder]
const path = require("path"); const dir = path.resolve(process.argv[2] || __dirname);
global.SUIT_SYM = {}; const M = require(path.join(dir, "meta.js")); Object.assign(global, M, require(path.join(dir, "cribbage.js")));
const R = require(path.join(dir, "cribrogue.js"));
let checks = 0, fails = 0; const ok = (c, m) => { checks++; if (!c) { fails++; console.log("FAIL", m); } };
const fp = { flushNeed: 2, flushPairs: true };
const flushPts = (h, st) => countHand(h, st, false, fp).events.filter((e) => e.kind === "flush").reduce((a, e) => a + e.points, 0);
// 3 hearts + a Mimic spade, club starter: hearts group becomes 4 -> 6 pairs = 12
ok(flushPts([{ rank: 2, suit: "H" }, { rank: 4, suit: "H" }, { rank: 9, suit: "H" }, { rank: 12, suit: "S", enh: "chameleon" }], { rank: 6, suit: "C" }) === 12, "Mimic joins the 3-heart group (12)");
// without the Mimic mark, the spade pairs with nothing: 3 hearts = 3 pairs = 6
ok(flushPts([{ rank: 2, suit: "H" }, { rank: 4, suit: "H" }, { rank: 9, suit: "H" }, { rank: 12, suit: "S" }], { rank: 6, suit: "C" }) === 6, "plain card unchanged (6)");
// two Mimics both join the largest group (2 diamonds -> 4 -> 6 pairs = 12)
ok(flushPts([{ rank: 2, suit: "D" }, { rank: 5, suit: "D" }, { rank: 8, suit: "S", enh: "chameleon" }, { rank: 9, suit: "C", enh: "chameleon" }], { rank: 13, suit: "H" }) === 12, "two Mimics join the diamonds (12)");
const usury = R.CCHARMS.find((c) => c.id === "usury");
const ctx = { mult: 1, essence: 10 }; usury.onCount(ctx);
ok(ctx.mult === 2 && ctx.essence === 6, `Usury is x2 and -4 Glim (got x${ctx.mult}, ${ctx.essence})`);
ok(/x2 mult/.test(usury.text), "Usury's text says x2");
console.log(`balance checks: ${checks}, failures: ${fails}`); console.log(fails === 0 ? "BALANCE OK" : "BALANCE FAILED"); process.exit(fails ? 1 : 0);
