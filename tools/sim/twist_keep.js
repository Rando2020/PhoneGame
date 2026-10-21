/* Twist playtest proxy (pass 16): how often a twist changes the best keep.
   For each twist, N deals (default 2000): a plain round-1 deal, then the
   same six cards and stock under the twist's rules. "Changed" means the
   plain best keep is no longer best under the twist (its expected hand score
   is below the twisted best by more than 1e-9, so ties don't count).
   The keep's value is the game's own keepOptionsEV: the hand's expected
   count over the cut. It ignores the Crib and mulligans, so twists that act
   there score 0 here by construction (said in the output).
     node tools/sim/twist_keep.js [deals per twist]                       */
const path = require("path");
const WEB = path.join(__dirname, "..", "..", "web");
global.SUIT_SYM = { S: "♠", H: "♥", C: "♣", D: "♦" };
const C = require(path.join(WEB, "cribbage.js"));
Object.assign(global, { countHand: C.countHand, countPoints: C.countPoints, keepOptions: C.keepOptions,
  keepEVFast: C.keepEVFast, keepOptionsEV: C.keepOptionsEV, cDeck: C.cDeck, cShuf: C.cShuf });
const R = require(path.join(WEB, "cribrogue.js"));
const M = require(path.join(WEB, "meta.js"));
if (!global.makeRng && M.makeRng) global.makeRng = M.makeRng;
const N = +(process.argv[2] || 2000);
const DECKS = Object.keys(R.CRIB_DECKS);
const key = (idx) => idx.slice().sort((a, b) => a - b).join(",");
const out = [];
for (const tw of R.CRIB_TWISTS) {
  let changed = 0, gain = 0, n = 0;
  for (let i = 0; n < N; i++) {
    const run = new R.CribRun(DECKS[i % DECKS.length], undefined, undefined, 90000 + i);
    run.wagerAt = {};
    run.round = 1;
    run.twistPlan = {};
    const rd = new R.CribRound(run);
    if (!rd.newDeal || rd.newDeal() === null) continue;
    const k = rd.keepCount();
    const plain = C.keepOptionsEV(rd.dealt, rd.stock, k, rd.mods)[0];
    run.twistPlan = { "1-1": tw.id };
    const mods2 = run.rules();
    const opts2 = C.keepOptionsEV(rd.dealt, rd.stock, k, mods2);
    const plainUnder = opts2.find((o) => key(o.idx) === key(plain.idx));
    if (opts2[0].ev > plainUnder.ev + 1e-9) { changed++; gain += opts2[0].ev - plainUnder.ev; }
    n++;
  }
  out.push({ twist: tw.id, name: tw.name, deals: n, changed_pct: +(100 * changed / n).toFixed(1),
             avg_ev_gain_when_changed: changed ? +(gain / changed).toFixed(2) : 0 });
}
for (const o of out) console.log(JSON.stringify(o));
console.log("note: keep value is the hand's EV over the cut; Crib and mulligan effects are not in it");
