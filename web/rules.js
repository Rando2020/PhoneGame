/* Meldlings — rules + combat engine.
   Deliberately a 1:1 mirror of scripts/cards/meld_rules.gd and
   scripts/game/combat.gd so tuning found here ports straight back to Godot. */

const SUITS = ["S", "H", "C", "D"];
const SUIT_SYM = { S: "\u2660", H: "\u2665", C: "\u2663", D: "\u2666" };
const SUIT_NAMES = { S: "Spades", H: "Hearts", C: "Clubs", D: "Diamonds" };
const RANK_LABEL = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

const Kind = { NONE: 0, PAIR: 1, RUN2: 2, RUN: 3, SET: 4, GRAND: 5 };
const ACTION_NAME = {
  [Kind.NONE]: "",
  [Kind.PAIR]: "BRACE",
  [Kind.RUN2]: "PREP",
  [Kind.RUN]: "STRIKE",
  [Kind.SET]: "RALLY",
  [Kind.GRAND]: "GRAND MELD",
};

function newDeck() {
  const d = [];
  for (const s of SUITS) for (let r = 1; r <= 13; r++) d.push({ rank: r, suit: s });
  return d;
}

function shuffle(a, rng = Math.random) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const cardLabel = (c) => RANK_LABEL[c.rank] + SUIT_SYM[c.suit];

// ---------------------------------------------------------------- meld rules
const ranks = (cs) => cs.map((c) => c.rank).sort((a, b) => a - b);
const sameRank = (cs) => cs.every((c) => c.rank === cs[0].rank);
const sameSuit = (cs) => cs.every((c) => c.suit === cs[0].suit);

function consecutive(rs) {
  for (let i = 1; i < rs.length; i++) if (rs[i] !== rs[i - 1] + 1) return false;
  return true;
}

function isRun(cs) {
  return sameSuit(cs) && consecutive(ranks(cs));
}

function classify(cards) {
  const n = cards.length;
  if (n < 2) return { kind: Kind.NONE, valid: false, label: "Select 2 or more cards", action: "" };

  if (sameRank(cards)) {
    const seen = new Set();
    for (const c of cards) {
      if (seen.has(c.suit))
        return { kind: Kind.NONE, valid: false, label: "Duplicate suit in set", action: "" };
      seen.add(c.suit);
    }
    if (n === 2) return res(Kind.PAIR, "PAIR");
    if (n === 4) return res(Kind.GRAND, "4-SUIT SET");
    return res(Kind.SET, `${n}-CARD SET`);
  }
  if (isRun(cards)) return n === 2 ? res(Kind.RUN2, "2-RUN") : res(Kind.RUN, `${n}-RUN`);
  return { kind: Kind.NONE, valid: false, label: "Not a legal meld", action: "" };
}

const res = (kind, label) => ({ kind, valid: true, label, action: ACTION_NAME[kind] });

/* Could `card` join `selection` and still reach a legal meld?
   This is what drives the dimming hints. */
function canJoin(selection, card) {
  if (selection.length === 0) return true;
  const probe = selection.concat([card]);

  if (sameRank(selection) && card.rank === selection[0].rank && probe.length <= 4) {
    const seen = new Set();
    let ok = true;
    for (const c of probe) {
      if (seen.has(c.suit)) { ok = false; break; }
      seen.add(c.suit);
    }
    if (ok) return true;
  }
  if (sameSuit(selection) && card.suit === selection[0].suit) {
    const r = ranks(selection);
    if (consecutive(r) && (card.rank === r[0] - 1 || card.rank === r[r.length - 1] + 1)) return true;
  }
  return false;
}

/* Every legal meld in a hand, longest first. */
function findMelds(hand) {
  const out = [];
  const byRank = {}, bySuit = {};
  hand.forEach((c, i) => {
    (byRank[c.rank] ||= []).push(i);
    (bySuit[c.suit] ||= []).push(i);
  });
  for (const k in byRank) if (byRank[k].length >= 2) out.push(byRank[k].slice());
  for (const s in bySuit) {
    const idx = bySuit[s].slice().sort((a, b) => hand[a].rank - hand[b].rank);
    let chain = [];
    for (const i of idx) {
      if (!chain.length || hand[i].rank === hand[chain[chain.length - 1]].rank + 1) chain.push(i);
      else { if (chain.length >= 2) out.push(chain.slice()); chain = [i]; }
    }
    if (chain.length >= 2) out.push(chain);
  }
  return out.sort((a, b) => b.length - a.length);
}

