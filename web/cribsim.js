global.SUIT_SYM = { S:"\u2660", H:"\u2665", C:"\u2663", D:"\u2666" };
const C = require("./cribbage.js");
Object.assign(global, { countHand: C.countHand, countPoints: C.countPoints,
  keepOptions: C.keepOptions, keepEVFast: C.keepEVFast, keepOptionsEV: C.keepOptionsEV,
  cDeck: C.cDeck, cShuf: C.cShuf });
const R = require("./cribrogue.js");
const { CribRun, CribRound, CRIB_LADDER, CCHARMS, CRIB_DEALS } = R;
const NRUNS = +(process.env.NRUNS || 80);
const M = require('./meta.js');
const STREET = M.STREETS[(+(process.env.STREET || 1)) - 1];

function playRound(run, skill = "best") {
  const rd = new CribRound(run);
  while (rd.dealsLeft > 0) {
    if (!rd.newDeal()) break;
    if (rd.recutsLeft > 0) {
      if (rd.starter && countPoints(rd.dealt.slice(0, rd.keepCount()), rd.starter, false, rd.mods) < 4)
        rd.recut();
    }
    let best = skill === "best" ? rd.bestKeepEV() : null;
    if (best && rd.mulligansLeft > 0 && rd.stock.length > rd.needed() + 8) {
      const pace = rd.target / Math.max(1, CRIB_DEALS + rd.mods.dealBonus);
      if (best.ev * 3 < pace * 0.45) { rd.mulligan(); best = rd.bestKeepEV(); }
    }
    let idx;
    if (best) idx = best.idx;
    else {
      const k = rd.keepCount();
      idx = rd.dealt.map((c, i) => i).sort((a, b) => rd.dealt[b].rank - rd.dealt[a].rank).slice(0, k);
    }
    rd.commit(idx);
    if (rd.score >= rd.target) { rd.cashOut(); break; }
  }
  if (!rd.over) rd.settle();
  return rd;
}

function shop(run) {
  if (!run.shopState) run.openShop();
  // levels first — they are the uncapped backbone
  const order = ["fifteen", "run", "pair", "flush", "nobs"];
  let lv = true;
  while (lv) {
    lv = false;
    for (const cat of order)
      if (run.essence >= run.levelCostFor(cat) + 8) { run.buyLevel(cat); lv = true; break; }
  }
  // then cards: prize fives and enhanced cards, ignore plain junk
  for (const entry of run.shopState.cards) {
    if (entry.sold) continue;
    const worth = (entry.card.rank === 5 ? 14 : 0) +
                  (entry.card.rank >= 10 ? 6 : 2) +
                  (entry.card.enh ? 9 : 0);
    if (worth >= entry.cost && run.essence >= entry.cost) {
      run.buyCard(entry); entry.sold = true;
    }
  }
  /* Value a charm by quality then price, with no tier prejudice, and churn a
     weak charm out when something clearly better is affordable. */
  const QV = { common: 1, uncommon: 2, rare: 3, legendary: 4 };
  const val = (c) => QV[c.rarity || "common"] * 100 + c.cost;
  let bought = true;
  while (bought) {
    bought = false;
    const offer = run.shopState.offer
      .filter(c => !run.charms.some(x => x.id === c.id))
      .sort((a, b) => val(b) - val(a));
    if (!offer.length) break;
    const pick = offer[0];
    if (run.isFull()) {
      const worst = run.charms.slice().sort((a, b) => val(a) - val(b))[0];
      if (worst && val(pick) > val(worst) * 1.15 &&
          run.essence + Math.max(2, Math.floor(worst.cost / 2)) >= pick.cost) {
        run.sell(worst.id);
      } else break;
    }
    if (pick.cost <= run.essence && !run.isFull()) {
      run.charms.push(pick); run.essence -= pick.cost;
      if (pick.onAcquire) pick.onAcquire(run);
      bought = true;
    } else break;
  }
  // spend leftovers on category levels, favouring the categories we hit most
  let more = true;
  while (more) {
    more = false;
    for (const cat of order)
      if (run.essence >= run.levelCostFor(cat)) { run.buyLevel(cat); more = true; break; }
  }
}

function fullRun(deck, skill = "best") {
  const run = new CribRun(deck, (typeof STREET !== 'undefined' ? STREET : null));
  let reached = 0;
  for (let i = 0; i < 25; i++) {
    const rd = playRound(run, skill);
    if (!rd.won) return { reached, charms: run.charms.length };
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    shop(run);
    run.shopState = null;
    if (run.advance()) break;
  }
  return { reached: 25, charms: run.charms.length };
}

if (require.main !== module) { module.exports = { playRound, shop, fullRun }; }
else {
console.log("=== round 1 score, no charms (target %d) ===", CRIB_LADDER.baseTarget);
for (const d of ["pip","thump","clover","facet"]) {
  const a = [];
  for (let i=0;i<120;i++){ const run = new CribRun(d); a.push(playRound(run).score); }
  a.sort((x,y)=>x-y);
  console.log(`  ${d.padEnd(7)} p10 ${a[12]}  median ${a[60]}  p90 ${a[108]}`);
}

console.log("\n=== GATE 4: full-run clear rate (300 runs/deck) ===");
for (const d of ["pip","thump","clover","facet"]) {
  let sum=0, cl=0, ch=0, N=NRUNS;
  for (let i=0;i<N;i++){ const r=fullRun(d); sum+=r.reached; ch+=r.charms; if(r.reached>=25)cl++; }
  console.log(`  ${d.padEnd(7)} avg round ${(sum/N).toFixed(1).padStart(5)}   clears ${(100*cl/N).toFixed(1).padStart(5)}%   avg charms ${(ch/N).toFixed(1)}`);
}

console.log("\n=== GATE 3b: does skill still matter across a whole run? ===");
for (const skill of ["best","naive"]) {
  let sum=0,N=Math.max(20,Math.floor(NRUNS/2));
  for(let i=0;i<N;i++) sum+=fullRun("facet",skill).reached;
  console.log(`  ${skill.padEnd(6)} keeps: avg round reached ${(sum/N).toFixed(1)}`);
}

console.log("\n=== GATE 5: growth sensitivity (facet) ===");
for (const g of [1.13,1.145,1.155,1.17]) {
  CRIB_LADDER.growth = g;
  let sum=0,cl=0,N=Math.max(20,Math.floor(NRUNS/3));
  for(let i=0;i<N;i++){const r=fullRun("facet"); sum+=r.reached; if(r.reached>=25)cl++;}
  console.log(`  growth x${g}   avg round ${(sum/N).toFixed(1).padStart(5)}   clears ${(100*cl/N).toFixed(1)}%`);
}
}
