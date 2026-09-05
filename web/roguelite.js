/* Meldlings — roguelite core.
   Balatro skeleton, Rummy 500 body:
     round = "reach the target within N turns"
     turn  = draw -> lay melds (scoring beats) -> lay off -> discard
     score = base (pip value) x mult, with charms firing on each lay
   Measured design notes in GIN_DESIGN.md / ROGUE_DESIGN.md. */

const RSUITS = ["S", "H", "C", "D"];
const pip = (c) => (c.aceHigh && c.rank === 1 ? 15 : Math.min(10, c.rank));

const mkDeck = () => {
  const d = [];
  for (const s of RSUITS) for (let r = 1; r <= 13; r++) d.push({ rank: r, suit: s });
  return d;
};
const rshuf = (a) => {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

/* ---------------------------------------------------------------- meld shape */
const isSetCards = (cs) => cs.length >= 3 && cs.every((c) => c.rank === cs[0].rank) &&
  new Set(cs.map((c) => c.suit)).size === cs.length;

function isRunCards(cs, wrap = false) {
  if (cs.length < 3) return false;
  if (!cs.every((c) => c.suit === cs[0].suit)) return false;
  const r = cs.map((c) => c.rank).sort((a, b) => a - b);
  let ok = true;
  for (let i = 1; i < r.length; i++) if (r[i] !== r[i - 1] + 1) ok = false;
  if (ok) return true;
  if (wrap && r[0] === 1) {            // K-A-2 style wrap
    const hi = r.slice(1).concat([14]).sort((a, b) => a - b);
    let w = true;
    for (let i = 1; i < hi.length; i++) if (hi[i] !== hi[i - 1] + 1) w = false;
    if (w) return true;
  }
  return false;
}

const isPrepCards = (cs) => cs.length === 2 &&
  (cs[0].rank === cs[1].rank ||
   (cs[0].suit === cs[1].suit && Math.abs(cs[0].rank - cs[1].rank) === 1));

/* What kind of lay is this selection, if any? */
function layKind(cs, mods = {}) {
  if (isSetCards(cs)) return "set";
  if (isRunCards(cs, mods.wrapRuns)) return "run";
  if (isPrepCards(cs) && !mods.noPrep) return "prep";
  return null;
}

/* Can this single card extend an existing table meld? */
function extendTarget(card, table) {
  for (const m of table) {
    const cs = m.cards;
    if (m.kind === "set" || (m.kind === "prep" && cs[0].rank === cs[1].rank)) {
      if (card.rank === cs[0].rank && cs.length < 4 && !cs.some((x) => x.suit === card.suit)) return m;
    } else {
      if (card.suit !== cs[0].suit) continue;
      const rs = cs.map((x) => x.rank).sort((a, b) => a - b);
      if (card.rank === rs[0] - 1 || card.rank === rs[rs.length - 1] + 1) return m;
    }
  }
  return null;
}

/* ---------------------------------------------------------------- charms */
/* tier 1 = meld triggers, tier 2 = multipliers, tier 3 = rule-breakers */
const CHARMS = [
  // --- tier 1: flat base, fires on a matching lay
  { id: "runner",   name: "Runner",     tier: 1, cost: 5, text: "Runs gain +5 base.",
    onLay: (ctx) => { if (ctx.kind === "run") { ctx.base += 5; return true; } } },
  { id: "rallier",  name: "Rallier",    tier: 1, cost: 5, text: "Sets gain +5 base.",
    onLay: (ctx) => { if (ctx.kind === "set") { ctx.base += 5; return true; } } },
  { id: "prepper",  name: "Prepper",    tier: 1, cost: 4, text: "PREPs gain +4 base.",
    onLay: (ctx) => { if (ctx.kind === "prep") { ctx.base += 4; return true; } } },
  { id: "spadebound", name: "Spadebound", tier: 1, cost: 6, text: "+3 base per ♠ in the meld.",
    onLay: (ctx) => { const n = ctx.cards.filter((c) => c.suit === "S").length;
      if (n) { ctx.base += 3 * n; return true; } } },
  { id: "heartbound", name: "Heartbound", tier: 1, cost: 6, text: "+3 base per ♥ in the meld.",
    onLay: (ctx) => { const n = ctx.cards.filter((c) => c.suit === "H").length;
      if (n) { ctx.base += 3 * n; return true; } } },
  { id: "longhand", name: "Long Hand",  tier: 1, cost: 7, text: "+4 base per card beyond 3.",
    onLay: (ctx) => { const x = ctx.cards.length - 3;
      if (x > 0) { ctx.base += 4 * x; return true; } } },

  // --- tier 2: multipliers
  { id: "sharpener", name: "Sharpener", tier: 2, cost: 8, text: "+0.5 mult per run laid this round.",
    onLay: (ctx) => { const n = ctx.round.laid.filter((l) => l.kind === "run").length;
      if (n) { ctx.mult += 0.5 * n; return true; } } },
  { id: "collector", name: "Collector", tier: 2, cost: 8, text: "+0.4 mult per set laid this round.",
    onLay: (ctx) => { const n = ctx.round.laid.filter((l) => l.kind === "set").length;
      if (n) { ctx.mult += 0.4 * n; return true; } } },
  { id: "momentum", name: "Momentum",  tier: 2, cost: 9, text: "+0.25 mult per meld already laid.",
    onLay: (ctx) => { const n = ctx.round.laid.length;
      if (n) { ctx.mult += 0.25 * n; return true; } } },
  { id: "deepcut",  name: "Deep Cut",  tier: 2, cost: 7, text: "+1 mult if you dug the discard this turn.",
    onLay: (ctx) => { if (ctx.round.dugThisTurn) { ctx.mult += 1; return true; } } },
  { id: "keystone", name: "Keystone",  tier: 2, cost: 10, text: "x1.5 mult, always.",
    onLay: (ctx) => { ctx.mult *= 1.5; return true; } },
  { id: "crescendo", name: "Crescendo", tier: 2, cost: 12, text: "x1.25 mult, compounding each lay this round.",
    onLay: (ctx) => { ctx.mult *= Math.pow(1.25, ctx.round.laid.length + 1); return true; } },
  { id: "twinsuit", name: "Twin Suit", tier: 2, cost: 10, text: "x1.6 mult if the meld is all one suit.",
    onLay: (ctx) => { if (new Set(ctx.cards.map(c=>c.suit)).size === 1) { ctx.mult *= 1.6; return true; } } },
  { id: "fatstack", name: "Fat Stack", tier: 2, cost: 11, text: "x1.35 mult on melds of 4+ cards.",
    onLay: (ctx) => { if (ctx.cards.length >= 4) { ctx.mult *= 1.35; return true; } } },
  { id: "engine",   name: "Engine",    tier: 2, cost: 13, text: "x2 mult on every third lay this round.",
    onLay: (ctx) => { if ((ctx.round.laid.length + 1) % 3 === 0) { ctx.mult *= 2; return true; } } },

  // --- tier 3: rule-breakers
  { id: "loosemeld", name: "Loose Meld", tier: 3, cost: 9, text: "PREPs score at full value, not half.",
    rule: { prepFull: true } },
  { id: "excavator", name: "Excavator", tier: 3, cost: 10, text: "Digging the discard is free.",
    rule: { freeDig: true } },
  { id: "acezero",  name: "Ace Zero",   tier: 3, cost: 9, text: "Aces are 0 deadwood and 15 base.",
    rule: { aceHigh: true } },
  { id: "longcon",  name: "Long Con",   tier: 3, cost: 11, text: "Runs may wrap K-A-2.",
    rule: { wrapRuns: true } },
  { id: "secondwind", name: "Second Wind", tier: 3, cost: 10, text: "+3 turns each round.",
    rule: { turnBonus: 3 } },
  { id: "widehand", name: "Wide Hand",  tier: 3, cost: 8, text: "+2 hand size.",
    rule: { handBonus: 2 } },
];

/* ---------------------------------------------------------------- decks */
const MELDLING_DECKS = {
  pip:    { name: "Pip",    suit: "S", text: "+3 digs each round.",
            rule: { digBonus: 3 } },
  thump:  { name: "Thump",  suit: "H", text: "+12 base on your first lay each round.",
            rule: { firstLayBonus: 12 } },
  clover: { name: "Clover", suit: "C", text: "+1 hand size, +1 turn.",
            rule: { handBonus: 1, turnBonus: 1 } },
  facet:  { name: "Facet",  suit: "D", text: "Runs x1.55 mult, sets x0.8.",
            rule: { runMult: 1.55, setMult: 0.8 } },
};

/* ---------------------------------------------------------------- bosses */
const BOSSES = [
  { act: 1, art: "deadwood", name: "Deadwood",      text: "Unmelded cards cost double at round end.", rule: { deadwoodMult: 2 } },
  { act: 2, art: "shuffler", name: "The Shuffler",  text: "The discard pile is face down — no digging.", rule: { noDig: true } },
  { act: 3, art: "jokester", name: "Jokester",      text: "Runs score half.",                        rule: { runMult: 0.5 } },
  { act: 4, art: "shuffler", name: "The Reshuffler",text: "Only one meld may be laid per turn.",     rule: { oneLayPerTurn: true } },
  { act: 5, art: "kingpin",  name: "Kingpin",       text: "PREP melds score nothing.",               rule: { prepZero: true } },
];

/* ---------------------------------------------------------------- run */
const ACTS = 5, ROUNDS_PER_ACT = 5;
/* Ladder is tunable; see ROGUE_DESIGN.md for the sweep that set these. */
const LADDER = { baseTarget: 30, growth: 1.14 };
const BASE_TURNS = 12, BASE_HAND = 12, BASE_DIGS = 3;

class RogueRun {
  constructor(meldling) {
    this.meldling = meldling;
    this.deck = MELDLING_DECKS[meldling];
    this.act = 1;
    this.round = 1;
    this.essence = 6;
    this.charms = [];
    this.best = 0;
  }
  roundIndex() { return (this.act - 1) * ROUNDS_PER_ACT + this.round; }  // 1..25
  target() { return Math.round(LADDER.baseTarget * Math.pow(LADDER.growth, this.roundIndex() - 1)); }
  isBossRound() { return this.round === ROUNDS_PER_ACT; }
  boss() { return this.isBossRound() ? BOSSES[this.act - 1] : null; }

  /* Merge every passive rule: deck + charms + boss. */
  rules() {
    const r = { deadwoodMult: 1, runMult: 1, setMult: 1, prepRate: 0.5,
                turnBonus: 0, handBonus: 0, digBonus: 0, firstLayBonus: 0 };
    const merge = (src) => {
      for (const k in src) {
        if (k === "runMult" || k === "setMult") r[k] *= src[k];
        else if (typeof src[k] === "number") r[k] = (r[k] || 0) + src[k];
        else r[k] = src[k];
      }
    };
    if (this.deck.rule) merge(this.deck.rule);
    for (const c of this.charms) if (c.rule) merge(c.rule);
    const b = this.boss();
    if (b) merge(b.rule);
    if (r.prepFull) r.prepRate = 1;
    if (r.prepZero) r.prepRate = 0;
    return r;
  }

  advance() {
    this.round++;
    if (this.round > ROUNDS_PER_ACT) { this.round = 1; this.act++; }
    return this.act > ACTS;
  }

  shopOffer(n = 3) {
    const owned = new Set(this.charms.map((c) => c.id));
    const pool = CHARMS.filter((c) => !owned.has(c.id));
    return rshuf(pool.slice()).slice(0, n);
  }
}

/* ---------------------------------------------------------------- round */
class Round {
  constructor(run) {
    this.run = run;
    this.mods = run.rules();
    this.target = run.target();
    this.turnsLeft = BASE_TURNS + this.mods.turnBonus;
    this.digsLeft = Math.max(0, BASE_DIGS + this.mods.digBonus - (this.mods.noDig ? 99 : 0));
    this.handSize = BASE_HAND + this.mods.handBonus;
    this.score = 0;
    this.laid = [];             // { kind, total }
    this.table = [];            // { kind, cards }
    this.dugThisTurn = false;
    this.laysThisTurn = 0;
    this.phase = "draw";
    this.over = false;
    this.won = false;
    this.lastScore = null;

    const d = rshuf(mkDeck());
    if (this.mods.aceHigh) d.forEach((c) => { if (c.rank === 1) c.aceHigh = true; });
    this.stock = d;
    this.hand = this.stock.splice(0, this.handSize);
    this.discard = [this.stock.pop()];
  }

  canDig() { return !this.mods.noDig && (this.mods.freeDig || this.digsLeft > 0); }

  draw(src) {
    if (this.phase !== "draw" || this.over) return null;
    if (src === "dig") {
      if (!this.canDig() || !this.discard.length) return null;
      const c = this.discard.pop();
      this.hand.push(c);
      if (!this.mods.freeDig) this.digsLeft--;
      this.dugThisTurn = true;
    } else {
      if (!this.stock.length) { this.finish(); return null; }
      this.hand.push(this.stock.pop());
    }
    this.phase = "act";
    return this.hand[this.hand.length - 1];
  }

  /* The scoring pipeline. Returns the breakdown so the UI can animate it. */
  scoreLay(cards, kind) {
    const ctx = {
      cards, kind, base: cards.reduce((t, c) => t + pip(c), 0), mult: 1,
      round: this, run: this.run, fired: [],
    };
    if (kind === "prep") ctx.base = Math.round(ctx.base * this.mods.prepRate);
    if (this.laid.length === 0 && this.mods.firstLayBonus) {
      ctx.base += this.mods.firstLayBonus;
      ctx.fired.push(this.run.deck.name);
    }
    for (const ch of this.run.charms) {
      if (ch.onLay && ch.onLay(ctx)) ctx.fired.push(ch.name);
    }
    if (kind === "run") ctx.mult *= this.mods.runMult;
    if (kind === "set") ctx.mult *= this.mods.setMult;
    ctx.total = Math.max(0, Math.round(ctx.base * ctx.mult));
    return ctx;
  }

  layMeld(indices) {
    if (this.phase !== "act" || this.over) return null;
    if (this.mods.oneLayPerTurn && this.laysThisTurn >= 1) return null;
    const cards = indices.map((i) => this.hand[i]);
    const kind = layKind(cards, this.mods);
    if (!kind) return null;

    const res = this.scoreLay(cards, kind);
    indices.slice().sort((a, b) => b - a).forEach((i) => this.hand.splice(i, 1));
    this.table.push({ kind, cards });
    this.score += res.total;
    this.laid.push({ kind, total: res.total });
    this.laysThisTurn++;
    this.lastScore = res;
    this.checkWin();
    return res;
  }

  /* Extend a table meld with one card. Scores that card, base x mult. */
  layOff(handIndex) {
    if (this.phase !== "act" || this.over) return null;
    const card = this.hand[handIndex];
    const target = extendTarget(card, this.table);
    if (!target) return null;
    const res = this.scoreLay([card], target.kind === "prep" ? "prep" : target.kind);
    target.cards.push(card);
    if (target.kind === "prep" && target.cards.length >= 3)
      target.kind = target.cards.every((c) => c.rank === target.cards[0].rank) ? "set" : "run";
    this.hand.splice(handIndex, 1);
    this.score += res.total;
    this.laid.push({ kind: "off", total: res.total });
    this.lastScore = res;
    this.checkWin();
    return res;
  }

  discardCard(index) {
    if (this.phase !== "act" || this.over) return null;
    const c = this.hand.splice(index, 1)[0];
    this.discard.push(c);
    this.turnsLeft--;
    this.dugThisTurn = false;
    this.laysThisTurn = 0;
    this.phase = "draw";
    if (this.turnsLeft <= 0 || !this.stock.length) this.finish();
    return c;
  }

  deadwood() {
    return this.hand.reduce((t, c) => t + (c.aceHigh && c.rank === 1 ? 0 : pip(c)), 0)
      * this.mods.deadwoodMult;
  }

  checkWin() {
    if (this.score >= this.target) this.won = true;
  }

  /* Deadwood does NOT gate the round -- it taxes the economy.
     Pass/fail is gross score vs target; unmelded cards cost you Essence, which
     costs you your build. That keeps hoarding painful without making a
     turn-limited round unwinnable while holding a full hand. */
  settle() {
    this.over = true;
    this.deadwoodPenalty = this.deadwood();
    this.goneOut = this.hand.length === 0;
    this.won = this.score >= this.target;
    this.finalScore = this.score;
    this.essenceEarned = this.won
      ? Math.max(2, 6
          + Math.floor(Math.max(0, this.score - this.target) / 25)
          + (this.goneOut ? 6 : 0)
          - Math.floor(this.deadwoodPenalty / 25))
      : 0;
    return this.won;
  }

  finish() { return this.settle(); }
  cashOut() { return this.settle(); }
}

if (typeof module !== "undefined")
  module.exports = { pip, mkDeck, layKind, extendTarget, isSetCards, isRunCards, isPrepCards,
    CHARMS, MELDLING_DECKS, BOSSES, RogueRun, Round,
    ACTS, ROUNDS_PER_ACT, LADDER, BASE_TURNS, BASE_HAND, BASE_DIGS };
