// Clear rate (with 95% CI) and mean round reached per Meldling, via cribsim.fullRun.
// usage: N=400 DECKS=pip,clover node web/deck_sweep.js   (~25 s per deck at N=400)
const { fullRun } = require("./cribsim.js");
const N = +(process.env.N || 400);
const decks = (process.env.DECKS || "pip,thump,clover,facet,clover_asc").split(",");
const t0 = Date.now(); const out = {};
for (const d of decks) {
  let cl = 0, sum = 0;
  for (let i = 0; i < N; i++) { const r = fullRun(d); sum += r.reached; if (r.reached >= 25) cl++; }
  const p = cl / N, se = Math.sqrt(p * (1 - p) / N);
  out[d] = { clear: +(100 * p).toFixed(1), ci95: +(196 * se).toFixed(1), reached: +(sum / N).toFixed(2) };
}
console.log(JSON.stringify(out)); console.error(`(${N} runs/deck, ${Date.now() - t0} ms)`);
