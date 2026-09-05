Object.assign(global,{SUIT_SYM:{S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"}});
const C=require("./cribbage.js");
Object.assign(global,{countHand:C.countHand,countPoints:C.countPoints,keepOptions:C.keepOptions,
  keepEVFast:C.keepEVFast,keepOptionsEV:C.keepOptionsEV,cDeck:C.cDeck,cShuf:C.cShuf});
const R=require("./cribrogue.js");
const { playRound, shop } = require("./cribsim.js");

const bought = {}, carried = {}, offered = {};
let runs = 0;
for (let i=0;i<160;i++){
  const run = new R.CribRun(["pip","thump","clover","facet"][i%4]);
  runs++;
  for (let k=0;k<25;k++){
    const rd = playRound(run);
    for (const n in (rd.contribTotals||{})) carried[n] = (carried[n]||0) + rd.contribTotals[n];
    if (!rd.won) break;
    run.essence += rd.essenceEarned;
    run.openShop();
    for (const ch of run.shopState.offer) offered[ch.name] = (offered[ch.name]||0)+1;
    shop(run);
    for (const ch of run.charms) bought[ch.name] = (bought[ch.name]||0)+1;
    run.shopState = null;
    if (run.advance()) break;
  }
}

const rows = R.CCHARMS.map(ch => ({
  charm: ch.name,
  quality: R.RARITY[ch.rarity||"common"].name,
  offered: offered[ch.name]||0,
  held: bought[ch.name]||0,
  "pts carried": Math.round(carried[ch.name]||0),
  "pts per hold": bought[ch.name] ? Math.round((carried[ch.name]||0)/bought[ch.name]) : 0,
})).sort((a,b)=> b["pts per hold"] - a["pts per hold"]);
console.log(`${runs} runs\n`);
console.table(rows);

const dead = rows.filter(r => r.offered>0 && r.held===0);
const weak = rows.filter(r => r.held>0 && r["pts per hold"] < 25);
console.log("\nNEVER TAKEN despite being offered:", dead.map(r=>r.charm).join(", ") || "none");
console.log("TAKEN BUT LOW IMPACT (<25 pts/hold):", weak.map(r=>r.charm).join(", ") || "none");
