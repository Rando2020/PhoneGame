/* Twist playtest proxy: how often a twist changes the best play.
   Pass 16 valued a keep by its hand EV only. Pass 17 adds what that missed:
   - the Crib: a keep's value is hand EV + the thrown cards' Crib EV, at the
     Crib's real mult (0.5, or 1 under Open Crib). Crib EV is estimated on
     S shared samples per deal (the other Crib cards and the cut, drawn from
     the stock), so every keep of a deal is valued on the same samples.
   - mulligans (Second Look): per round, a greedy player mulligans whenever
     the best keep is worth less than a fresh deal on average. "Changed" is
     a round where that player wants a third mulligan (base is 2).
   Units: per deal for keep twists, per round for Second Look (said below).
   "Changed" for a keep twist: the plain best keep (hand + Crib) is no longer
   best under the twist (ties within 1e-9 don't count).
     node tools/sim/twist_keep.js [deals per twist] [ids,comma,separated]  */
const path = require("path");
const WEB = path.join(__dirname, "..", "..", "web");
global.SUIT_SYM = { S: "♠", H: "♥", C: "♣", D: "♦" };
const C = require(path.join(WEB, "cribbage.js"));
Object.assign(global, { countHand: C.countHand, countPoints: C.countPoints, keepOptions: C.keepOptions,
  keepEVFast: C.keepEVFast, keepOptionsEV: C.keepOptionsEV, cDeck: C.cDeck, cShuf: C.cShuf });
const R = require(path.join(WEB, "cribrogue.js"));
const M = require(path.join(WEB, "meta.js"));
if (!global.makeRng && M.makeRng) global.makeRng = M.makeRng;
const N = +(process.argv[2] || 2000);
const S = 24;                                   // Crib samples per deal
const DECKS = Object.keys(R.CRIB_DECKS);
const key = (idx) => idx.slice().sort((a, b) => a - b).join(",");

/* Candidates (pass 17): rules the engine already scores, never shipped as twists. */
const CANDIDATES = [
  { id: "wrap", name: "Round the Bend", text: "Runs may wrap K-A-2.", rule: { wrapRuns: true } },
  { id: "aces11", name: "Aces High", text: "Aces count 11 toward fifteens.", rule: { aceEleven: true } },
  { id: "deal7", name: "Generous Deal", text: "You are dealt 7 cards.", rule: { dealtBonus: 1 } },
  { id: "runs2", name: "Short Runs", text: "Runs of 2 count.", rule: { runNeed: 2 } },
  { id: "crib5", name: "Wide Crib", text: "Your Crib counts 5 cards.", rule: { cribKeep: 5 } },
];
const TWISTS = R.CRIB_TWISTS.concat(CANDIDATES);
const want = process.argv[3] ? process.argv[3].split(",") : TWISTS.map((t) => t.id);

function modsWith(run, rule) {
  // the shipped twist merge (CribRun.rules) for shipped twists; for candidates
  // the same "only helps" idea, key by key
  const r = Object.assign({}, run.rules());
  for (const k in rule) {
    const v = rule[k];
    if (k === "flushNeed" || k === "runNeed") r[k] = Math.min(r[k] || 99, v);
    else if (k === "fifteenPoints" || k === "nobsPoints" || k === "cribKeep") r[k] = Math.max(r[k] || 0, v);
    else if (k === "mulliganBonus" || k === "dealtBonus") r[k] = (r[k] || 0) + v;
    else r[k] = v;
  }
  return r;
}

/* Every keep of `dealt`, valued hand EV + Crib EV x mult, on shared samples. */
function values(dealt, stock, keepN, mods, samples) {
  const mult = mods.cribFull ? 1 : 0.5;
  const cribN = Math.max(4, mods.cribKeep || 4);
  return C.keepOptionsEV(dealt, stock, keepN, mods).map((o) => {
    const thrown = dealt.filter((_, i) => !o.idx.includes(i));
    let crib = 0;
    for (const s of samples) {
      const cards = thrown.slice(0, cribN).concat(s.others).slice(0, cribN);
      crib += C.countHand(cards, s.cut, true, mods).base;
    }
    return { idx: o.idx, v: o.ev + mult * crib / samples.length };
  }).sort((a, b) => b.v - a.v);
}

