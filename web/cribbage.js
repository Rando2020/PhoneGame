/* Meldlings — cribbage scoring.
   Exact rules. Returns an ordered CASCADE of events so the UI can tick them up
   one at a time, which is where the dopamine lives. */

const CSUITS = ["S", "H", "C", "D"];
const CRANK_LABEL = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const cval = (c, mods = {}) => (mods.aceEleven && c.rank === 1 ? 11 : Math.min(10, c.rank));

const cDeck = () => {
  const d = [];
  for (const s of CSUITS) for (let r = 1; r <= 13; r++) d.push({ rank: r, suit: s });
  return d;
};
const cShuf = (a) => {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const cardStr = (c) => CRANK_LABEL[c.rank] + (SUIT_SYM ? SUIT_SYM[c.suit] : c.suit);

/* ---------------------------------------------------------------- count */
/* hand: the kept cards (normally 4). starter: the cut card.
   isCrib: flushes need all five. mods: charm/boss rule bag.
   Returns { events:[{kind,label,points,cards}], base } */
/* A split card is two ranks at once. Rather than special-casing every rule, we
   expand the hand into each combination and keep the best — with at most a few
   splits in play that's a handful of counts, not 52-squared. */
function expandSplits(cards) {
  let out = [cards];
  cards.forEach((c, i) => {
    if (!c || c.rank2 === undefined) return;
    const next = [];
    for (const variant of out) {
      const a = variant.slice(); a[i] = Object.assign({}, c, { rank: c.rank, split: true });
      const b = variant.slice(); b[i] = Object.assign({}, c, { rank: c.rank2, split: true });
      next.push(a, b);
    }
    out = next.slice(0, 64);        // hard cap; nobody holds six splits
  });
  return out;
}

function countHand(hand, starter, isCrib = false, mods = {}) {
  const hasSplit = hand.some((c) => c && c.rank2 !== undefined) ||
                   (starter && starter.rank2 !== undefined);
  if (hasSplit) {
    const all = starter ? hand.concat([starter]) : hand.slice();
    let best = null;
    for (const variant of expandSplits(all)) {
      const h = starter ? variant.slice(0, -1) : variant;
      const st = starter ? variant[variant.length - 1] : null;
      const r = countHandCore(h, st, isCrib, mods);
      if (!best || r.base > best.base) best = r;
    }
    return best;
  }
  return countHandCore(hand, starter, isCrib, mods);
}

function countHandCore(hand, starter, isCrib = false, mods = {}) {
  let all = starter ? hand.concat([starter]) : hand.slice();
  // a "dead" suit is inert: it cannot form fifteens, pairs, runs or flushes
  if (mods.deadSuit) all = all.filter((c) => c.suit !== mods.deadSuit);
  const events = [];
  const n = all.length;

  // --- fifteens: every subset summing to exactly 15
  if (!mods.noFifteens) {
    let running = 0;
    const per = mods.fifteenPoints ?? 2;
    for (let m = 1; m < (1 << n); m++) {
      let sum = 0, cards = [];
      for (let i = 0; i < n; i++) if (m & (1 << i)) { sum += cval(all[i], mods); cards.push(all[i]); }
      if (sum === 15 && cards.length >= 2) {
        running += per;
        events.push({ kind: "fifteen", label: `Fifteen ${running}`, points: per, cards });
      }
    }
  }

  // --- pairs
  if (!mods.noPairs) {
    const byRank = {};
    all.forEach((c) => (byRank[c.rank] ||= []).push(c));
    const per = (mods.pairDouble ? 4 : 2) * (mods.pairScale ?? 1);
    for (const r in byRank) {
      const g = byRank[r];
      if (g.length < 2) continue;
      const pairs = (g.length * (g.length - 1)) / 2;
      const name = g.length === 2 ? "Pair" : g.length === 3 ? "Three of a kind" : "Four of a kind";
      events.push({ kind: "pair", label: `${name} of ${CRANK_LABEL[r]}s`, points: pairs * per, cards: g });
    }
  }

  // --- runs: maximal consecutive stretches, counted with multiplicity
  if (!mods.noRuns) {
    const count = {};
    all.forEach((c) => (count[c.rank] = (count[c.rank] || 0) + 1));
    const ranks = Object.keys(count).map(Number).sort((a, b) => a - b);
    let i = 0;
    while (i < ranks.length) {
      let j = i;
      while (j + 1 < ranks.length && ranks[j + 1] === ranks[j] + 1) j++;
      let len = j - i + 1;
      if (len >= 3) {
        const cap = mods.runCap || 99;
        const scored = Math.min(len, cap);
        let mult = 1;
        for (let k = i; k <= j; k++) mult *= count[ranks[k]];
        const bonus = (mods.runCardBonus || 0) * scored;
        const pts = scored * mult + bonus;
        const cards = all.filter((c) => c.rank >= ranks[i] && c.rank <= ranks[j]);
        events.push({
          kind: "run",
          label: mult > 1 ? `${mult} runs of ${scored}` : `Run of ${scored}`,
          points: pts, cards,
        });
      }
      i = j + 1;
    }
  }

  // --- flush
  const need = mods.flushNeed || 4;
  const suits = {};
  const flushHand = mods.deadSuit ? hand.filter((c) => c.suit !== mods.deadSuit) : hand;
  const wilds = flushHand.filter((c) => c.enh === "wild").length;
  flushHand.forEach((c) => {
    if (c.enh === "wild") return;
    suits[c.suit] = (suits[c.suit] || 0) + 1;
  });
  for (const k in suits) suits[k] += wilds;
  if (!Object.keys(suits).length && wilds >= need) suits[flushHand[0].suit] = wilds;
  for (const s in suits) {
    if (suits[s] >= Math.min(need, hand.length) && !mods.noFlush) {
      const withStarter = starter && starter.suit === s;
      if (isCrib && !withStarter) break;              // crib flush needs all five
      let pts = suits[s] + (withStarter ? 1 : 0);
      events.push({
        kind: "flush",
        label: `Flush of ${pts}`,
        points: pts,
        cards: flushHand.filter((c) => c.suit === s).concat(withStarter ? [starter] : []),
      });
      break;
    }
  }

  // --- nobs
  if (starter && !mods.noNobs) {
    const j = hand.find((c) => c.rank === 11 && c.suit === starter.suit &&
      (!mods.deadSuit || c.suit !== mods.deadSuit));
    if (j) events.push({ kind: "nobs", label: "Nobs", points: mods.nobsPoints ?? 1, cards: [j] });
  }

  const base = events.reduce((t, e) => t + e.points, 0);
  return { events, base };
}

const countPoints = (hand, starter, isCrib = false, mods = {}) =>
  countHand(hand, starter, isCrib, mods).base;

/* ---------------------------------------------------------------- keep choice */
/* All ways to keep k of the dealt cards, with the count each would score against
   a given starter. Used for the "best keep" coaching readout and for AI play. */
function keepOptions(dealt, starter, keep = 4, mods = {}) {
  const out = [];
  const n = dealt.length;
  const rec = (start, chosen) => {
    if (chosen.length === keep) {
      const hand = chosen.map((i) => dealt[i]);
      out.push({ idx: chosen.slice(), points: countPoints(hand, starter, false, mods) });
      return;
    }
    for (let i = start; i < n; i++) { chosen.push(i); rec(i + 1, chosen); chosen.pop(); }
  };
  rec(0, []);
  return out.sort((a, b) => b.points - a.points);
}

/* Expected value of a keep across every possible starter still in the deck.
   This is what a strong cribbage player approximates in their head. */
function keepEV(dealt, keepIdx, mods = {}) {
  const hand = keepIdx.map((i) => dealt[i]);
  const seen = new Set(dealt.map((c) => c.rank + c.suit));
  let total = 0, n = 0;
  for (const c of cDeck()) {
    if (seen.has(c.rank + c.suit)) continue;
    total += countPoints(hand, c, false, mods);
    n++;
  }
  return n ? total / n : 0;
}

/* Fast EV: sample one representative card per rank, weighted by how many of that
   rank remain in the given pool. Accurate enough to rank keeps, ~40x cheaper than
   iterating the whole deck — and because it reads the ROUND's remaining stock,
   tracking the deck genuinely improves the estimate. */
function keepEVFast(hand, pool, mods = {}) {
  const byRank = {};
  for (const c of pool) (byRank[c.rank] ||= []).push(c);
  let total = 0, weight = 0;
  for (const r in byRank) {
    const g = byRank[r];
    total += countPoints(hand, g[0], false, mods) * g.length;
    weight += g.length;
  }
  return weight ? total / weight : countPoints(hand, null, false, mods);
}

/* Rank every keep by fast EV against a pool. Returns sorted options. */
function keepOptionsEV(dealt, pool, keep = 4, mods = {}) {
  const out = [];
  const rec = (start, chosen) => {
    if (chosen.length === keep) {
      const hand = chosen.map((i) => dealt[i]);
      out.push({ idx: chosen.slice(), ev: keepEVFast(hand, pool, mods),
                 sure: countPoints(hand, null, false, mods) });
      return;
    }
    for (let i = start; i < dealt.length; i++) { chosen.push(i); rec(i + 1, chosen); chosen.pop(); }
  };
  rec(0, []);
  return out.sort((a, b) => b.ev - a.ev);
}

function bestKeepByEV(dealt, keep = 4, mods = {}) {
  const opts = [];
  const rec = (start, chosen) => {
    if (chosen.length === keep) { opts.push(chosen.slice()); return; }
    for (let i = start; i < dealt.length; i++) { chosen.push(i); rec(i + 1, chosen); chosen.pop(); }
  };
  rec(0, []);
  let best = null, bestEV = -1;
  for (const idx of opts) {
    const ev = keepEV(dealt, idx, mods);
    if (ev > bestEV) { bestEV = ev; best = idx; }
  }
  return { idx: best, ev: bestEV };
}

if (typeof module !== "undefined")
  module.exports = { CSUITS, CRANK_LABEL, cval, cDeck, cShuf, countHand, countPoints,
    keepOptions, keepEV, bestKeepByEV, keepEVFast, keepOptionsEV, expandSplits };
