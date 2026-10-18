// Forced-build balance sweep: start runs with chosen charms already owned and
// report clear rate (95% CI), mean round reached, and run-end Glim and deck size.
// Reuses cribsim's playRound/shop, so policy matches web/deck_sweep.js.
// usage: N=400 DECK=pip BUILDS="none;cutpurse;usury;collector;cutpurse+thebank" node web/forced_sweep.js
const R = require("./cribrogue.js");
const { playRound, shop } = require("./cribsim.js");
const { CribRun, CCHARMS } = R;
const N = +(process.env.N || 400), DECK = process.env.DECK || "pip";
const builds = (process.env.BUILDS || "none;cutpurse;usury;collector;cutpurse+thebank").split(";");
function run1(ids) {
  const run = new CribRun(DECK, null);
  for (const id of ids) { const c = CCHARMS.find((x) => x.id === id); run.charms.push(c); if (c.onAcquire) c.onAcquire(run); }
  let reached = 0, peakGlim = 0;
  for (let i = 0; i < 25; i++) {
    const rd = playRound(run, "best");
    peakGlim = Math.max(peakGlim, run.essence);
    if (!rd.won) return { reached, glim: run.essence, peakGlim, deck: run.cards.length };
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    shop(run); run.shopState = null;
    if (run.advance()) break;
  }
  return { reached: 25, glim: run.essence, peakGlim, deck: run.cards.length };
}
const out = {};
const t0 = Date.now();
for (const b of builds) {
  const ids = b === "none" ? [] : b.split("+");
  let cl = 0, sr = 0, sg = 0, sp = 0, sd = 0;
  for (let i = 0; i < N; i++) { const r = run1(ids); if (r.reached >= 25) cl++; sr += r.reached; sg += r.glim; sp += r.peakGlim; sd += r.deck; }
  const p = cl / N;
  out[b] = { clear: +(100 * p).toFixed(1), ci95: +(196 * Math.sqrt(p * (1 - p) / N)).toFixed(1), reached: +(sr / N).toFixed(2),
             endGlim: +(sg / N).toFixed(1), peakGlim: +(sp / N).toFixed(1), deck: +(sd / N).toFixed(1) };
}
console.log(JSON.stringify(out));
console.error(`(${DECK}, ${N} runs/build, ${Date.now() - t0} ms)`);
