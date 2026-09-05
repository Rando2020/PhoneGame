/* Meldlings — Gin Rummy core.
   Real Rummy: draw from stock or discard, meld, discard, knock.
   Deadwood is the cost that makes hoarding hurt. */

const V = (c) => Math.min(10, c.rank);          // A=1, face=10
const SUITS_G = ["S", "H", "C", "D"];

/* ---------------------------------------------------------------- melds */
function allMelds(hand) {
  const out = [];
  const push = (idx) => out.push({ idx, mask: idx.reduce((m, i) => m | (1 << i), 0) });

  // sets: 3 or 4 of a rank
  const byRank = {};
  hand.forEach((c, i) => (byRank[c.rank] ||= []).push(i));
  for (const r in byRank) {
    const g = byRank[r];
    if (g.length >= 3) {
      if (g.length === 3) push(g.slice());
      else {
        push(g.slice());                                  // all four
        for (let k = 0; k < 4; k++) push(g.filter((_, j) => j !== k)); // each trio
      }
    }
  }

  // runs: 3+ consecutive in a suit
  const bySuit = {};
  hand.forEach((c, i) => (bySuit[c.suit] ||= []).push(i));
  for (const s in bySuit) {
    const g = bySuit[s].slice().sort((a, b) => hand[a].rank - hand[b].rank);
    for (let i = 0; i < g.length; i++) {
      let chain = [g[i]];
      for (let j = i + 1; j < g.length; j++) {
        if (hand[g[j]].rank === hand[chain[chain.length - 1]].rank + 1) {
          chain.push(g[j]);
          if (chain.length >= 3) push(chain.slice());
        } else break;
      }
    }
  }
  return out;
}

/* Best way to arrange a hand: maximise melded value, minimise deadwood.
   Exhaustive over disjoint meld combinations, memoised on the used-card mask.
   Hands are <= 11 cards so this is instant. */
function bestArrangement(hand) {
  const melds = allMelds(hand);
  const memo = new Map();

  const deadwoodOf = (used) => {
    let t = 0;
    for (let i = 0; i < hand.length; i++) if (!(used & (1 << i))) t += V(hand[i]);
    return t;
  };

  function rec(used) {
    if (memo.has(used)) return memo.get(used);
    let best = { dw: deadwoodOf(used), melds: [] };
    for (const m of melds) {
      if ((m.mask & used) === 0) {
        const sub = rec(used | m.mask);
        if (sub.dw < best.dw) best = { dw: sub.dw, melds: [m.idx].concat(sub.melds) };
      }
    }
    memo.set(used, best);
    return best;
  }

  const r = rec(0);
  const usedMask = r.melds.reduce((m, idx) => m | idx.reduce((a, i) => a | (1 << i), 0), 0);
  const dead = [];
  hand.forEach((c, i) => { if (!(usedMask & (1 << i))) dead.push(i); });
  return { melds: r.melds, deadwood: r.dw, deadwoodIdx: dead, meldedMask: usedMask };
}

const KNOCK_LIMIT = 10;
const canKnock = (hand, limit = KNOCK_LIMIT) => bestArrangement(hand).deadwood <= limit;
const isGin = (hand) => bestArrangement(hand).deadwood === 0;

/* ---------------------------------------------------------------- layoff */
/* Opponent may extend the knocker's melds with their own deadwood. */
function layoff(deadCards, knockerMelds, knockerHand) {
  const melds = knockerMelds.map((idx) => idx.map((i) => knockerHand[i]));
  const remaining = [];
  let laid = 0;

  for (const c of deadCards) {
    let placed = false;
    for (const m of melds) {
      const sameRank = m.every((x) => x.rank === m[0].rank);
      if (sameRank) {
        if (c.rank === m[0].rank && m.length < 4 && !m.some((x) => x.suit === c.suit)) {
          m.push(c); placed = true; break;
        }
      } else {
        const rs = m.map((x) => x.rank).sort((a, b) => a - b);
        if (c.suit === m[0].suit && (c.rank === rs[0] - 1 || c.rank === rs[rs.length - 1] + 1)) {
          m.push(c); placed = true; break;
        }
      }
    }
    if (placed) laid += V(c); else remaining.push(c);
  }
  return { laidValue: laid, remaining, remainingValue: remaining.reduce((t, c) => t + V(c), 0) };
}

/* ---------------------------------------------------------------- scoring */
const GIN_BONUS = 25;
const UNDERCUT_BONUS = 25;
const BIG_GIN_BONUS = 31;

function scoreHand(knockerHand, opponentHand, gin, mods = {}) {
  const k = bestArrangement(knockerHand);
  const o = bestArrangement(opponentHand);
  const ginB = (mods.ginBonus ?? GIN_BONUS);
  const undercutB = (mods.undercutBonus ?? UNDERCUT_BONUS);

  if (gin) {
    return { winner: "knocker", points: o.deadwood + ginB, gin: true, undercut: false,
             knockerDw: 0, oppDw: o.deadwood };
  }

  const oppDead = o.deadwoodIdx.map((i) => opponentHand[i]);
  const lo = layoff(oppDead, k.melds, knockerHand);
  const oppAfter = lo.remainingValue;

  if (oppAfter <= k.deadwood) {
    return { winner: "opponent", points: (k.deadwood - oppAfter) + undercutB,
             gin: false, undercut: true, knockerDw: k.deadwood, oppDw: oppAfter,
             laidOff: lo.laidValue };
  }
  return { winner: "knocker", points: oppAfter - k.deadwood, gin: false, undercut: false,
           knockerDw: k.deadwood, oppDw: oppAfter, laidOff: lo.laidValue };
}

