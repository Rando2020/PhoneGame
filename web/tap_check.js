// The Daily can't depend on HOW a player looks at their cards. Play the same
// Daily twice, same choices, same Math.random state; the only difference is how
// many hypothetical counts happen (previews, cut quality, auto-sort, coaching).
// Outcomes must be identical. usage: node web/tap_check.js [web-folder]
const path = require("path"), fs = require("fs");
const dir = path.resolve(process.argv[2] || __dirname);
if (!fs.statSync(dir).isDirectory()) { console.log("pass a web FOLDER"); process.exit(2); }
global.SUIT_SYM = {};
const M = require(path.join(dir, "meta.js")); Object.assign(global, M, require(path.join(dir, "cribbage.js")));
const R = require(path.join(dir, "cribrogue.js"));
const DECKS = ["pip", "thump", "clover", "facet"];
let checks = 0, fails = 0, fickleCounted = 0, brittleCounted = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 5) console.log("FAIL", m); } };
function play(seed, taps) {
  Math.random = makeRng(7);                       // identical for both plays
  const run = new R.CribRun(DECKS[seed % 4], M.STREETS[0], null, seed);
  run.cards.forEach((c, i) => { if (i % 3 === 0) c.enh = "lucky"; else if (i % 5 === 0) c.enh = "glass"; });
  run.charms = ["keystone2", "ballast"].map((id) => R.CCHARMS.find((c) => c.id === id));
  const trace = [];
  for (let r = 0; r < 4; r++) {
    const rd = new R.CribRound(run);
    while (!rd.over) {
      if (!rd.newDeal()) break;
      const best = rd.bestKeepEV(), kept = best.idx.map((i) => rd.dealt[i]);
      for (let t = 0; t < taps; t++) { rd.preview(best.idx); run.bestOrder(rd, kept); }
      const res = rd.commit(best.idx);
      for (let t = 0; t < taps; t++) { rd.cutQuality(kept, rd.starter); rd.bestKeep(); }
      for (const c of kept.concat([rd.starter])) { if (c.enh === "lucky") fickleCounted++; if (c.enh === "glass") brittleCounted++; }
      trace.push([res.total, res.shattered.length, run.cards.length]);
    }
    if (!rd.over) rd.settle();
    trace.push(["round", rd.score, rd.won]);
    run.round++;
  }
  return JSON.stringify(trace);
}
for (let seed = 1; seed <= 60; seed++) {
  const quiet = play(seed, 0), busy = play(seed, 3);
  ok(quiet === busy, `seed ${seed}: extra looks changed the outcome`);
}
console.log(`tap checks: ${checks}, failures: ${fails}, Fickle cards counted: ${fickleCounted}, Brittle: ${brittleCounted}`);
const good = fails === 0 && checks >= 60 && fickleCounted > 100 && brittleCounted > 50;
console.log(good ? "TAP OK" : "TAP FAILED");
process.exit(good ? 0 : 1);
