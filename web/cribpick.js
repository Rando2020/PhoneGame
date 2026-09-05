global.SUIT_SYM={S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"};
const C=require("./cribbage.js");
global.countHand=C.countHand; global.keepOptions=C.keepOptions;
global.cDeck=C.cDeck; global.cShuf=C.cShuf;
const R=require("./cribrogue.js");
const { fullRun } = require("./cribsim.js");
console.log("growth     pip   thump  clover   facet");
for (const g of [1.22]) {
  R.CRIB_LADDER.growth = g;
  const out=[];
  for (const d of ["pip","thump","clover","facet"]) {
    let cl=0, N=250;
    for (let i=0;i<N;i++) if (fullRun(d).reached>=25) cl++;
    out.push(`${(100*cl/N).toFixed(0).padStart(4)}%`);
  }
  console.log(`  ${g.toFixed(2)}   ${out.join("   ")}`);
}
