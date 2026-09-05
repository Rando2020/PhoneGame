Object.assign(global,{SUIT_SYM:{S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"}});
const C=require("./cribbage.js");
Object.assign(global,{countHand:C.countHand,countPoints:C.countPoints,keepOptions:C.keepOptions,
  keepEVFast:C.keepEVFast,keepOptionsEV:C.keepOptionsEV,cDeck:C.cDeck,cShuf:C.cShuf});
const R=require("./cribrogue.js");
const { fullRun } = require("./cribsim.js");
const N = +(process.env.N || 50);
console.log("growth     pip   thump  clover   facet");
for (const g of (process.env.GS||"1.185,1.20,1.215").split(",").map(Number)) {
  R.CRIB_LADDER.growth = g;
  const out=[];
  for (const d of ["pip","thump","clover","facet"]) {
    let cl=0; for (let i=0;i<N;i++) if (fullRun(d).reached>=25) cl++;
    out.push(`${(100*cl/N).toFixed(0).padStart(4)}%`);
  }
  console.log(`  ${g.toFixed(3)}  ${out.join("   ")}`);
}
