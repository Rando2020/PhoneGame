const R = require("./rules.js");
const { newDeck, shuffle, findMelds, classify, Kind } = R;

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------- 1. what's actually in a hand?
console.log("=== meld availability in a random hand (20000 deals) ===\n");
for (const size of [8, 10, 12]) {
  const rng = mulberry32(size * 1000 + 7);
  let pair = 0, run2 = 0, run3 = 0, set3 = 0, grand = 0, anyDmg = 0, nothing = 0;
  const N = 20000;
  for (let i = 0; i < N; i++) {
    const hand = shuffle(newDeck(), rng).slice(0, size);
    const ms = findMelds(hand).map((idx) => classify(idx.map((j) => hand[j])));
    const has = (k, len = 0) => ms.some((v) => v.kind === k);
    const runLen = Math.max(0, ...findMelds(hand)
      .filter((idx) => classify(idx.map((j) => hand[j])).kind === Kind.RUN)
      .map((idx) => idx.length));
    if (has(Kind.PAIR)) pair++;
    if (has(Kind.RUN2)) run2++;
    if (runLen >= 3) run3++;
    if (has(Kind.SET)) set3++;
    if (has(Kind.GRAND)) grand++;
    const dmg = runLen >= 3 || has(Kind.SET) || has(Kind.GRAND);
    if (dmg) anyDmg++;
    if (!ms.length) nothing++;
  }
  const p = (x) => (100 * x / N).toFixed(1).padStart(5) + "%";
  console.log(`  hand of ${String(size).padStart(2)}:  pair ${p(pair)}  2-run ${p(run2)}  ` +
    `3+run ${p(run3)}  3+set ${p(set3)}  grand ${p(grand)}  ` +
    `|  ANY DAMAGE ${p(anyDmg)}   dead hand ${p(nothing)}`);
}

// ---------------------------------------------------------------- 2. tuning variants
const TUNINGS = {
  current: { hand: 8, focus: 2, strike: (n) => 5 * n + 3 * (n - 3), rally: (n) => 4 * n,
    brace: (n) => 6 + n, prepDraw: 2, enemyHp: 1.0, enemyDmg: 1.0, run2Damage: 0 },

  // more cards seen => runs actually appear
  biggerHand: { hand: 12, focus: 2, strike: (n) => 5 * n + 3 * (n - 3), rally: (n) => 4 * n,
    brace: (n) => 6 + n, prepDraw: 2, enemyHp: 1.0, enemyDmg: 1.0, run2Damage: 0 },

  // sets are common, so let them carry more of the damage load
  setsMatter: { hand: 12, focus: 2, strike: (n) => 5 * n + 3 * (n - 3), rally: (n) => 6 * n,
    brace: (n) => 6 + n, prepDraw: 2, enemyHp: 1.0, enemyDmg: 1.0, run2Damage: 0 },

  // + softer enemy ramp
  tuned: { hand: 12, focus: 2, strike: (n) => 5 * n + 4 * (n - 3), rally: (n) => 6 * n,
    brace: (n) => 8 + n * 2, prepDraw: 3, enemyHp: 0.85, enemyDmg: 0.7, run2Damage: 0 },

  // reward for holding: a 2-run stored as PREP boosts your next STRIKE
  patienceRewarded: { hand: 12, focus: 2, strike: (n) => 5 * n + 4 * (n - 3), rally: (n) => 6 * n,
    brace: (n) => 8 + n * 2, prepDraw: 3, enemyHp: 0.85, enemyDmg: 0.7, run2Damage: 0, prepBoost: 8 },
};

