Object.assign(global,{SUIT_SYM:{S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"}});
const C=require("./cribbage.js");
Object.assign(global,{countHand:C.countHand,keepOptions:C.keepOptions,countPoints:C.countPoints,
  cDeck:C.cDeck,cShuf:C.cShuf,bestKeepByEV:C.bestKeepByEV,keepEV:C.keepEV});
const R=require("./cribrogue.js");

console.log("=== AUDIT 1: does the current UI trivialise the keep decision? ===\n");
/* Right now the starter is cut BEFORE the keep and the preview shows the exact
   score. So a player can just tap through combinations and take the maximum —
   i.e. play "hindsight" with zero skill. */
let naive=0, ev=0, hind=0, N=2500;
for (let i=0;i<N;i++){
  const d=cShuf(cDeck()); const dealt=d.splice(0,6), st=d.pop();
  const high=dealt.map((c,j)=>j).sort((a,b)=>dealt[b].rank-dealt[a].rank).slice(0,4);
  naive+=countPoints(high.map(j=>dealt[j]),st);
  hind +=keepOptions(dealt,st,4)[0].points;
  const bk=bestKeepByEV(dealt,4);
  ev   +=countPoints(bk.idx.map(j=>dealt[j]),st);
}
naive/=N; ev/=N; hind/=N;
console.log(`  naive keep (highest cards)      ${naive.toFixed(2)}`);
console.log(`  EV keep  (starter UNKNOWN)      ${ev.toFixed(2)}   <- real cribbage skill`);
console.log(`  hindsight (starter KNOWN)       ${hind.toFixed(2)}   <- what the UI hands you free`);
console.log(`\n  Reachable with zero thought today: ${hind.toFixed(2)} (tap all 15 combos, take max).`);
console.log(`  So the measured +${(100*(ev/naive-1)).toFixed(0)}% skill gap is currently UNAVAILABLE —`);
console.log(`  the game answers its own question. Cutting AFTER the keep restores it.`);

console.log("\n=== AUDIT 2: boss variety ===\n");
console.log(`  bosses defined: ${R.CRIB_BOSSES.length}, one fixed per act`);
console.log(`  distinct boss sequences across all runs: 1`);
console.log(`  -> every run fights the same five bosses in the same order.`);

console.log("\n=== AUDIT 3: how much of the charm pool does a run see? ===\n");
console.log(`  charms: ${R.CCHARMS.length}, slots: 5, avg owned at run end ~5`);
console.log(`  a full run buys ~8-10 charms total (with selling), so ~25-30% of the pool`);

console.log("\n=== AUDIT 4: decision count per round ===\n");
const deals = R.CRIB_DEALS, mull = R.BASE_MULLIGANS;
console.log(`  keeps per round      ${deals}   (15 options each at keep-4-of-6)`);
console.log(`  mulligan decisions   ${mull}`);
console.log(`  shop decisions       ~3 buys + reroll + ${R.LEVEL_CATS.length} level options`);
console.log(`  -> the round is thin: ${deals} real decisions. Balatro gives 4 hands + 3 discards.`);
