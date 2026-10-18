/* Meldlings — the meta layer.
   Achievements are the reason to keep playing after you can clear Street I;
   Streets are the reason to keep playing after you can clear everything. */

const ACHIEVEMENTS = [
  // --- early, teach the systems
  { id: "first_road",  name: "First Road",     text: "Clear an Act.",                    hint: "Reach Act 2." },
  { id: "counted",     name: "Counted",        text: "Score a hand worth 40 or more.",   hint: "One big count." },
  { id: "spoiled",     name: "Spoiled",        text: "Beat a Spoiler.",                  hint: "Survive a boss round." },
  // --- cribbage lore
  { id: "twentynine",  name: "Twenty-Nine",    text: "Count the perfect hand.",          hint: "5-5-5-J with the matching 5 cut.", secret: true },
  { id: "nineteen",    name: "Nineteen",       text: "Count a hand worth nothing.",      hint: "The score cribbage cannot make." },
  { id: "his_heels",   name: "His Heels",      text: "Cut a Jack.",                      hint: "The starter comes up a knave." },
  // --- mastery
  { id: "clutch",      name: "Down to the Cut", text: "Win a round on the cut alone.",   hint: "Your four cards weren't enough." },
  { id: "optimal5",    name: "Sharp Eye",      text: "Make the best possible keep 5 times in one run." },
  { id: "skunk",       name: "Skunked",        text: "Clear a round at triple the target." },
  { id: "shatter",     name: "Brittle Heart",  text: "Break three marked cards in one run." },
  { id: "whittled",    name: "Whittled Down",  text: "Finish a round with fewer than 30 cards." },
  { id: "deep_count",  name: "Deep Count",     text: "Take a Reckoning to level 8." },
  { id: "hallowed",    name: "Hallowed Hand",  text: "Hold two Hallowed charms at once." },
  { id: "crib_king",   name: "Crib King",      text: "Score 60 or more from a single Crib." },
  // --- the long game
  { id: "long_road",   name: "The Long Road",  text: "Clear a full run.",                hint: "All five Acts." },
  { id: "street_ii",   name: "Second Street",  text: "Clear a run on Street II." },
  { id: "street_iii",  name: "Third Street",   text: "Clear a run on Street III." },
];

/* Difficulty tiers, named for the rows of a cribbage board. Each unlocks by
   clearing the one before it. */
const STREETS = [
  { id: 1, name: "First Street",   text: "The road as it comes.", mods: {} },
  { id: 2, name: "Second Street",  text: "Targets +25%. The Crib scores at half.",
    mods: { targetMul: 1.25, cribHalf: true } },
  { id: 3, name: "Third Street",   text: "Spoilers hold rounds 3 and 5.",
    mods: { targetMul: 1.25, extraSpoiler: true } },
  { id: 4, name: "Fourth Street",  text: "One fewer charm slot. Marks cost double.",
    mods: { targetMul: 1.3, slots: -1, extraSpoiler: true, markCostMul: 2 } },
  { id: 5, name: "Fifth Street",   text: "Your deck no longer recycles. Run it dry and the round ends.",
    mods: { targetMul: 1.35, slots: -1, extraSpoiler: true, noRecycle: true } },
  { id: 6, name: "The Turn",       text: "Charms score at half against Spoilers.",
    mods: { targetMul: 1.3, slots: -1, extraSpoiler: true, noRecycle: true, halfCharmBoss: true } },
  { id: 7, name: "The Stink Hole", text: "Clearing early pays nothing extra.",
    mods: { targetMul: 1.32, slots: -1, extraSpoiler: true, noRecycle: true,
            halfCharmBoss: true, noCashOut: true } },
  { id: 8, name: "Skunk Line",     text: "Every Spoiler is Ruinous.",
    mods: { targetMul: 1.34, slots: -1, extraSpoiler: true, noRecycle: true,
            halfCharmBoss: true, noCashOut: true, allRuinous: true } },
];

/* TRIALS — preset runs built around one brutal constraint. Cheap to author,
   and each one teaches a different corner of the system. */
