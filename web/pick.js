const R = require("./roguelite.js");
const { fullRun } = require("./roguesim.js");
console.log("growth   deck     avg round   clears");
for (const g of [1.12, 1.14, 1.15, 1.16]) {
  for (const m of ["pip","thump","clover","facet"]) {
    let sum=0, cl=0, N=400;
    for (let i=0;i<N;i++){ R.LADDER.growth=g; const r=fullRun(m,g); sum+=r.reached; if(r.reached>=25)cl++; }
    console.log(`  ${g.toFixed(2)}   ${m.padEnd(8)} ${(sum/N).toFixed(1).padStart(6)}     ${(100*cl/N).toFixed(1)}%`);
  }
  console.log("");
}
