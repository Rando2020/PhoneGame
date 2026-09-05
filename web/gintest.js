const G = require("./gin.js");
const { bestArrangement, GinHand, CpuGin, scoreHand } = G;

// --- correctness spot checks
const H = (s) => s.split(" ").map(t => ({rank: +t.slice(0,-1), suit: t.slice(-1)}));
const show = (h) => { const a = bestArrangement(h);
  return `melds=${a.melds.map(m=>m.map(i=>h[i].rank+h[i].suit).join("")).join("|")} dw=${a.deadwood}`; };

console.log("=== deadwood optimiser ===");
console.log(" 3H4H5H + 9S9H9C + K D:", show(H("3H 4H 5H 9S 9H 9C 13D")));
console.log(" overlap 5H6H7H8H + 5S5C:", show(H("5H 6H 7H 8H 5S 5C")));
console.log(" gin hand:", show(H("1S 2S 3S 7H 7C 7D 10C 11C 12C 13C")));
console.log(" junk:", show(H("1S 4H 7C 10D 13S 2C 5H 8D 11S 3H")));

console.log("\n=== scoring ===");
const knocker = H("3H 4H 5H 9S 9H 9C 2C 3C");     // dw = 5
const opp     = H("1S 2S 3S 13D 12H 11C 10S 8D");
console.log(" knock:", JSON.stringify(scoreHand(knocker, opp, false)));

// --- pacing: how many hands to reach a target?
function playHand(rng) {
  const h = new GinHand(rng);
  let guard = 0;
  while (!h.over && guard++ < 200) {
    if (h.turn === "player") {
      // mirror the CPU policy for the "player" so both sides play well
      const src = CpuGin.chooseDraw({ ...h, cpu: h.player });
      if (src === "discard") h.drawDiscard("player"); else h.drawStock("player");
      if (h.over) break;
      const di = CpuGin.chooseDiscard(h.player);
      const kept = h.player.slice(); kept.splice(di, 1);
      const a = bestArrangement(kept);
      if (a.deadwood <= 10 && (a.deadwood <= 6 || a.deadwood === 0)) { h.knock("player", di); break; }
      h.discardCard("player", di);
    } else CpuGin.takeTurn(h);
  }
  return { r: h.result, turns: guard };
}

function m32(a){return function(){a|=0;a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);
t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};}

console.log("\n=== hand statistics (4000 hands) ===");
let pts=[], turns=[], gins=0, undercuts=0, washes=0, pWin=0, n=4000;
for (let i=0;i<n;i++){
  const {r,turns:t} = playHand(m32(i*7919+3));
  turns.push(t);
  if (!r || r.wash) { washes++; continue; }
  pts.push(r.points);
  if (r.gin) gins++;
  if (r.undercut) undercuts++;
  if (r.winner === "player") pWin++;
}
const avg = a => (a.reduce((x,y)=>x+y,0)/a.length);
const med = a => a.slice().sort((x,y)=>x-y)[Math.floor(a.length/2)];
console.log(`  avg points/hand  ${avg(pts).toFixed(1)}   median ${med(pts)}   max ${Math.max(...pts)}`);
console.log(`  avg turns/hand   ${avg(turns).toFixed(1)}  (a "turn" = one player action)`);
console.log(`  gin ${(100*gins/n).toFixed(1)}%   undercut ${(100*undercuts/n).toFixed(1)}%   wash ${(100*washes/n).toFixed(1)}%`);

console.log("\n=== hands needed to reach a target ===");
for (const target of [25, 50, 75, 100]) {
  let hands=[], N=800;
  for (let s=0;s<N;s++){
    let a=0,b=0,c=0;
    const rng=m32(s*104729+5);
    while(a<target && b<target && c<40){ const {r}=playHand(rng); c++;
      if(!r||r.wash) continue;
      if(r.winner==="player") a+=r.points; else b+=r.points; }
    hands.push(c);
  }
  console.log(`  first to ${String(target).padStart(3)}:  ${avg(hands).toFixed(1)} hands  (median ${med(hands)})`);
}
