/* Full gauntlet playthrough with a greedy player — proves the run is completable. */
const R = require("./rules.js");
const { Combat, Run, classify, findMelds, Kind, GAUNTLET, ROSTER } = R;
function m32(a){return function(){a|=0;a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);
t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};}
const opts=c=>findMelds(c.hand).map(i=>({i,v:classify(i.map(j=>c.hand[j]))})).filter(m=>m.v.valid);
function turn(c){while(c.focus>0&&!c.over){const ms=opts(c);if(!ms.length)break;
const sc=m=>m.v.kind===Kind.GRAND?1000:m.v.kind===Kind.RUN?500+m.i.length*10:
m.v.kind===Kind.SET?400+m.i.length*10:m.v.kind===Kind.PAIR?100:50;
ms.sort((a,b)=>sc(b)-sc(a));c.playMeld(c.takeFromHand(ms[0].i));}c.endTurn();}

function gauntlet(seed, verbose=false){
  const rng=m32(seed); const run=new Run("pip");
  for(const node of GAUNTLET){
    if(node.type==="cache"){ const o=run.offerRelics(3); if(o.length) run.relics.push(o[0]); continue; }
    if(node.type==="rest"){ run.heal(Math.round(run.maxHp*0.32)); continue; }
    const c=new Combat(run,node.enemy,rng);
    let g=0; while(!c.over&&g++<200) turn(c);
    run.hp=c.player.hp;
    if(verbose) console.log(`  ${ROSTER[node.enemy].name.padEnd(14)} ${c.victory?"WIN ":"LOSS"} turns ${String(c.turn).padStart(2)}  hp ${run.hp}/${run.maxHp}`);
    if(!c.victory) return {cleared:false, at:node.enemy};
    run.heal(run.relicValue("heal_after"));
  }
  return {cleared:true, hp:run.hp, relics:run.relics.length};
}

console.log("=== sample gauntlet ===");
gauntlet(42, true);
let clear=0, stops={};
const N=1000;
for(let i=0;i<N;i++){const r=gauntlet(i*31337+7); if(r.cleared)clear++; else stops[r.at]=(stops[r.at]||0)+1;}
console.log(`\nfull gauntlet cleared: ${(100*clear/N).toFixed(1)}%  (greedy AI, ${N} runs)`);
console.log("stopped at:", stops);
