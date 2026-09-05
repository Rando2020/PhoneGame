/* Can the ladder actually be climbed? Plays full 25-round runs with a decent
   policy and a simple shop heuristic. Tunes TARGET_GROWTH from data. */
const R = require("./roguelite.js");
const { RogueRun, Round, CHARMS, layKind, extendTarget, pip } = R;

/* --- greedy round policy: lay everything you can, dig when it completes a meld */
function bestLays(round) {
  const h = round.hand, out = [];
  const n = h.length;
  // sets
  const byRank = {};
  h.forEach((c,i)=>(byRank[c.rank] ||= []).push(i));
  for (const k in byRank) if (byRank[k].length >= 3) out.push(byRank[k].slice());
  // runs
  const bySuit = {};
  h.forEach((c,i)=>(bySuit[c.suit] ||= []).push(i));
  for (const s in bySuit) {
    const g = bySuit[s].slice().sort((a,b)=>h[a].rank-h[b].rank);
    for (let i=0;i<g.length;i++){ let ch=[g[i]];
      for(let j=i+1;j<g.length;j++){ if(h[g[j]].rank===h[ch[ch.length-1]].rank+1){ch.push(g[j]);
        if(ch.length>=3) out.push(ch.slice());} else break; } }
  }
  return out.sort((a,b)=>b.length-a.length);
}

function preps(round) {
  const h = round.hand, out = [];
  for (let i=0;i<h.length;i++) for (let j=i+1;j<h.length;j++){
    const a=h[i],b=h[j];
    if (a.rank===b.rank || (a.suit===b.suit && Math.abs(a.rank-b.rank)===1)) out.push([i,j]);
  }
  return out;
}

function playRound(run) {
  const rd = new Round(run);
  let guard = 0;
  while (!rd.over && guard++ < 100) {
    // draw: dig if the top completes a meld or extends the table
    const top = rd.discard[rd.discard.length-1];
    let dug = false;
    if (top && rd.canDig()) {
      const probe = rd.hand.concat([top]);
      const fake = { hand: probe };
      if (bestLays(fake).length > bestLays(rd).length || extendTarget(top, rd.table)) {
        rd.draw("dig"); dug = true;
      }
    }
    if (!dug) rd.draw("stock");
    if (rd.over) break;

    // lay complete melds
    let laid = true;
    while (laid) {
      laid = false;
      const opts = bestLays(rd);
      if (opts.length) { if (rd.layMeld(opts[0])) laid = true; }
    }
    // lay off singles
    let off = true;
    while (off) {
      off = false;
      for (let i=0;i<rd.hand.length;i++)
        if (extendTarget(rd.hand[i], rd.table)) { if (rd.layOff(i)) { off = true; break; } }
    }
    // lay a PREP if nothing else happened and it's worth anything
    if (rd.mods.prepRate > 0 && rd.laysThisTurn === 0) {
      const p = preps(rd);
      if (p.length) rd.layMeld(p[0]);
    }

    if (rd.score >= rd.target) { rd.cashOut(); break; }
    if (!rd.hand.length) { rd.finish(); break; }
    // discard the highest card that isn't part of a pending meld
    let worst = 0;
    for (let i=1;i<rd.hand.length;i++) if (pip(rd.hand[i]) > pip(rd.hand[worst])) worst = i;
    rd.discardCard(worst);
  }
  if (!rd.over) rd.finish();
  return rd;
}

/* --- shop heuristic: buy the most expensive affordable charm, prefer tier 2 */
function shop(run) {
  let bought = true;
  while (bought) {
    bought = false;
    const offer = run.shopOffer(3)
      .filter(c => c.cost <= run.essence)
      .sort((a,b) => (({2:0,1:1,3:2})[a.tier] - ({2:0,1:1,3:2})[b.tier]) || (b.cost - a.cost));
    if (offer.length) { run.charms.push(offer[0]); run.essence -= offer[0].cost; bought = true; }
  }
}

function fullRun(meldling = "facet", growth = null) {
  if (growth) R.LADDER.growth = growth;
  const run = new RogueRun(meldling);
  let reached = 0;
  for (let i = 0; i < 25; i++) {
    const rd = playRound(run);
    if (!rd.won) return { reached, charms: run.charms.length };
    reached = run.roundIndex();
    run.essence += rd.essenceEarned;
    shop(run);
    if (run.advance()) break;
  }
  return { reached: 25, charms: run.charms.length };
}

if (typeof module !== "undefined" && require.main !== module) { module.exports = { fullRun }; }
else {
console.log("=== how far does a run get? (400 runs each) ===\n");
for (const m of ["pip","thump","clover","facet"]) {
  const hist = {}; let sum = 0, clears = 0;
  for (let i=0;i<400;i++){ const r = fullRun(m); sum += r.reached;
    if (r.reached >= 25) clears++;
    const b = Math.ceil(r.reached/5)||0; hist[b] = (hist[b]||0)+1; }
  console.log(`  ${m.padEnd(7)} avg round reached ${(sum/400).toFixed(1).padStart(5)}   ` +
    `full clears ${(100*clears/400).toFixed(1)}%   act histogram ${JSON.stringify(hist)}`);
}

console.log("\n=== target growth sensitivity (facet, 300 runs) ===");
for (const g of [1.14, 1.17, 1.21, 1.25, 1.30]) {
  let sum=0, clears=0;
  for (let i=0;i<300;i++){ const r = fullRun("facet", g); sum += r.reached; if (r.reached>=25) clears++; }
  console.log(`  growth x${g.toFixed(2)}   avg round ${(sum/300).toFixed(1).padStart(5)}   clears ${(100*clears/300).toFixed(1)}%`);
}
}