/* ---------------------------------------------------------------- match */
class GinHand {
  constructor(rng = Math.random, handSize = 10, mods = {}) {
    this.rng = rng;
    this.mods = mods;
    this.handSize = handSize;
    const deck = [];
    for (const s of SUITS_G) for (let r = 1; r <= 13; r++) deck.push({ rank: r, suit: s });
    for (let i = deck.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }
    this.stock = deck;
    this.player = this.stock.splice(0, handSize);
    this.cpu = this.stock.splice(0, handSize);
    this.discard = [this.stock.pop()];
    this.turn = "player";
    this.phase = "draw";          // draw -> discard
    this.over = false;
    this.result = null;
    this.log = [];
  }

  knockLimit(who) {
    return (who === "player" ? (this.mods.knockLimit ?? KNOCK_LIMIT) : KNOCK_LIMIT);
  }

  hand(who) { return who === "player" ? this.player : this.cpu; }

  drawStock(who) {
    if (this.phase !== "draw" || this.turn !== who) return null;
    if (!this.stock.length) { this.endDraw(); return null; }
    const c = this.stock.pop();
    this.hand(who).push(c);
    this.phase = "discard";
    return c;
  }

  drawDiscard(who) {
    if (this.phase !== "draw" || this.turn !== who || !this.discard.length) return null;
    const c = this.discard.pop();
    this.hand(who).push(c);
    this.phase = "discard";
    return c;
  }

  discardCard(who, index) {
    if (this.phase !== "discard" || this.turn !== who) return null;
    const h = this.hand(who);
    if (index < 0 || index >= h.length) return null;
    const c = h.splice(index, 1)[0];
    this.discard.push(c);
    this.phase = "draw";
    this.turn = who === "player" ? "cpu" : "player";
    if (this.stock.length <= 2) this.endDraw();
    return c;
  }

  /* Knock after drawing, before discarding: discard one, then score. */
  knock(who, discardIndex) {
    if (this.phase !== "discard" || this.turn !== who) return null;
    const h = this.hand(who);
    const kept = h.slice();
    kept.splice(discardIndex, 1);
    const arr = bestArrangement(kept);
    if (arr.deadwood > this.knockLimit(who)) return null;

    this.discard.push(h.splice(discardIndex, 1)[0]);
    const opp = who === "player" ? this.cpu : this.player;
    const gin = arr.deadwood === 0;
    const r = scoreHand(kept, opp, gin, this.mods);
    this.over = true;
    this.result = {
      ...r,
      knocker: who,
      winner: r.winner === "knocker" ? who : (who === "player" ? "cpu" : "player"),
    };
    return this.result;
  }

  endDraw() {
    // stock exhausted: hand is a wash
    this.over = true;
    this.result = { winner: null, points: 0, gin: false, undercut: false, wash: true };
  }
}

/* ---------------------------------------------------------------- cpu */
/* Draws the discard only if it measurably lowers deadwood; discards the highest
   card that isn't doing work; knocks when under the limit and ahead. */
const CpuGin = {
  wouldImprove(hand, card) {
    const before = bestArrangement(hand).deadwood;
    const probe = hand.concat([card]);
    const arr = bestArrangement(probe);
    // best deadwood after discarding the worst remaining card
    let best = 99;
    for (let i = 0; i < probe.length; i++) {
      const t = probe.slice(); t.splice(i, 1);
      best = Math.min(best, bestArrangement(t).deadwood);
    }
    return before - best;
  },

  chooseDraw(h) {
    const top = h.discard[h.discard.length - 1];
    if (!top) return "stock";
    return this.wouldImprove(h.cpu, top) >= 4 ? "discard" : "stock";
  },

  chooseDiscard(hand) {
    let bestI = 0, bestDw = 999;
    for (let i = 0; i < hand.length; i++) {
      const t = hand.slice(); t.splice(i, 1);
      const dw = bestArrangement(t).deadwood;
      // tie-break toward pitching the higher card
      if (dw < bestDw || (dw === bestDw && V(hand[i]) > V(hand[bestI]))) {
        bestDw = dw; bestI = i;
      }
    }
    return bestI;
  },

  takeTurn(h) {
    const src = this.chooseDraw(h);
    if (src === "discard") h.drawDiscard("cpu"); else h.drawStock("cpu");
    if (h.over) return;
    const di = this.chooseDiscard(h.cpu);
    const kept = h.cpu.slice(); kept.splice(di, 1);
    const arr = bestArrangement(kept);
    if (arr.deadwood <= KNOCK_LIMIT && (arr.deadwood <= 6 || arr.deadwood === 0)) {
      return h.knock("cpu", di);
    }
    h.discardCard("cpu", di);
  },
};

if (typeof module !== "undefined")
  module.exports = { V, allMelds, bestArrangement, canKnock, isGin, layoff, scoreHand,
    GinHand, CpuGin, KNOCK_LIMIT, GIN_BONUS, UNDERCUT_BONUS };
