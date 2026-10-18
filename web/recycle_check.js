// Card conservation through recycles: no card may exist in more copies than the
// round started with. usage: node web/recycle_check.js [path/to/cribrogue.js]
const path = require("path");
const crPath = path.resolve(process.argv[2] || path.join(__dirname, "cribrogue.js"));
global.SUIT_SYM = {};
const M = require(path.join(__dirname, "meta.js")); Object.assign(global, M, require(path.join(__dirname, "cribbage.js")));
const { CribRun, CribRound, CCHARMS } = require(crPath);
const key = (c) => c.rank + c.suit + (c.enh || "") + (c.rank2 || "");
const tally = (cards) => { const t = {}; for (const c of cards) if (c) t[key(c)] = (t[key(c)] || 0) + 1; return t; };
let checks = 0, fails = 0, recycles = 0, missing = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 8) console.log("FAIL", m); } };
const thirteen = M.TRIALS.find((t) => t.id === "thirteen");
for (let seed = 1; seed <= 60; seed++) {
  const trial = seed % 2 ? thirteen : null;
  const run = new CribRun("facet", null, trial, seed);
  if (seed % 3 === 0) run.charms.push(CCHARMS.find((c) => c.id === "doublecut"));
  const rd = new CribRound(run);
  const start = tally(rd.stock);
  let deal = 0;
  while (!rd.over && deal++ < 40) {
    const before = rd.cycle;
    if (!rd.newDeal()) break;
    if (rd.cycle > before) recycles++;
    if (deal % 4 === 1) rd.mulligan();
    const held = rd.phase === "keep" ? rd.dealt.concat(rd.starter ? [rd.starter] : [], rd.starter2 ? [rd.starter2] : []) : [];
    const now = tally(rd.stock.concat(rd.used, rd.burned || [], rd.crib, held));
    for (const k in now) ok(now[k] <= (start[k] || 0), `seed ${seed} deal ${deal} cycle ${rd.cycle}: ${k} x${now[k]}, round started with ${start[k] || 0}`);
    let total = 0; for (const k in start) total += start[k]; let have = 0; for (const k in now) have += now[k];
    if (have < total) missing = Math.max(missing, total - have);
    rd.commit(rd.bestKeepEV().idx);
    rd.dealsLeft = Math.max(rd.dealsLeft, 2);   // keep dealing so the deck cycles
  }
}
ok(missing === 0, `up to ${missing} cards dropped out of circulation (Double Cut's second starter?)`);
console.log(`conservation checks: ${checks}, failures: ${fails}, recycles exercised: ${recycles}, most cards out of circulation at once: ${missing}`);
console.log(fails === 0 && checks > 500 && recycles > 20 ? "RECYCLE OK" : "RECYCLE FAILED");
process.exit(fails === 0 && checks > 500 && recycles > 20 ? 0 : 1);