// ---------------------------------------------------------------- roster
const ROSTER = {
  pip:      { name: "Pip",        kind: "meldling", suit: "S", hp: 60, blurb: "Cautious. Bonus Block when it BRACEs on spades." },
  thump:    { name: "Thump",      kind: "meldling", suit: "H", hp: 72, blurb: "Stout. Heals a little whenever a RALLY lands." },
  clover:   { name: "Clover",     kind: "meldling", suit: "C", hp: 58, blurb: "Patient. PREP carries an extra card into the next turn." },
  facet:    { name: "Facet",      kind: "meldling", suit: "D", hp: 54, blurb: "Sharp. STRIKE scales harder with run length." },
  deadwood: { name: "Deadwood",   kind: "enemy",  hp: 44, tier: 1, blurb: "Punishes a cluttered hand." },
  shuffler: { name: "The Shuffler", kind: "enemy", hp: 52, tier: 1, blurb: "Reorders the shared deck." },
  jokester: { name: "Jokester",   kind: "elite",  hp: 88, tier: 2, blurb: "Breaks a rule each turn." },
  kingpin:  { name: "Kingpin",    kind: "boss",   hp: 160, tier: 3, blurb: "Melds against you using the same deck." },
};

const RELICS = [
  { id: "whetstone",  name: "Whetstone",  text: "STRIKE deals +4 damage.",            key: "strike_bonus", value: 4 },
  { id: "bulwark",    name: "Bulwark",    text: "BRACE grants +4 Block.",             key: "brace_bonus",  value: 4 },
  { id: "wideeye",    name: "Wide Eye",   text: "Draw 1 extra card each turn.",       key: "draw_bonus",   value: 1 },
  { id: "secondwind", name: "Second Wind",text: "Start each battle with +1 Focus.",   key: "focus_bonus",  value: 1 },
  { id: "emberpip",   name: "Ember Pip",  text: "RALLY applies +2 Burn.",             key: "burn_bonus",   value: 2 },
  { id: "thornmail",  name: "Thornmail",  text: "Start each battle with 3 Thorns.",   key: "thorns_start", value: 3 },
  { id: "deepdeck",   name: "Deep Deck",  text: "Hand size +1.",                      key: "hand_bonus",   value: 1 },
  { id: "luckycut",   name: "Lucky Cut",  text: "Heal 4 after every battle.",         key: "heal_after",   value: 4 },
  // --- rule-breakers: these bend Rummy itself rather than adding a status
  { id: "looseknock",   name: "Loose Knock",   text: "Knock at 15 deadwood instead of 10.", key: "knock_limit",  value: 15 },
  { id: "purist",       name: "Purist",        text: "Gin bonus 25 -> 40.",                 key: "gin_bonus",    value: 40 },
  { id: "counterpunch", name: "Counterpunch",  text: "Undercut bonus 25 -> 40.",            key: "undercut_bonus", value: 40 },
];

// ---------------------------------------------------------------- combat
class Combatant {
  constructor(id, name, hp) {
    Object.assign(this, { id, name, maxHp: hp, hp, block: 0, burn: 0, hex: 0, thorns: 0 });
  }
  alive() { return this.hp > 0; }
  statusLine() {
    const b = [`BLOCK ${this.block}`];
    if (this.burn) b.push(`BURN ${this.burn}`);
    if (this.hex) b.push(`HEX ${this.hex}`);
    if (this.thorns) b.push(`THORNS ${this.thorns}`);
    return b.join("   ");
  }
}

/* All balance lives here. Swept with web/tune.js -- see BALANCE.md.
   Key finding: a hand of 8 can deal damage only 20.9% of the time.
   The sandbox can mutate this object live. */
const TUNING = {
  handSize: 10,
  focus: 2,
  enemyDmg: 0.9,          // scale on enemy attack values
  enemyHpScale: 1.0,
  prepDraw: 3,
  strike: (n) => 5 * n + 4 * (n - 3),
  rally:  (n) => 6 * n,
  brace:  (n) => 8 + n * 2,
  grand:  () => 26,
};
const STRIKE = (n) => TUNING.strike(n);
const RALLY  = (n) => TUNING.rally(n);
const BRACE  = (n) => TUNING.brace(n);

class Combat {
  constructor(run, enemyId, rng = Math.random) {
    this.run = run;
    this.rng = rng;
    this.log = [];

    const pd = ROSTER[run.meldling];
    this.player = new Combatant(run.meldling, pd.name, run.maxHp);
    this.player.hp = run.hp;
    this.player.thorns = run.relicValue("thorns_start");

    const ed = ROSTER[enemyId];
    this.enemy = new Combatant(enemyId, ed.name, Math.round(ed.hp * TUNING.enemyHpScale));

    this.deck = shuffle(newDeck(), rng);
    this.discard = [];
    this.hand = [];
    this.maxFocus = TUNING.focus + run.relicValue("focus_bonus");
    this.focus = this.maxFocus;
    this.turn = 1;
    this.over = false;
    this.victory = false;

    for (let i = 0; i < this.handSize(); i++) this.hand.push(this.drawCard());
    this.rollIntent();
  }