const TRIALS = [
  { id: "pauper",   name: "The Pauper",   deck: "pip",
    text: "No shop, ever. Only what the deck gives you.", mods: { noShop: true } },
  { id: "onesuit",  name: "One Suit",     deck: "clover",
    text: "Your deck is fifty-two hearts.", mods: { oneSuit: "H", targetMul: 1.35 } },
  { id: "ascetic",  name: "The Ascetic",  deck: "muggins",
    text: "Your hand scores at a quarter. The Crib pays four times over.",
    mods: { handQuarter: true, cribQuad: true, targetMul: 0.4 } },
  { id: "thirteen", name: "Thirteen",     deck: "facet",
    text: "Your deck is thirteen cards, recycling constantly.", mods: { deckCap: 13 } },
  { id: "court",    name: "The Assessor's Court", deck: "nib",
    text: "Clear every target, but never score more than double it.",
    mods: { allExact: true, overBand: 2.0, targetMul: 0.8 } },
  { id: "famine",   name: "Long Famine",  deck: "thump",
    text: "Three deals a round, and one mulligan only.",
    mods: { dealBonus: -1, mulliganBonus: -1, targetMul: 0.75 } },
  { id: "blind",    name: "Blind Man's Count", deck: "pip",
    text: "You never see the deck tracker, and the cut is never previewed.",
    mods: { hideTracker: true } },
  { id: "glass",    name: "Glass Road",   deck: "clover",
    text: "Every card you buy is Brittle.", mods: { allBrittle: true } },
];

/* THE DAILY. One seed per calendar day, identical for everyone, one attempt.
   This is the Wordle hook: a reason to come back tomorrow that costs nothing to
   build because the run generator is already deterministic given a seed. */
