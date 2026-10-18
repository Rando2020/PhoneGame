// Run from the repo root: node web/sims/crib_twice_sim.js "$PWD/web" <once|twice> <meldling> <N>
// Clear rate and average round reached, with the Crib paid once (engine) vs
// twice (the web's round-end screen). Same seeds for both arms.
const path = require("path");
const WEB = process.argv[2];
const MODE = process.argv[3];            // "once" | "twice"
const DECK = process.argv[4];
const N = +process.argv[5];
process.env.NRUNS = "1";
const sim = require(path.join(WEB, "cribsim.js"));
const R = require(path.join(WEB, "cribrogue.js"));
const { makeRng } = require(path.join(WEB, "meta.js"));
const { CribRun, CribRound, CRIB_DEALS } = R;
const M = require(path.join(WEB, "meta.js"));
Object.assign(global, M);
function playRound(run) {
  const rd = new CribRound(run);
  while (rd.dealsLeft > 0) {
    if (!rd.newDeal()) break;
    let best = rd.bestKeepEV();
    if (rd.mulligansLeft > 0 && rd.stock.length > rd.needed() + 8) {
      const pace = rd.target / Math.max(1, CRIB_DEALS + rd.mods.dealBonus);
      if (best.ev * 3 < pace * 0.45) { rd.mulligan(); best = rd.bestKeepEV(); }
    }
    rd.commit(best.idx);
    if (rd.score >= rd.target) break;          // the web's afterCount: round ends here
  }
  if (!rd.over) {
    if (MODE === "twice") rd.settleCrib();     // cribRoundEnd: rd.cribResult || rd.settleCrib()
    rd.settle();                               // ...then settle(), which settles the Crib (again)
  }
  return rd;
}
let sum = 0, cl = 0, crib = 0, rounds = 0;
for (let i = 0; i < N; i++) {
  Math.random = makeRng(1000 + i);
  const run = new CribRun(DECK, M.STREETS[0], null, 50000 + i);
  let reached = 0;
  for (let r = 0; r < 25; r++) {
    const rd = playRound(run);
    rounds++; crib += rd.cribResult ? rd.cribResult.total : 0;
    if (!rd.won) break;
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    sim.shop(run); run.shopState = null;
    if (run.advance()) { reached = 25; break; }
  }
  sum += reached; if (reached >= 25) cl++;
}
console.log(JSON.stringify({ deck: DECK, mode: MODE, N, avgRound: +(sum / N).toFixed(2), clears: +(100 * cl / N).toFixed(1), avgCribPerRound: +(crib / rounds).toFixed(1) }));