  handSize() { return TUNING.handSize + this.run.relicValue("hand_bonus"); }

  drawCard() {
    if (!this.deck.length) {
      if (!this.discard.length) return null;
      this.deck = shuffle(this.discard.slice(), this.rng);
      this.discard = [];
      this.say("The deck runs out — the discard is reshuffled.");
    }
    return this.deck.pop();
  }

  drawToHand(n = 1) {
    const got = [];
    for (let i = 0; i < n; i++) {
      const c = this.drawCard();
      if (!c) break;
      this.hand.push(c);
      got.push(c);
    }
    return got;
  }

  say(t) { this.log.push(t); }

  attack(src, dst, amount) {
    const amt = Math.max(0, amount - src.hex);
    const absorbed = Math.min(dst.block, amt);
    dst.block -= absorbed;
    const through = amt - absorbed;
    dst.hp = Math.max(0, dst.hp - through);
    if (dst.thorns > 0 && through > 0) {
      src.hp = Math.max(0, src.hp - dst.thorns);
      this.say(`${src.name} takes ${dst.thorns} from Thorns.`);
    }
    return through;
  }

  /* Pure: what would this meld do? Never mutates. */
  preview(cards) {
    const v = classify(cards);
    if (!v.valid) return v.label;
    const n = cards.length, R = (k) => this.run.relicValue(k);
    switch (v.kind) {
      case Kind.PAIR:  return `BRACE  +${BRACE(n) + R("brace_bonus")} Block`;
      case Kind.RUN2:  return `PREP  draw ${TUNING.prepDraw + R("draw_bonus")}, +1 Focus`;
      case Kind.RUN: {
        const d = STRIKE(n) + R("strike_bonus");
        return `STRIKE  ${d} raw  (${Math.max(0, d - this.player.hex - this.enemy.block)} after Block ${this.enemy.block})`;
      }
      case Kind.SET:   return `RALLY  ${RALLY(n)} raw + ${2 + R("burn_bonus")} Burn`;
      case Kind.GRAND: return `GRAND MELD  ${TUNING.grand() + R("strike_bonus")} raw, 3 Hex, 8 Block`;
    }
    return v.label;
  }

  takeFromHand(indices) {
    const idx = indices.slice().sort((a, b) => b - a);
    const out = [];
    for (const i of idx) if (i >= 0 && i < this.hand.length) out.unshift(this.hand.splice(i, 1)[0]);
    return out;
  }

  playMeld(cards) {
    const v = classify(cards);
    if (!v.valid || this.over) return null;
    const n = cards.length, R = (k) => this.run.relicValue(k);
    const out = { action: v.action, kind: v.kind, damage: 0, block: 0, offensive: true, text: "" };

    switch (v.kind) {
      case Kind.PAIR: {
        const b = BRACE(n) + R("brace_bonus");
        this.player.block += b;
        Object.assign(out, { block: b, offensive: false, text: `BRACE — ${b} Block.` });
        break;
      }
      case Kind.RUN2: {
        const extra = TUNING.prepDraw + R("draw_bonus");
        this.drawToHand(extra);
        this.focus += 1;
        Object.assign(out, { offensive: false, text: `PREP — drew ${extra}, +1 Focus.` });
        break;
      }
      case Kind.RUN: {
        const d = STRIKE(n) + R("strike_bonus");
        out.damage = this.attack(this.player, this.enemy, d);
        out.text = `STRIKE — ${out.damage} damage.`;
        break;
      }
      case Kind.SET: {
        const burn = 2 + R("burn_bonus");
        out.damage = this.attack(this.player, this.enemy, RALLY(n));
        this.enemy.burn += burn;
        out.text = `RALLY — ${out.damage} damage, ${burn} Burn.`;
        break;
      }
      case Kind.GRAND: {
        out.damage = this.attack(this.player, this.enemy, TUNING.grand() + R("strike_bonus"));
        this.enemy.hex += 3;
        this.player.block += 8;
        out.block = 8;
        out.text = `GRAND MELD — ${out.damage} damage, 3 Hex, 8 Block.`;
        break;
      }
    }
    for (const c of cards) this.discard.push(c);
    this.focus -= 1;
    this.say(out.text);
    this.checkEnd();
    return out;
  }

  discardCard(i) {
    if (i < 0 || i >= this.hand.length || this.over) return null;
    const c = this.hand.splice(i, 1)[0];
    this.discard.push(c);
    return c;
  }