function dailyKey(d) {
  const t = d || new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, "0")}-${String(t.getDate()).padStart(2, "0")}`;
}
function dailySeed(key) {
  let h = 2166136261;
  for (let i = 0; i < key.length; i++) { h ^= key.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
/* A seeded generator, so the same day deals the same cards for everybody. */
function makeRng(seed) {
  let s = seed >>> 0;
  const rand = function () {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
  // the state, so a saved run resumes the same stream (makeRng(state) continues it)
  rand.state = () => s;
  return rand;
}

/* THE LONG COUNT — past Act 5, the ladder just keeps going. */
const ENDLESS_FROM = 26;

/* Meldlings you start with, and the ones you earn. */
const MELDLING_UNLOCKS = {
  pip: null, thump: null, clover: null, facet: null,
  nib: "twentynine",     // earned by counting the perfect hand
  muggins: "long_road",  // earned by clearing a full run
};

/* ASCENDED forms: the same identity pushed until it breaks. Unlocked by clearing
   a run with the base Meldling. */
const ASCENDED = {
  pip:     { of: "pip",     name: "Pip Ascended" },
  thump:   { of: "thump",   name: "Thump Ascended" },
  clover:  { of: "clover",  name: "Clover Ascended" },
  facet:   { of: "facet",   name: "Facet Ascended" },
};

/* SYSTEM UNLOCKS — not cosmetics. These change how the game is played, and they
   are won from Wagers, never bought. Each one makes a later run look less like
   the one you started with. */
const SYSTEMS = [
  { id: "crib_cut",   name: "The Crib's Own Cut",
    text: "Your Crib gets its own cut card at round end, with its own reveal." },
  { id: "crib_mult",  name: "The Gathering",
    text: "The Crib builds a multiplier as you feed it. Matching suits and courts raise it." },
  { id: "split_cards",name: "Split Cards",
    text: "The Stall begins selling cards that are two ranks at once." },
  { id: "sixth_slot", name: "The Sixth Slot",
    text: "One more charm slot, for the rest of time." },
  { id: "the_play",   name: "The Play",
    text: "After each count, you and the Spoiler peg your cards toward 31 for bonus points." },
  { id: "deep_stall", name: "The Deep Stall",
    text: "The Stall offers four cards instead of three, and Marks appear more often." },
];

/* Cosmetics, bought with Pegs — the currency that stays with your profile.
   Glim is spent inside a run; Pegs outlive it. */
const CARD_BACKS = [
  { id: "indigo",  name: "Indigo",   cost: 0,  text: "The house back." },
  { id: "crimson", name: "Crimson",  cost: 25, text: "Woven red." },
  { id: "moss",    name: "Mosswork", cost: 25, text: "Rays through green." },
  { id: "bone",    name: "Bone",     cost: 40, text: "Pale and plain." },
  { id: "void",    name: "The Void", cost: 60, text: "Chevrons in the dark." },
  { id: "brass",   name: "Brass",    cost: 80, text: "Rings of old metal." },
];

/* LENSES — UI panels you can pin open permanently, bought with Pegs.
   Everything is reachable from the Table drawer for free; a Lens just keeps it
   on screen so you never have to open it. */
const LENSES = [
  { id: "counter", name: "Counter's Lens", cost: 30,
    text: "Pins the deck tracker open: every rank still live, at a glance." },
  { id: "crib",    name: "Crib Glass",     cost: 30,
    text: "Pins your Crib open, so you always see what you've fed it." },
  { id: "ledger",  name: "The Ledger",     cost: 35,
    text: "Pins your charms on the table during play." },
  { id: "odds",    name: "Odds Glass",     cost: 45,
    text: "Shows how many live cards would improve each keep." },
];

/* Pegs are paid for milestones, not for grinding. */
function pegsForRun(reached, cleared, street, deeds) {
  let p = Math.floor(reached / 2);
  if (cleared) p += 20 + street * 10;
  p += deeds * 5;
  return p;
}

/* ---------------------------------------------------------------- the save
   One store, one key, one in-memory copy. Achv and Meta previously each did
   their own read-modify-write against the SAME key, so whichever wrote last
   could clobber the other's changes. And there was no version field, despite
   the format changing twice (lenses -> pins, surplus -> skipProgress).
   ---------------------------------------------------------------------- */
const SAVE_KEY = "meldlings.save";
const SAVE_VERSION = 3;

const MIGRATIONS = {
  /* v1: the original split store, keyed "meldlings.meta.v1" */
  1: (m) => {
    // Lenses became free pins; carry ownership across as pinned panels
    if (m.lenses) {
      m.pins = m.pins || {};
      const map = { counter: "counter", crib: "crib", ledger: "ledger" };
      for (const k in m.lenses) if (map[k] && !(m.lensOff || {})[k]) m.pins[map[k]] = true;
    }
    delete m.lenses; delete m.lensOff;
    return m;
  },
  /* v2: surplus folded into skip progress (run-scoped, nothing to carry) */
  2: (m) => { delete m.surplus; return m; },
};

const Store = {
  _cache: null,
  read() {
    if (this._cache) return this._cache;
    let m = {};
    try {
      m = JSON.parse(localStorage.getItem(SAVE_KEY) || "null")
        || JSON.parse(localStorage.getItem("meldlings.meta.v1") || "{}");
    } catch (e) { m = {}; }
    let v = m.__v || 1;
    while (v < SAVE_VERSION) {
      if (MIGRATIONS[v]) { try { m = MIGRATIONS[v](m); } catch (e) {} }
      v++;
    }
    m.__v = SAVE_VERSION;
    this._cache = m;
    return m;
  },
  write(m) {
    this._cache = m;
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(m)); } catch (e) {}
  },
  wipe() {
    this._cache = null;
    try { localStorage.removeItem(SAVE_KEY); localStorage.removeItem("meldlings.meta.v1"); } catch (e) {}
  },
};

const Achv = {
  KEY: SAVE_KEY,
  load() { return Store.read(); },
  save(m) { Store.write(m); },

  has(id) { return !!(this.load().got || {})[id]; },
  count() { return Object.keys(this.load().got || {}).length; },

  grant(id) {
    const m = this.load();
    m.got = m.got || {};
    if (m.got[id]) return false;
    m.got[id] = Date.now();
    this.save(m);
    return true;
  },

  streetUnlocked() {
    const m = this.load();
    return Math.max(1, Math.min(STREETS.length, m.street || 1));
  },
  unlockStreet(n) {
    const m = this.load();
    m.street = Math.max(m.street || 1, Math.min(STREETS.length, n));
    this.save(m);
  },

  pegs() { return this.load().pegs || 0; },
  addPegs(n) { const m = this.load(); m.pegs = (m.pegs || 0) + n; this.save(m); return m.pegs; },
  spendPegs(n) {
    const m = this.load();
    if ((m.pegs || 0) < n) return false;
    m.pegs -= n; this.save(m); return true;
  },
  clearedWith(deck) { return !!(this.load().cleared || {})[deck]; },
  markCleared(deck) {
    const m = this.load(); m.cleared = m.cleared || {}; m.cleared[deck] = 1; this.save(m);
  },
  trialDone(id) { return !!(this.load().trials || {})[id]; },
  markTrial(id) {
    const m = this.load(); m.trials = m.trials || {}; m.trials[id] = 1; this.save(m);
  },
  bestEndless() { return this.load().endless || 0; },
  setEndless(n) {
    const m = this.load();
    if (n > (m.endless || 0)) { m.endless = n; this.save(m); }
  },

  /* Panels pin for free — this used to be a purchase, which made a settings
     toggle wear a price tag. */
  pinned(id) { return !!(this.load().pins || {})[id]; },
  togglePin(id) {
    const m = this.load();
    m.pins = m.pins || {};
    m.pins[id] = !m.pins[id];
    this.save(m);
  },

  dailyDone(key) { return (this.load().daily || {})[key || dailyKey()] || null; },
  recordDaily(key, result) {
    const m = this.load();
    m.daily = m.daily || {};
    m.daily[key] = result;
    // keep a fortnight, not a lifetime
    const keys = Object.keys(m.daily).sort().slice(-14);
    const trimmed = {};
    for (const k of keys) trimmed[k] = m.daily[k];
    m.daily = trimmed;
    m.dailyStreak = this.streakFrom(trimmed);
    this.save(m);
  },
  streakFrom(daily) {
    let n = 0;
    const d = new Date();
    for (;;) {
      if (!daily[dailyKey(d)]) break;
      n++;
      d.setDate(d.getDate() - 1);
    }
    return n;
  },
  dailyStreak() { return this.streakFrom(this.load().daily || {}); },

  hasSystem(id) { return !!(this.load().systems || {})[id]; },
  grantSystem(id) {
    const m = this.load();
    m.systems = m.systems || {};
    if (m.systems[id]) return false;
    m.systems[id] = Date.now();
    this.save(m);
    return true;
  },
  lockedSystems() { return SYSTEMS.filter((s) => !this.hasSystem(s.id)); },

  ownsLens(id) { return !!(this.load().lenses || {})[id]; },
  buyLens(id) {
    const l = LENSES.find((x) => x.id === id);
    if (!l || this.ownsLens(id) || !this.spendPegs(l.cost)) return false;
    const m = this.load(); m.lenses = m.lenses || {}; m.lenses[id] = 1; this.save(m);
    return true;
  },
  lensOn(id) {
    const m = this.load();
    if (!this.ownsLens(id)) return false;
    return (m.lensOff || {})[id] ? false : true;
  },
  toggleLens(id) {
    const m = this.load();
    m.lensOff = m.lensOff || {};
    m.lensOff[id] = !m.lensOff[id];
    this.save(m);
  },

  ownsBack(id) { const m = this.load(); return id === "indigo" || !!(m.backs || {})[id]; },
  buyBack(id) {
    const b = CARD_BACKS.find((x) => x.id === id);
    if (!b || this.ownsBack(id) || !this.spendPegs(b.cost)) return false;
    const m = this.load(); m.backs = m.backs || {}; m.backs[id] = 1; this.save(m);
    return true;
  },
  activeBack() { const m = this.load(); return m.back || "indigo"; },
  setBack(id) { if (!this.ownsBack(id)) return false; const m = this.load(); m.back = id; this.save(m); return true; },

  /* Last ten runs, so you can see which Meldling actually suits you. */
  logRun(entry) {
    const m = this.load();
    m.history = [entry].concat(m.history || []).slice(0, 10);
    this.save(m);
  },
  history() { return this.load().history || []; },
  deckStats() {
    const h = this.history();
    const by = {};
    for (const r of h) {
      const d = (by[r.deck] = by[r.deck] || { runs: 0, best: 0, total: 0 });
      d.runs++; d.total += r.reached; d.best = Math.max(d.best, r.reached);
    }
    for (const k in by) by[k].avg = (by[k].total / by[k].runs).toFixed(1);
    return by;
  },

  meldlingUnlocked(id) {
    if (ASCENDED[id.replace("_asc", "")] && id.endsWith("_asc"))
      return this.clearedWith(id.replace("_asc", ""));
    const req = MELDLING_UNLOCKS[id];
    return !req || this.has(req);
  },

  /* Fired from gameplay; returns the list of newly earned achievements. */
  check(evt, d = {}) {
    const got = [];
    const g = (id) => { if (this.grant(id)) got.push(id); };

    if (evt === "count") {
      if (d.total >= 40) g("counted");
      if (d.base >= 29 && d.perfect) g("twentynine");
      if (d.base === 0) g("nineteen");
      if (d.cutJack) g("his_heels");
      if (d.cutSaved) g("clutch");
      if (d.optimalStreak >= 5) g("optimal5");
    }
    if (evt === "round") {
      if (d.won && d.act >= 1 && d.round >= 5) g("spoiled");
      if (d.won && d.score >= d.target * 3) g("skunk");
      if (d.won && d.deckSize < 30) g("whittled");
      if (d.cribTotal >= 60) g("crib_king");
      if (d.maxReckoning >= 8) g("deep_count");
      if (d.hallowed >= 2) g("hallowed");
      if (d.shattered >= 3) g("shatter");
      if (d.won && d.actCleared) g("first_road");
    }
    if (evt === "run") {
      if (d.cleared) {
        g("long_road");
        if (d.street >= 2) g("street_ii");
        if (d.street >= 3) g("street_iii");
        this.unlockStreet(d.street + 1);
      }
    }
    return got;
  },
};

if (typeof module !== "undefined")
  module.exports = { ACHIEVEMENTS, STREETS, TRIALS, ASCENDED, ENDLESS_FROM,
    dailyKey, dailySeed, makeRng,
    MELDLING_UNLOCKS, CARD_BACKS, LENSES, SYSTEMS, pegsForRun, Achv };