class Sim {
  constructor(T, enemyId, rng) {
    this.T = T; this.rng = rng;
    const e = R.ROSTER[enemyId];
    this.tier = e.tier || 1;
    this.ehp = Math.round(e.hp * T.enemyHp);
    this.emax = this.ehp;
    this.php = 60; this.pmax = 60;
    this.pblock = 0; this.eblock = 0;
    this.pburn = 0; this.eburn = 0; this.phex = 0;
    this.deck = shuffle(newDeck(), rng); this.disc = [];
    this.hand = []; this.turn = 1; this.prep = 0;
    for (let i = 0; i < T.hand; i++) this.hand.push(this.draw());
  }
  draw() {
    if (!this.deck.length) { this.deck = shuffle(this.disc.slice(), this.rng); this.disc = []; }
    return this.deck.pop();
  }
  hit(amt, toEnemy) {
    amt = Math.max(0, amt - (toEnemy ? this.phex : 0));
    if (toEnemy) { const a = Math.min(this.eblock, amt); this.eblock -= a; this.ehp -= amt - a; }
    else { const a = Math.min(this.pblock, amt); this.pblock -= a; this.php -= amt - a; }
  }
  play(idx, kind, n) {
    const T = this.T;
    const cards = idx.slice().sort((a, b) => b - a).map((i) => this.hand.splice(i, 1)[0]);
    this.disc.push(...cards);
    if (kind === Kind.PAIR) this.pblock += T.brace(n);
    else if (kind === Kind.RUN2) {
      for (let i = 0; i < T.prepDraw; i++) this.hand.push(this.draw());
      this.prep = T.prepBoost || 0;
    }
    else if (kind === Kind.RUN) { this.hit(T.strike(n) + this.prep, true); this.prep = 0; }
    else if (kind === Kind.SET) { this.hit(T.rally(n), true); this.eburn += 2; }
    else if (kind === Kind.GRAND) { this.hit(26, true); this.pblock += 8; }
  }
  endTurn() {
    const T = this.T;
    if (this.pburn > 0) { this.php -= this.pburn; this.pburn--; }
    if (this.php <= 0) return;
    const kinds = ["STRIKE", "BRACE", "RALLY"];
    const k = kinds[Math.floor(this.rng() * kinds.length)];
    const scale = T.enemyDmg;
    if (k === "STRIKE") this.hit(Math.round((6 + this.tier * 3 + this.turn) * scale), false);
    else if (k === "BRACE") this.eblock += 6 + this.tier * 2;
    else { this.hit(Math.round((4 + this.tier * 2) * scale), false); this.pburn += 2; }
    if (this.eburn > 0) { this.ehp -= this.eburn; this.eburn--; }
    this.pblock = Math.floor(this.pblock / 2); this.eblock = Math.floor(this.eblock / 2);
    this.phex = Math.max(0, this.phex - 1);
    this.turn++;
    while (this.hand.length < T.hand) this.hand.push(this.draw());
  }
  over() { return this.ehp <= 0 || this.php <= 0; }
}

function options(s) {
  return findMelds(s.hand).map((idx) => ({ idx, v: classify(idx.map((i) => s.hand[i])) }))
    .filter((m) => m.v.valid);
}

function runPolicy(s, mode) {
  let focus = s.T.focus;
  while (focus > 0 && !s.over()) {
    const ms = options(s);
    if (!ms.length) break;
    const score = (m) => {
      const n = m.idx.length;
      if (m.v.kind === Kind.GRAND) return 1000;
      if (m.v.kind === Kind.RUN) return 500 + n * 10;
      if (m.v.kind === Kind.SET) return 400 + n * 10;
      if (m.v.kind === Kind.PAIR) return mode === "patient" ? 300 : 100;
      return mode === "patient" ? 350 : 50;   // patient values PREP
    };
    ms.sort((a, b) => score(b) - score(a));
    const best = ms[0];
    s.play(best.idx, best.v.kind, best.idx.length);
    focus--;
  }
  s.endTurn();
}

console.log("\n=== win rate by tuning (1500 battles each) ===\n");
const rows = [];
for (const [name, T] of Object.entries(TUNINGS)) {
  const row = { tuning: name };
  for (const e of ["deadwood", "jokester", "kingpin"]) {
    for (const mode of ["greedy", "patient"]) {
      let w = 0; const N = 1500;
      for (let i = 0; i < N; i++) {
        const s = new Sim(T, e, mulberry32(i * 104729 + 11));
        let g = 0;
        while (!s.over() && g++ < 120) runPolicy(s, mode);
        if (s.ehp <= 0 && s.php > 0) w++;
      }
      row[`${e.slice(0, 4)}/${mode.slice(0, 3)}`] = (100 * w / N).toFixed(0) + "%";
    }
  }
  rows.push(row);
}
console.table(rows);