function samplesFrom(stock, rng, n) {
  const out = [];
  for (let i = 0; i < S; i++) {
    const d = C.cShuf(stock.slice(), rng);
    out.push({ others: d.slice(0, n), cut: d[n] });
  }
  return out;
}

function keepTwist(tw) {
  let changed = 0, n = 0;
  for (let i = 0; n < N; i++) {
    const run = new R.CribRun(DECKS[i % DECKS.length], undefined, undefined, 90000 + i);
    run.wagerAt = {}; run.round = 1; run.twistPlan = {};
    const rd = new R.CribRound(run);
    if (rd.newDeal() === null) continue;
    const g = makeRng(777 + i);
    const k = rd.keepCount();
    const plainMods = rd.mods;
    const smp = samplesFrom(rd.stock.slice(1), g, 4);    // stock[0] is held back for a 7th card
    const plain = values(rd.dealt, rd.stock, k, plainMods, smp)[0];
    const mods2 = modsWith(run, tw.rule);
    let dealt2 = rd.dealt, stock2 = rd.stock;
    if (tw.rule.dealtBonus) { dealt2 = rd.dealt.concat(rd.stock.slice(0, tw.rule.dealtBonus)); stock2 = rd.stock.slice(tw.rule.dealtBonus); }
    const v2 = values(dealt2, stock2, k, mods2, smp);
    const plainUnder = v2.find((o) => key(o.idx) === key(plain.idx));
    if (v2[0].v > plainUnder.v + 1e-9) changed++;
    n++;
  }
  return { twist: tw.id, name: tw.name, unit: "deals", n, changed_pct: +(100 * changed / n).toFixed(1) };
}

/* Second Look: rounds where a greedy mulligan player wants a third mulligan. */
function mulliganTwist(tw) {
  let changed = 0, n = 0;
  // a fresh deal's average best value, from 200 random deals (plain rules)
  const g0 = makeRng(4242);
  let fresh = 0;
  for (let i = 0; i < 200; i++) {
    const d = C.cShuf(C.cDeck(), g0);
    const smp = samplesFrom(d.slice(6), g0, 2);
    fresh += values(d.slice(0, 6), d.slice(6), 4, { flushNeed: 4, fifteenPoints: 2, nobsPoints: 1, runNeed: 3, cribKeep: 4 }, smp)[0].v;
  }
  fresh /= 200;
  for (let i = 0; n < N; i++) {
    const run = new R.CribRun(DECKS[i % DECKS.length], undefined, undefined, 90000 + i);
    run.wagerAt = {}; run.round = 1; run.twistPlan = {};
    const rd = new R.CribRound(run);
    const g = makeRng(999 + i);
    let deck = rd.stock.slice(), wants = 0;
    for (let deal = 0; deal < 4 && deck.length > 12; deal++) {
      for (let tries = 0; tries < 4 && deck.length >= 12; tries++) {
        const dealt = deck.splice(0, 6);
        const smp = samplesFrom(deck, g, 2);
        const best = values(dealt, deck, 4, rd.mods, smp)[0].v;
        if (best >= fresh) break;
        wants++;
      }
    }
    if (wants > 2) changed++;
    n++;
  }
  return { twist: tw.id, name: tw.name, unit: "rounds (wants a 3rd mulligan)", n, changed_pct: +(100 * changed / n).toFixed(1), fresh_value: +fresh.toFixed(2) };
}

for (const tw of TWISTS) {
  if (!want.includes(tw.id)) continue;
  console.log(JSON.stringify(tw.rule.mulliganBonus ? mulliganTwist(tw) : keepTwist(tw)));
}
