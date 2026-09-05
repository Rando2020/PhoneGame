/* Solitaire Rummy round: "score X within N turns".
   Measures the score curve so the ante ladder can be set from data. */

const G = require("./gin.js");
const { bestArrangement, V } = G;

const SUITS = ["S","H","C","D"];
const mkDeck = () => { const d=[]; for(const s of SUITS) for(let r=1;r<=13;r++) d.push({rank:r,suit:s}); return d; };
function shuf(a,rng){for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
function m32(a){return function(){a|=0;a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);
t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};}

const base = (cards) => cards.reduce((t,c)=>t+V(c),0);

function layoffTarget(card, table){
  for(const m of table){
    const set = m.every(x=>x.rank===m[0].rank);
    if(set){ if(card.rank===m[0].rank && m.length<4 && !m.some(x=>x.suit===card.suit)) return m; }
    else { const rs=m.map(x=>x.rank).sort((a,b)=>a-b);
      if(card.suit===m[0].suit && (card.rank===rs[0]-1||card.rank===rs[rs.length-1]+1)) return m; }
  }
  return null;
}

/* mult: flat multiplier applied to every meld (stands in for ability stacking) */
function round(rng, {turns=12, handSize=10, digs=3, mult=1, runMult=1, setMult=1, prep=false, prepRate=0.5} = {}) {
  const deck = shuf(mkDeck(), rng);
  const hand = deck.splice(0, handSize);
  const discard = [deck.pop()];
  const table = [];
  let score = 0, beats = 0, digsLeft = digs;

  for (let t = 0; t < turns; t++) {
    if (!deck.length) break;

    // --- draw. dig only when the top completes a meld right now
    let took = false;
    const top = discard[discard.length-1];
    if (top && digsLeft > 0) {
      const before = bestArrangement(hand).melds.length;
      const after = bestArrangement(hand.concat([top])).melds.length;
      if (after > before || layoffTarget(top, table)) { hand.push(discard.pop()); digsLeft--; took = true; }
    }
    if (!took) hand.push(deck.pop());

    // --- lay every meld held (each is a scoring beat)
    let laid = true;
    while (laid) {
      laid = false;
      const arr = bestArrangement(hand);
      let candidates = arr.melds;
      if (prep && !candidates.length) {
        // no complete meld: lay a 2-card PREP (pair or 2-run) at reduced value
        const two = [];
        for (let i=0;i<hand.length;i++) for (let j=i+1;j<hand.length;j++){
          const a=hand[i], b=hand[j];
          if (a.rank===b.rank || (a.suit===b.suit && Math.abs(a.rank-b.rank)===1)) two.push([i,j]);
        }
        if (two.length) candidates = [two[0]];
      }
      for (const idx of candidates) {
        const cards = idx.map(i=>hand[i]);
        const isPrep = cards.length === 2;
        const isRun = !cards.every(c=>c.rank===cards[0].rank);
        idx.slice().sort((a,b)=>b-a).forEach(i=>hand.splice(i,1));
        table.push(cards);
        score += Math.round(base(cards) * mult * (isRun ? runMult : setMult) * (isPrep ? prepRate : 1));
        beats++;
        laid = true;
        break;
      }
    }

    // --- lay off onto our own tableau
    let off = true;
    while (off) {
      off = false;
      for (let i=0;i<hand.length;i++){
        const tgt = layoffTarget(hand[i], table);
        if (tgt){ tgt.push(hand[i]); score += Math.round(V(hand[i])*mult); beats++; hand.splice(i,1); off=true; break; }
      }
    }

    if (!hand.length) break;

    // --- discard highest deadwood
    let worst=0; for(let i=1;i<hand.length;i++) if(V(hand[i])>V(hand[worst])) worst=i;
    discard.push(hand.splice(worst,1)[0]);
  }

  const dead = hand.reduce((t,c)=>t+V(c),0);
  return { score, net: score - dead, beats, dead };
}

function stats(opts, N=4000) {
  const s=[], b=[];
  for (let i=0;i<N;i++){ const r = round(m32(i*7919+5), opts); s.push(r.net); b.push(r.beats); }
  s.sort((a,b)=>a-b);
  const avg = a=>a.reduce((x,y)=>x+y,0)/a.length;
  return { p10: s[Math.floor(N*0.1)], p50: s[Math.floor(N*0.5)],
           p90: s[Math.floor(N*0.9)], avg: avg(s).toFixed(0), beats: avg(b).toFixed(1) };
}

console.log("=== score per round, by turns allowed (hand 10, mult 1) ===\n");
console.log("  turns   p10    median   p90    beats");
for (const t of [8,10,12,15,20]) {
  const r = stats({turns:t});
  console.log(`  ${String(t).padStart(4)}   ${String(r.p10).padStart(4)}   ${String(r.p50).padStart(5)}   ${String(r.p90).padStart(5)}   ${r.beats}`);
}

console.log("\n=== PREP: laying incomplete 2-card melds (12 turns) ===");
for (const h of [10,12,14]) {
  const a = stats({turns:12, handSize:h});
  const b = stats({turns:12, handSize:h, prep:true});
  console.log(`  hand ${String(h).padStart(2)}   without PREP: beats ${a.beats} median ${String(a.p50).padStart(3)}   |   with PREP: beats ${b.beats} median ${String(b.p50).padStart(3)}`);
}

console.log("\n=== effect of hand size (12 turns) ===");
for (const h of [8,10,12,14]) {
  const r = stats({turns:12, handSize:h});
  console.log(`  hand ${String(h).padStart(2)}   median ${String(r.p50).padStart(3)}   p90 ${String(r.p90).padStart(3)}   beats ${r.beats}`);
}

console.log("\n=== multiplier scaling (12 turns) — the ability axis ===");
for (const m of [1,1.5,2,3,5]) {
  const r = stats({turns:12, mult:m});
  console.log(`  mult x${String(m).padStart(3)}   median ${String(r.p50).padStart(4)}   p90 ${String(r.p90).padStart(4)}`);
}

console.log("\n=== proposed ante ladder (5 acts x 5 rounds) ===");
const b0 = stats({turns:12}).p50;
console.log(`  baseline median with no upgrades: ${b0}\n`);
let target = Math.round(b0 * 0.75);
for (let act=1; act<=5; act++){
  const row=[];
  for (let r=1;r<=5;r++){ row.push(target); target = Math.round(target*1.32); }
  console.log(`  Act ${act}:  ${row.map(x=>String(x).padStart(5)).join("  ")}${act===5?"   <- final boss":""}`);
}
console.log("\n  (x1.32 per round => final round needs ~%dx the baseline round.)",
  Math.round(target/b0));
