global.SUIT_SYM = { S:"\u2660", H:"\u2665", C:"\u2663", D:"\u2666" };
const C = require("./cribbage.js");
const { countHand, countPoints, keepOptions, bestKeepByEV, cDeck, cShuf } = C;
const h = (s) => s.split(" ").map(t => {
  const suit = t.slice(-1); const r = t.slice(0,-1);
  return { rank: r === "A" ? 1 : r === "J" ? 11 : r === "Q" ? 12 : r === "K" ? 13 : +r, suit };
});

console.log("=== GATE 1: exact scoring ===\n");
const cases = [
  ["5S 5H 5C JD", "5D", 29, "the perfect hand"],
  ["4S 5S 6S 7S", "8S", 14, "run of 5 + flush 5 + two 15s"],
  ["AS 2H 3C 4D", "5S", 7,  "run of 5, one 15 (A+2+3+4+5=15)"],
  ["5S 5H 5C 5D", "JS", 28, "four 5s: 12 pairs + 16 in fifteens; NO nobs (jack is the starter)"],
  ["7S 8H 9C 10D", "JS", 7, "run of 5 = 5, one fifteen (7+8) = 2"],
  ["2S 3H 4C 9D", "10S", 7, "run of 3 = 3, two fifteens (2+3+10, 2+4+9) = 4"],
  ["KS KH QC QD", "JS", 16, "two pairs + two runs of 3"],
];
let pass = 0;
for (const [hs, st, exp, note] of cases) {
  const r = countHand(h(hs), h(st)[0]);
  const ok = r.base === exp;
  if (ok) pass++;
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${hs} + ${st}  got ${String(r.base).padStart(2)} expected ${String(exp).padStart(2)}   ${note}`);
  if (!ok) console.log("        events:", r.events.map(e=>`${e.label}=${e.points}`).join(", "));
}
console.log(`\n  ${pass}/${cases.length} reference hands correct`);

console.log("\n=== GATE 2: dopamine density (scoring events per deal) ===\n");
function dealSim(n=20000){
  let ev=0, pts=0, zero=0, hist={};
  for(let i=0;i<n;i++){
    const d=cShuf(cDeck());
    const dealt=d.splice(0,6), starter=d.pop();
    const best=keepOptions(dealt,starter,4)[0];
    const r=countHand(best.idx.map(j=>dealt[j]),starter);
    ev+=r.events.length; pts+=r.base;
    if(!r.events.length) zero++;
    const b=Math.min(8,r.events.length); hist[b]=(hist[b]||0)+1;
  }
  return {ev:ev/n, pts:pts/n, zero:100*zero/n, hist};
}
const d1=dealSim();
console.log(`  events per deal  ${d1.ev.toFixed(2)}   (gate: >= 4)`);
console.log(`  points per deal  ${d1.pts.toFixed(1)}`);
console.log(`  scoreless deals  ${d1.zero.toFixed(2)}%`);
console.log(`  event histogram  ${JSON.stringify(d1.hist)}`);

console.log("\n=== GATE 3: skill gap (naive keep vs optimal keep) ===\n");
function skillGap(n=3000){
  let naive=0, greedy=0, ev=0;
  for(let i=0;i<n;i++){
    const d=cShuf(cDeck());
    const dealt=d.splice(0,6), starter=d.pop();
    // naive: keep the 4 highest cards
    const byVal=dealt.map((c,j)=>j).sort((a,b)=>dealt[b].rank-dealt[a].rank).slice(0,4);
    naive+=countPoints(byVal.map(j=>dealt[j]),starter);
    // greedy: best against THIS starter (hindsight, upper bound)
    greedy+=keepOptions(dealt,starter,4)[0].points;
    // EV: best expected keep, not knowing the starter — real skilled play
    const bk=bestKeepByEV(dealt,4);
    ev+=countPoints(bk.idx.map(j=>dealt[j]),starter);
  }
  return {naive:naive/n, ev:ev/n, greedy:greedy/n};
}
const g=skillGap();
console.log(`  naive (keep highest)      ${g.naive.toFixed(2)} pts`);
console.log(`  skilled (best EV keep)    ${g.ev.toFixed(2)} pts`);
console.log(`  hindsight (knows starter) ${g.greedy.toFixed(2)} pts`);
console.log(`\n  skill gap naive -> skilled: +${(100*(g.ev/g.naive-1)).toFixed(1)}%   (gate: >= 15%)`);
console.log(`  headroom to perfect info:   +${(100*(g.greedy/g.ev-1)).toFixed(1)}%`);
