const R = require("./rules.js");
const { Combat, Run, classify, findMelds, Kind, TUNING } = R;
function m32(a){return function(){a|=0;a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);
t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};}
const opts=c=>findMelds(c.hand).map(i=>({i,v:classify(i.map(j=>c.hand[j]))})).filter(m=>m.v.valid);
function greedy(c){while(c.focus>0&&!c.over){const ms=opts(c);if(!ms.length)break;
const sc=m=>m.v.kind===Kind.GRAND?1000:m.v.kind===Kind.RUN?500+m.i.length*10:
m.v.kind===Kind.SET?400+m.i.length*10:m.v.kind===Kind.PAIR?100:50;
ms.sort((a,b)=>sc(b)-sc(a));c.playMeld(c.takeFromHand(ms[0].i));}c.endTurn();}
function win(e,seed){const run=new Run("pip");const c=new Combat(run,e,m32(seed));
let g=0;while(!c.over&&g++<200)greedy(c);return c.victory;}
function rate(e,n=1200){let w=0;for(let i=0;i<n;i++)if(win(e,i*7919+13))w++;return 100*w/n;}
console.log("hand  edmg  ehp | deadwood  jokester  kingpin");
for(const h of [9,10,11,12])for(const d of [0.9,1.0,1.15])for(const hp of [1.0,1.15]){
  TUNING.handSize=h;TUNING.enemyDmg=d;TUNING.enemyHpScale=hp;
  const r=["deadwood","jokester","kingpin"].map(e=>rate(e).toFixed(0).padStart(3)+"%");
  console.log(`${String(h).padStart(4)}  ${d.toFixed(2)}  ${hp.toFixed(2)} |   ${r.join("     ")}`);
}
