// Recycling-sensitive balance: Facet (thin deck) and the Thirteen trial (13-card
// deck, recycles constantly). Thirteen isn't reachable via cribsim.fullRun, so
// this drives playRound/shop directly with the trial attached.
// usage: N=1200 node web/recycle_sweep.js
const R = require("./cribrogue.js");
const M = require("./meta.js");
const { playRound, shop } = require("./cribsim.js");
const N = +(process.env.N || 1200);
function one(deck, trial) {
  const run = new R.CribRun(deck, null, trial || null);
  let reached = 0, recycles = 0, rounds = 0;
  for (let i = 0; i < 25; i++) {
    const rd = playRound(run, "best"); rounds++;
    recycles += (rd.cycle || 1) - 1;
    if (!rd.won) return { reached, recycles, rounds };
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    if (!(trial && trial.mods.noShop)) { shop(run); run.shopState = null; }
    if (run.advance()) break;
  }
  return { reached: 25, recycles, rounds };
}
const out = {};
for (const [name, deck, trial] of [["facet", "facet", null], ["thirteen", "facet", M.TRIALS.find((t) => t.id === "thirteen")]]) {
  let cl = 0, sr = 0, rc = 0, rr = 0;
  for (let i = 0; i < N; i++) { const r = one(deck, trial); if (r.reached >= 25) cl++; sr += r.reached; rc += r.recycles; rr += r.rounds; }
  const p = cl / N;
  out[name] = { clear: +(100 * p).toFixed(1), ci95: +(196 * Math.sqrt(p * (1 - p) / N)).toFixed(1),
                reached: +(sr / N).toFixed(2), recyclesPerRound: +(rc / rr).toFixed(2) };
}
console.log(JSON.stringify(out));