  cycle() {
    this.focus -= 1;
    this.drawToHand(1 + this.run.relicValue("draw_bonus"));
  }

  rollIntent() {
    const kinds = ["STRIKE", "BRACE", "RALLY"];
    if (this.turn % 3 === 0) kinds.push("HEX");
    const tier = ROSTER[this.enemy.id].tier || 1;
    const pick = kinds[Math.floor(this.rng() * kinds.length)];
    const amount = {
      STRIKE: Math.round((6 + tier * 3 + this.turn) * TUNING.enemyDmg),
      BRACE: 6 + tier * 2,
      RALLY: Math.round((4 + tier * 2) * TUNING.enemyDmg),
      HEX: 2,
    }[pick];
    this.intent = { kind: pick, amount };
  }

  intentText() {
    const { kind, amount } = this.intent;
    return {
      STRIKE: `INTENT: STRIKE for ${amount}`,
      BRACE: `INTENT: BRACE ${amount} Block`,
      RALLY: `INTENT: RALLY ${amount} + Burn`,
      HEX: `INTENT: HEX ${amount}`,
    }[kind];
  }

  endTurn() {
    if (this.over) return [];
    const ev = [];

    if (this.player.burn > 0) {
      this.player.hp = Math.max(0, this.player.hp - this.player.burn);
      ev.push({ t: "burn", who: "player", n: this.player.burn });
      this.player.burn = Math.max(0, this.player.burn - 1);
    }
    if (this.checkEnd()) return ev;

    const { kind, amount } = this.intent;
    if (kind === "STRIKE") {
      ev.push({ t: "hit", who: "player", n: this.attack(this.enemy, this.player, amount) });
    } else if (kind === "BRACE") {
      this.enemy.block += amount;
      ev.push({ t: "block", who: "enemy", n: amount });
    } else if (kind === "RALLY") {
      ev.push({ t: "hit", who: "player", n: this.attack(this.enemy, this.player, amount) });
      this.player.burn += 2;
      ev.push({ t: "burn_applied", who: "player", n: 2 });
    } else if (kind === "HEX") {
      this.player.hex += amount;
      ev.push({ t: "hex", who: "player", n: amount });
    }

    if (this.enemy.burn > 0) {
      this.enemy.hp = Math.max(0, this.enemy.hp - this.enemy.burn);
      ev.push({ t: "burn", who: "enemy", n: this.enemy.burn });
      this.enemy.burn = Math.max(0, this.enemy.burn - 1);
    }

    this.player.block = Math.floor(this.player.block * 0.5);
    this.enemy.block = Math.floor(this.enemy.block * 0.5);
    this.player.hex = Math.max(0, this.player.hex - 1);
    this.enemy.hex = Math.max(0, this.enemy.hex - 1);

    this.turn += 1;
    this.focus = this.maxFocus;
    this.drawToHand(Math.max(0, this.handSize() - this.hand.length));
    this.rollIntent();
    this.checkEnd();
    return ev;
  }

  checkEnd() {
    if (this.over) return true;
    if (!this.enemy.alive()) { this.over = true; this.victory = true; return true; }
    if (!this.player.alive()) { this.over = true; this.victory = false; return true; }
    return false;
  }
}

// ---------------------------------------------------------------- run state
class Run {
  constructor(meldling, bonusHp = 0) {
    this.meldling = meldling;
    this.maxHp = ROSTER[meldling].hp + bonusHp;
    this.hp = this.maxHp;
    this.relics = [];
    this.essence = 0;
    this.node = 0;
    this.lastResult = "";
  }
  relicValue(key) {
    return this.relics.reduce((t, r) => t + (r.key === key ? r.value : 0), 0);
  }
  hasRelic(id) { return this.relics.some((r) => r.id === id); }
  offerRelics(n = 3) {
    return shuffle(RELICS.filter((r) => !this.hasRelic(r.id)).slice()).slice(0, n);
  }
  heal(n) { this.hp = Math.min(this.maxHp, this.hp + n); }
}

const GAUNTLET = [
  { type: "battle", enemy: "deadwood" },
  { type: "cache" },
  { type: "battle", enemy: "shuffler" },
  { type: "rest" },
  { type: "elite", enemy: "jokester" },
  { type: "cache" },
  { type: "boss", enemy: "kingpin" },
];

if (typeof module !== "undefined") {
  module.exports = { TUNING, SUITS, SUIT_SYM, SUIT_NAMES, RANK_LABEL, Kind, ACTION_NAME,
    newDeck, shuffle, cardLabel, classify, canJoin, findMelds, ROSTER, RELICS,
    Combat, Combatant, Run, GAUNTLET };
}
