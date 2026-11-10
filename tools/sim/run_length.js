// Run-length variants on patched copies of the real JS engine.
// node drive.js <variant-dir> <label> -> one JSON line
const path = require('path');
const dir = process.argv[2], label = process.argv[3];
process.chdir(dir);
const S = require(path.join(dir, 'cribsim.js'));
const R = require(path.join(dir, 'cribrogue.js'));
const { CribRun, CRIB_ROUNDS, CRIB_ACTS, CRIB_DEALS } = R;
const N = +(process.env.NRUNS || 120);
const DEAL_S = 40, SHOP_S = 25;           // estimates: seconds a deal, a shop visit
function run(deck, skill) {
  const r = new CribRun(deck, null);
  let deals = 0, cleared = 0, firstSpoilerAt = null, t = 0;
  const total = CRIB_ACTS * CRIB_ROUNDS;
  for (let i = 0; i < total; i++) {
    const boss = r.round === CRIB_ROUNDS;
    if (boss && firstSpoilerAt === null) firstSpoilerAt = t;    // minutes into the run when it starts
    const rd = S.playRound(r, skill);
    const used = (CRIB_DEALS + (rd.mods.dealBonus || 0) + (rd.mods.act1Trim || 0)) - rd.dealsLeft;
    const d = Math.max(1, rd._dealsPlayed || used);
    deals += d; t += d * DEAL_S;
    if (!rd.won) break;
    cleared++;
    r.essence += rd.essenceEarned;
    S.shop(r); r.shopState = null; t += SHOP_S;
    if (r.advance()) break;
  }
  return { deals, cleared, total, won: cleared >= total, firstSpoilerAt, secs: t };
}
const out = {};
for (const skill of ['best', 'naive']) {
  let deals = 0, cleared = 0, won = 0, reachSp = 0, spT = 0, secs = 0, n = 0, total = 0;
  for (const d of ['pip', 'thump', 'clover', 'facet']) for (let i = 0; i < N; i++) {
    const x = run(d, skill); n++; total = x.total;
    deals += x.deals; cleared += x.cleared; won += x.won ? 1 : 0; secs += x.secs;
    if (x.firstSpoilerAt !== null) { reachSp++; spT += x.firstSpoilerAt; }
  }
  out[skill] = { runs: n, avg_rounds_cleared: +(cleared / n).toFixed(1), of: total,
    clear_pct: +(100 * won / n).toFixed(1), reach_first_spoiler_pct: +(100 * reachSp / n).toFixed(1),
    min_to_first_spoiler: reachSp ? +(spT / reachSp / 60).toFixed(1) : null,
    avg_run_min: +(secs / n / 60).toFixed(1) };
}
console.log(JSON.stringify({ variant: label, ...out }));
