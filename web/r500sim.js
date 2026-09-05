/* Does Rummy 500 (lay-down melding) actually produce Balatro-like beats?
   The metric that matters: scoring EVENTS per hand, not points per hand. */

const G = require("./gin.js");
const { bestArrangement, V } = G;

const SUITS = ["S", "H", "C", "D"];
const mkDeck = () => { const d = []; for (const s of SUITS) for (let r = 1; r <= 13; r++) d.push({rank:r,suit:s}); return d; };
function shuf(a, rng) { for (let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];} return a; }
function m32(a){return function(){a|=0;a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);
t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};}

const meldValue = (cards) => cards.reduce((t,c)=>t+V(c),0);

/* Can `card` be laid off onto an existing table meld? */
function layoffTarget(card, table) {
  for (const m of table) {
    const set = m.every(x => x.rank === m[0].rank);
    if (set) {
      if (card.rank === m[0].rank && m.length < 4 && !m.some(x=>x.suit===card.suit)) return m;
    } else {
      const rs = m.map(x=>x.rank).sort((a,b)=>a-b);
      if (card.suit === m[0].suit && (card.rank===rs[0]-1 || card.rank===rs[rs.length-1]+1)) return m;
    }
  }
  return null;
}

function playHand(rng, opts = {}) {
  const meldMin = opts.meldMin ?? 3;
  const handSize = opts.handSize ?? 10;
  const deck = shuf(mkDeck(), rng);
  const hands = [deck.splice(0,handSize), deck.splice(0,handSize)];
  const table = [[],[]];            // each player's laid melds
  const discard = [deck.pop()];
  const scores = [0,0];
  const beats = [0,0];              // scoring events
  let turn = 0, guard = 0, out = -1;

  while (guard++ < 200 && deck.length) {
    const me = hands[turn];

    // --- draw: take the discard only if it completes something now
    const top = discard[discard.length-1];
    let took = false;
    if (top) {
      const probe = me.concat([top]);
      const a = bestArrangement(probe);
      const before = bestArrangement(me);
      if (a.melds.length > before.melds.length || layoffTarget(top, table[0].concat(table[1]))) {
        me.push(discard.pop()); took = true;
      }
    }
    if (!took) me.push(deck.pop());

    // --- lay every complete meld we hold  (each = one scoring beat)
    let laid = true;
    while (laid) {
      laid = false;
      const arr = bestArrangement(me);
      for (const idx of arr.melds) {
        if (idx.length < meldMin) continue;
        const cards = idx.map(i => me[i]);
        idx.slice().sort((a,b)=>b-a).forEach(i => me.splice(i,1));
        table[turn].push(cards);
        scores[turn] += meldValue(cards);
        beats[turn]++;
        laid = true;
        break;
      }
    }

    // --- lay off onto any table meld  (each = a smaller beat)
    let off = true;
    while (off) {
      off = false;
      for (let i=0;i<me.length;i++){
        const t = layoffTarget(me[i], table[0].concat(table[1]));
        if (t) { t.push(me[i]); scores[turn]+=V(me[i]); beats[turn]++; me.splice(i,1); off=true; break; }
      }
    }

    if (!me.length) { out = turn; break; }

    // --- discard the highest card not doing work
    let worst = 0;
    for (let i=1;i<me.length;i++) if (V(me[i]) > V(me[worst])) worst = i;
    discard.push(me.splice(worst,1)[0]);
    turn = 1-turn;
  }

  // deadwood penalty
  for (const p of [0,1]) scores[p] -= hands[p].reduce((t,c)=>t+V(c),0);
  return { scores, beats, turns: guard, out };
}

console.log("=== Rummy 500 (lay-down melding) — interaction beats ===\n");
for (const cfg of [
  {handSize: 7,  label: "hand 7"},
  {handSize: 10, label: "hand 10"},
  {handSize: 13, label: "hand 13"},
]) {
  let B=0,S=0,T=0,N=3000,maxB=0;
  for (let i=0;i<N;i++){
    const r = playHand(m32(i*7919+11), cfg);
    B += r.beats[0]; S += Math.max(...r.scores); T += r.turns;
    maxB = Math.max(maxB, r.beats[0]);
  }
  console.log(`  ${cfg.label.padEnd(9)} beats/hand ${(B/N).toFixed(1).padStart(4)}   ` +
    `max ${String(maxB).padStart(2)}   turns ${(T/N).toFixed(1).padStart(5)}   ` +
    `top score ${(S/N).toFixed(0)}`);
}

console.log("\n=== Gin, for comparison ===");
console.log("  hand 10   beats/hand  1.0   (the knock — nothing before it)   turns  16.1");

console.log("\n=== hands to reach a target (hand 10) ===");
for (const target of [100, 200, 300, 500]) {
  let hs=[],N=600;
  for (let s=0;s<N;s++){
    const rng=m32(s*104729+3); let a=0,b=0,c=0;
    while(a<target && b<target && c<30){ const r=playHand(rng,{handSize:10}); c++; a+=Math.max(0,r.scores[0]); b+=Math.max(0,r.scores[1]); }
    hs.push(c);
  }
  const avg = hs.reduce((x,y)=>x+y,0)/hs.length;
  console.log(`  first to ${String(target).padStart(3)}:  ${avg.toFixed(1)} hands`);
}
