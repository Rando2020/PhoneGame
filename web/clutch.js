Object.assign(global,{SUIT_SYM:{S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"}});
const C=require("./cribbage.js");
Object.assign(global,{countHand:C.countHand,countPoints:C.countPoints,keepOptions:C.keepOptions,
  keepEVFast:C.keepEVFast,keepOptionsEV:C.keepOptionsEV,cDeck:C.cDeck,cShuf:C.cShuf});
const R=require("./cribrogue.js");
const { playRound, shop } = require("./cribsim.js");

/* Where do clutch moments actually live across a real run? */
const byAct = {};
let rounds=0, narrow=0, soClose=0, decisive=0, lastDealCross=0, cutSaved=0;

for (let r=0;r<120;r++){
  const run = new R.CribRun(["pip","thump","clover","facet"][r%4]);
  for (let i=0;i<25;i++){
    const rd = playRound(run);
    rounds++;
    const a = run.act;
    byAct[a] = byAct[a] || { n:0, narrow:0, close:0, dec:0 };
    byAct[a].n++;
    if (rd.narrow) { narrow++; byAct[a].narrow++; }
    if (rd.soClose) { soClose++; byAct[a].close++; }
    const m = rd.mvp();
    if (m && m.decisive) { decisive++; byAct[a].dec++; }
    if (rd.lastCount && rd.lastCount.crossedTarget && rd.lastCount.wasFinalDeal) lastDealCross++;
    if (rd.lastCount && rd.lastCount.crossedTarget &&
        rd.lastCount.scoreBefore + rd.lastCount.handOnly < rd.target) cutSaved++;
    if (!rd.won) break;
    run.essence += rd.essenceEarned; shop(run);
    if (run.advance()) break;
  }
}
console.log(`rounds played: ${rounds}\n`);
console.log(`  narrow wins (<=12% margin)      ${(100*narrow/rounds).toFixed(1)}%`);
console.log(`  near misses (lost by <=12%)     ${(100*soClose/rounds).toFixed(1)}%`);
console.log(`  a charm/level/cut was DECISIVE  ${(100*decisive/rounds).toFixed(1)}%`);
console.log(`  target crossed on the FINAL deal ${(100*lastDealCross/rounds).toFixed(1)}%`);
console.log(`  the CUT is what crossed you over ${(100*cutSaved/rounds).toFixed(1)}%`);
console.log("\n  by act:");
for (const a in byAct) {
  const b = byAct[a];
  console.log(`    act ${a}: ${String(b.n).padStart(4)} rounds  narrow ${(100*b.narrow/b.n).toFixed(0).padStart(3)}%  near-miss ${(100*b.close/b.n).toFixed(0).padStart(3)}%  decisive ${(100*b.dec/b.n).toFixed(0).padStart(3)}%`);
}
