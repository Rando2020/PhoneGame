// Run from the repo root: node web/sims/skip_sim.js "$PWD/web" <auto|push|smart|pushnoskip|autoskip> <meldling> <N> [street]
// Cash-out choice + Skips, as DEPTH.md designs them, against today's game.
//   auto  : today. The round ends the moment the target falls. No Skips.
//   push  : the round always runs full; overshoot banks toward Skips
//           (surplus += 100 x overshoot / target; 100 = one Skip); a banked
//           Skip is spent on the next non-Spoiler round (Glim, shop, move on).
//   smart : cash out at the target unless this deal's overshoot already shows
//           the build is running hot (>= 40% over) and no Skip is banked.
// Same seeds for every policy. Street from argv.
const path = require("path");
const WEB = process.argv[2], POLICY = process.argv[3], DECK = process.argv[4], N = +process.argv[5], ST = +(process.argv[6] || 1);
process.env.NRUNS = "1";
const sim = require(path.join(WEB, "cribsim.js"));
const M = require(path.join(WEB, "meta.js")); Object.assign(global, M);
const R = require(path.join(WEB, "cribrogue.js"));
const { CribRun, CribRound, CRIB_DEALS } = R;
const stats = { pushes: 0, skipsEarned: 0, skipsUsed: 0, rounds: 0 };
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
    if (rd.score >= rd.target) {
      const full = rd.mods.noCashOut && POLICY !== "auto";
      const push = full || POLICY === "push" || POLICY === "pushnoskip" ||
        (POLICY === "smart" && run.skips === 0 && rd.score >= rd.target * 1.4);
      if (!push || rd.dealsLeft <= 0) break;
      stats.pushes++;
    }
  }
  if (!rd.over) rd.settle();
  if (POLICY !== "auto" && rd.won) {
    run.skipProgress += Math.round(100 * Math.max(0, rd.score - rd.target) / rd.target);
    while (run.skipProgress >= 100) { run.skipProgress -= 100; run.skips++; stats.skipsEarned++; }
  }
  stats.rounds++;
  return rd;
}
let sum = 0, cl = 0;
for (let i = 0; i < N; i++) {
  Math.random = makeRng(1000 + i);
  const run = new CribRun(DECK, M.STREETS[ST - 1], null, 50000 + i);
  let reached = 0;
  for (let r = 0; r < 40; r++) {
    if (POLICY !== "auto" && POLICY !== "pushnoskip" && run.skips > 0 && !run.isBoss()) {
      run.skips--; stats.skipsUsed++;
      run.essence += 8 + Math.round(run.roundIndex() * 0.6);
      reached = run.roundIndex();
      sim.shop(run); run.shopState = null;
      if (run.advance()) { reached = 25; break; }
      continue;
    }
    const rd = playRound(run);
    if (!rd.won) break;
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    sim.shop(run); run.shopState = null;
    if (run.advance()) { reached = 25; break; }
  }
  sum += reached; if (reached >= 25) cl++;
}
console.log(JSON.stringify({ deck: DECK, street: ST, policy: POLICY, N, avgRound: +(sum / N).toFixed(2),
  clears: +(100 * cl / N).toFixed(1), pushesPerRun: +(stats.pushes / N).toFixed(2),
  skipsEarned: +(stats.skipsEarned / N).toFixed(2), skipsUsed: +(stats.skipsUsed / N).toFixed(2) }));
