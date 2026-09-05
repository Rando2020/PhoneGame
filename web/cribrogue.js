/* Meldlings — cribbage roguelite layer.
   round = reach TARGET within N deals
   deal  = draw 6 -> keep 4 -> cut starter -> COUNT (cascade x mult)
   round end = the Crib pays out as a banked bonus */

const CRIB_ACTS = 5, CRIB_ROUNDS = 5;
const CRIB_LADDER = { baseTarget: 36, growth: 1.19 };
const CRIB_DEALS = 4, CRIB_DEALT = 6, CRIB_KEEP = 4;
/* The single most important balance constraint: a hard cap on charms.
   Without it the AI hoarded 18 charms and cleared 90% of runs. With 5 slots you
   must choose a build and sell into it -- which is where meta skill lives. */
const CHARM_SLOTS = 5;
/* Second scaling axis. Charms are capped at 5 slots, so uncapped growth has to
   come from somewhere else -- exactly why Balatro pairs 5 joker slots with
   unlimited hand-level upgrades. Levels add flat base per scoring event. */
const BASE_MULLIGANS = 2;
const CRIB_SIZE = 4;
const SURPLUS_PER_SKIP = 100;   // 100 surplus = one skip = beating a target by 2x

/* ---- per-card enhancements. Cards themselves become the build. ---- */
/* MARKS — a card bears a mark. Named from craft and old counting language
   rather than borrowed material names. */
const ENHANCEMENTS = {
  gilded:    { name: "Sunlit",   tint: "#e8b64c", tag: "☀", cost: 5,
               text: "+6 base whenever this card is counted." },
  glass:     { name: "Brittle",  tint: "#74e0d0", tag: "✧", cost: 7,
               text: "x1.4 mult when counted. 1 in 4 chance it breaks for good." },
  chameleon: { name: "Mimic",    tint: "#c96fd6", tag: "≈", cost: 8,
               text: "Wears any suit it likes, for flushes." },
  steel:     { name: "Offering", tint: "#9aa6bf", tag: "†", cost: 6,
               text: "+0.6 mult, but only if you give it to the Crib." },
  coin:      { name: "Minted",   tint: "#6fc98a", tag: "◈", cost: 5,
               text: "+3 Glim each time it is counted." },
  lucky:     { name: "Fickle",   tint: "#e8804c", tag: "?", cost: 6,
               text: "1 in 4 chance of +25 base. Otherwise nothing." },
};

/* Cribbage weights fives absurdly — they make fifteen with every ten-card — so
   the market must make them rare and expensive, or the game solves itself. */
const CARD_WEIGHT = { 1: 6, 2: 6, 3: 6, 4: 6, 5: 1, 6: 5, 7: 5, 8: 5, 9: 5,
                      10: 3, 11: 3, 12: 3, 13: 3 };
const RANK_PREMIUM = { 5: 9, 10: 3, 11: 3, 12: 3, 13: 3 };

function rollCardRank() {
  const total = Object.values(CARD_WEIGHT).reduce((a, b) => a + b, 0);
  let r = Math.random() * total;
  for (const k in CARD_WEIGHT) { r -= CARD_WEIGHT[k]; if (r <= 0) return +k; }
  return 7;
}

function rollCardOffer() {
  const rank = rollCardRank();
  const suit = ["S", "H", "C", "D"][Math.floor(Math.random() * 4)];
  const card = { rank, suit };
  let cost = 4 + (RANK_PREMIUM[rank] || 0);

  /* Split cards: two ranks on one card, unlocked from a Wager. Adjacent ranks
     make runs; distant ones make fifteens. Both are worth paying for. */
  if (typeof Achv !== "undefined" && Achv.hasSystem("split_cards") && Math.random() < 0.22) {
    let r2 = rollCardRank();
    if (r2 === rank) r2 = (rank % 13) + 1;
    card.rank2 = r2;
    card.suit2 = ["S", "H", "C", "D"][Math.floor(Math.random() * 4)];
    cost += 7 + Math.round((RANK_PREMIUM[r2] || 0) * 0.5);
  }
  if (Math.random() < 0.55) {
    const keys = Object.keys(ENHANCEMENTS);
    const enh = keys[Math.floor(Math.random() * keys.length)];
    card.enh = enh;
    cost += ENHANCEMENTS[enh].cost;
  }
  return { card, cost };
}

/* Rarity drives shop odds, price and presentation. */
/* Charm quality, ascending. Reads as craftsmanship rather than loot tiers. */
const RARITY = {
  common:    { name: "Worn",     weight: 50, tint: "#8fa3c8" },
  uncommon:  { name: "Keen",     weight: 30, tint: "#6fc98a" },
  rare:      { name: "Gleaming", weight: 15, tint: "#e8b64c" },
  legendary: { name: "Hallowed", weight: 5,  tint: "#d06fd6" },
};
const RARITY_ORDER = ["common", "uncommon", "rare", "legendary"];

function rollRarity(rng = Math.random) {
  const total = RARITY_ORDER.reduce((t, k) => t + RARITY[k].weight, 0);
  let r = rng() * total;
  for (const k of RARITY_ORDER) { r -= RARITY[k].weight; if (r <= 0) return k; }
  return "common";
}
/* nobs dropped: it needs a jack matching the cut suit, so a Reckoning in it
   almost never pays. Same reason the Knave charm was cut. */
const LEVEL_CATS = ["fifteen", "pair", "run", "flush"];
const LEVEL_GAIN = 3;
const levelCost = (lv) => 4 + Math.round(lv * 2.2);

/* ---------------------------------------------------------------- charms */
const CCHARMS = [
  // ---- tier 1: flat, keyed to a scoring category
  { id: "fifteener", name: "Fifteener", tier: 1, cost: 5, rarity: "common", cat: "fifteen", text: "+3 per fifteen.",
    onEvent: (e, ctx) => { if (e.kind === "fifteen") { ctx.base += 3; return true; } } },
  { id: "twinner",   name: "Twinner",   tier: 1, cost: 5, rarity: "common", cat: "pair", text: "+4 per pair scored.",
    onEvent: (e, ctx) => { if (e.kind === "pair") { ctx.base += 4; return true; } } },
  { id: "rambler",   name: "Rambler",   tier: 1, cost: 5, rarity: "common", cat: "run", text: "+5 per run.",
    onEvent: (e, ctx) => { if (e.kind === "run") { ctx.base += 5; return true; } } },
  { id: "peacock",   name: "Peacock",   tier: 1, cost: 6, rarity: "common", cat: "flush", text: "+8 for a flush.",
    onEvent: (e, ctx) => { if (e.kind === "flush") { ctx.base += 8; return true; } } },
  { id: "facecard",  name: "Face Value", tier: 1, cost: 6, rarity: "common", cat: "fifteen", text: "+2 per J/Q/K in hand.",
    onCount: (ctx) => { const n = ctx.all.filter(c => c.rank >= 11).length;
      if (n) { ctx.base += 2 * n; return true; } } },

  // ---- tier 2: multipliers
  { id: "counting",  name: "The Counting House", tier: 2, cost: 9, rarity: "rare", cat: "mult", text: "x1.25 per distinct category scored.",
    onCount: (ctx) => { const k = new Set(ctx.events.map(e => e.kind)).size;
      if (k) { ctx.mult *= Math.pow(1.25, k); return true; } } },
  { id: "fever",     name: "Fifteen Fever", tier: 2, cost: 9, rarity: "uncommon", cat: "mult", text: "x1.8 if 3 or more fifteens.",
    onCount: (ctx) => { if (ctx.events.filter(e => e.kind === "fifteen").length >= 3) { ctx.mult *= 1.8; return true; } } },
  { id: "suited",    name: "Suited",     tier: 2, cost: 8, rarity: "uncommon", cat: "mult", text: "x1.7 if the hand has a flush.",
    onCount: (ctx) => { if (ctx.events.some(e => e.kind === "flush")) { ctx.mult *= 1.7; return true; } } },
  { id: "streak",    name: "Streak",     tier: 2, cost: 11, rarity: "rare", cat: "mult", text: "x1.3 compounding each deal this round.",
    onCount: (ctx) => { ctx.mult *= Math.pow(1.3, ctx.round.dealIndex); return true; } },
  { id: "keystone2", name: "Keystone",   tier: 2, cost: 10, rarity: "uncommon", cat: "mult", text: "x1.6 mult, always.",
    onCount: (ctx) => { ctx.mult *= 1.6; return true; } },
  { id: "thirdtime", name: "Third Time Lucky", tier: 2, cost: 10, rarity: "rare", cat: "mult", text: "x2.5 on every third deal.",
    onCount: (ctx) => { if ((ctx.round.dealIndex + 1) % 3 === 0) { ctx.mult *= 2.5; return true; } } },
  { id: "purse",     name: "Deep Pockets", tier: 2, cost: 12, rarity: "rare", cat: "mult", text: "x1.15 per charm you own.",
    onCount: (ctx) => { ctx.mult *= Math.pow(1.15, ctx.run.charms.length); return true; } },

  // ---- tier 3: rule-breakers
  { id: "aceeleven", name: "Aces High", tier: 3, cost: 8, rarity: "uncommon", cat: "rule", text: "Aces count 11 toward fifteens.",
    rule: { aceEleven: true } },
  { id: "wrap",      name: "Round the Bend", tier: 3, cost: 10, rarity: "rare", cat: "rule", text: "Runs may wrap K-A-2.",
    rule: { wrapRuns: true } },
  { id: "shortflush", name: "Half a Flush", tier: 3, cost: 9, rarity: "uncommon", cat: "flush", text: "Three-card flushes count.",
    rule: { flushNeed: 3 } },
  { id: "recut",     name: "Recut",      tier: 3, cost: 9, rarity: "uncommon", cat: "rule", text: "Re-cut the starter once per deal.",
    rule: { recuts: 1 } },
  { id: "cribmaster", name: "Crib Master", tier: 3, cost: 10, rarity: "rare", cat: "rule", text: "The Crib scores at full mult.",
    rule: { cribFull: true } },
  { id: "fifthdeal", name: "One More Deal", tier: 3, cost: 12, rarity: "rare", cat: "rule", text: "+1 deal each round.",
    rule: { dealBonus: 1 } },
  { id: "widedeal",  name: "Generous Deal",  tier: 3, cost: 13, rarity: "rare", cat: "rule", text: "You are dealt 7 cards, not 6.",
    rule: { dealtBonus: 1 } },

  // ---- passives that change HOW you play, not just the numbers
  { id: "foresight", name: "Foresight", tier: 3, cost: 11, rarity: "legendary", cat: "rule",
    text: "The starter is cut BEFORE you keep. You always know the answer.",
    rule: { foresight: true } },
  { id: "doublecut", name: "Double Cut", tier: 3, cost: 12, rarity: "rare", cat: "rule",
    text: "Two starters are cut; your hand counts against the better one.",
    rule: { doubleCut: true } },
  { id: "royalblood", name: "Royal Blood", tier: 3, cost: 10, rarity: "legendary", cat: "deck",
    text: "Remove every 2-6 from your deck. J/Q/K score +7 each.",
    onAcquire: (run) => run.removeWhere((c) => c.rank >= 2 && c.rank <= 6),
    onCount: (ctx) => { const n = ctx.all.filter((c) => c.rank >= 11).length;
      if (n) { ctx.base += 7 * n; return true; } } },
  { id: "peasant",   name: "Peasant Stock", tier: 3, cost: 9, rarity: "rare", cat: "deck",
    text: "Remove every J/Q/K from your deck. x1.6 mult.",
    onAcquire: (run) => run.removeWhere((c) => c.rank >= 11),
    onCount: (ctx) => { ctx.mult *= 1.6; return true; } },
  { id: "loaded",    name: "Cooked Deck", tier: 3, cost: 10, rarity: "rare", cat: "deck",
    text: "Add four extra 5s to your deck.",
    onAcquire: (run) => run.addCards([{rank:5,suit:"S"},{rank:5,suit:"H"},{rank:5,suit:"C"},{rank:5,suit:"D"}]) },
  { id: "thindeck",  name: "Whittled",  tier: 3, cost: 9, rarity: "rare", cat: "deck",
    text: "Remove 8 random cards. +1 deal each round.",
    onAcquire: (run) => run.removeRandom(8),
    rule: { dealBonus: 1 } },
  { id: "secondchance", name: "Change of Heart", tier: 3, cost: 7, rarity: "uncommon", cat: "rule",
    text: "+2 mulligans each round.", rule: { mulliganBonus: 2 } },
  { id: "greedycrib", name: "Greedy Crib", tier: 3, cost: 11, rarity: "rare", cat: "rule",
    text: "The Crib keeps its best 5 cards instead of 4.", rule: { cribKeep: 5 } },
  { id: "miser",     name: "Miser",      tier: 3, cost: 10, rarity: "legendary", cat: "rule",
    text: "Hands score x0.5. The Crib scores x3.",
    rule: { miser: true } },

  // ---- legendaries
  { id: "sovereign", name: "Sovereign", tier: 3, cost: 12, rarity: "legendary", cat: "mult",
    text: "x1.3 mult for each J/Q/K in the counted hand.",
    onCount: (ctx) => { const n = ctx.all.filter((c) => c.rank >= 11).length;
      if (n) { ctx.mult *= Math.pow(1.3, n); return true; } } },
  { id: "nineteen", name: "The Nineteen", tier: 3, cost: 11, rarity: "legendary", cat: "rule",
    text: "A hand that scores nothing scores 45 instead.",
    onCount: (ctx) => { if (ctx.base === 0) { ctx.base = 45; return true; } } },
  { id: "doubling", name: "Doubling Cube", tier: 3, cost: 12, rarity: "legendary", cat: "mult",
    text: "Your final deal of each round scores x3.",
    onCount: (ctx) => { if (ctx.round.dealsLeft <= 1) { ctx.mult *= 3; return true; } } },
  { id: "alchemist", name: "Alchemist", tier: 3, cost: 11, rarity: "legendary", cat: "deck",
    text: "Every 2, 3 and 4 in your deck becomes a 5.",
    onAcquire: (run) => { for (const c of run.cards) if (c.rank >= 2 && c.rank <= 4) c.rank = 5; } },
  { id: "overflow", name: "Overflow", tier: 3, cost: 13, rarity: "legendary", cat: "mult",
    text: "Your multiplier is squared.",
    onCount: (ctx) => { ctx.squareMult = true; return true; } },

  // ---- second wave
  { id: "quartermaster", name: "Quartermaster", tier: 1, cost: 5, rarity: "common", cat: "fifteen",
    text: "+4 base per card of your Meldling's suit.",
    onCount: (ctx) => { const su = CRIB_DECKS[ctx.run.meldling].suit;
      const n = ctx.all.filter((c) => c.suit === su).length;
      if (n) { ctx.base += 4 * n; return true; } } },
  { id: "evenhand", name: "Even Hand", tier: 1, cost: 5, rarity: "common", cat: "pair",
    text: "+5 base per even-ranked card counted.",
    onCount: (ctx) => { const n = ctx.all.filter((c) => c.rank % 2 === 0).length;
      if (n) { ctx.base += 5 * n; return true; } } },
  { id: "oddfellow", name: "Odd Fellow", tier: 1, cost: 5, rarity: "common", cat: "run",
    text: "+5 base per odd-ranked card counted.",
    onCount: (ctx) => { const n = ctx.all.filter((c) => c.rank % 2 === 1).length;
      if (n) { ctx.base += 5 * n; return true; } } },
  { id: "shortmemory", name: "Short Memory", tier: 2, cost: 8, rarity: "uncommon", cat: "mult",
    text: "x1.5 mult on your first deal of each round.",
    onCount: (ctx) => { if (ctx.round.dealIndex === 0) { ctx.mult *= 1.5; return true; } } },
  { id: "lastword", name: "The Last Word", tier: 2, cost: 9, rarity: "uncommon", cat: "mult",
    text: "x2 mult on your final deal of each round.",
    onCount: (ctx) => { if (ctx.round.dealsLeft <= 1) { ctx.mult *= 2; return true; } } },
  { id: "thinice", name: "Thin Ice", tier: 2, cost: 10, rarity: "rare", cat: "mult",
    text: "x2.2 mult while your deck holds fewer than 30 cards.",
    onCount: (ctx) => { if (ctx.run.deckSize() < 30) { ctx.mult *= 2.2; return true; } } },
  { id: "hoarder", name: "Hoarder", tier: 2, cost: 10, rarity: "rare", cat: "mult",
    text: "x1.25 mult per mulligan you still hold.",
    onCount: (ctx) => { const m = ctx.round.mulligansLeft;
      if (m) { ctx.mult *= Math.pow(1.25, m); return true; } } },
  { id: "cutpurse", name: "Cutpurse", tier: 3, cost: 9, rarity: "rare", cat: "rule",
    text: "+2 Glim every time you count a hand.",
    onCount: (ctx) => { ctx.run.essence += 2; return true; } },
  { id: "steadyhand", name: "Steady Hand", tier: 3, cost: 10, rarity: "rare", cat: "rule",
    text: "+1 mulligan and +1 recut each round.",
    rule: { mulliganBonus: 1, recuts: 1 } },
  /* ---- additive-mult charms. These are what make ORDER matter: an additive
     charm placed before a multiplier is worth far more than after it. ---- */
  { id: "ballast", name: "Ballast", tier: 2, cost: 8, rarity: "uncommon", cat: "mult",
    text: "+0.8 mult. Placement matters — put it early.",
    onCount: (ctx) => { ctx.mult += 0.8; return true; } },
  { id: "tallyman", name: "Tallyman", tier: 2, cost: 9, rarity: "uncommon", cat: "mult",
    text: "+0.3 mult per distinct category you scored.",
    onCount: (ctx) => { const k = new Set(ctx.events.map((e) => e.kind)).size;
      if (k) { ctx.mult += 0.3 * k; return true; } } },
  { id: "slowburn", name: "Slow Burn", tier: 2, cost: 10, rarity: "rare", cat: "mult",
    text: "+0.12 mult per Reckoning you have taken.",
    onCount: (ctx) => { const n = Object.values(ctx.run.levels).reduce((a, b) => a + b, 0);
      if (n) { ctx.mult += 0.12 * n; return true; } } },
  { id: "groundwork", name: "Groundwork", tier: 1, cost: 6, rarity: "common", cat: "mult",
    text: "+0.14 mult per scoring event in the hand.",
    onCount: (ctx) => { if (ctx.events.length) { ctx.mult += 0.14 * ctx.events.length; return true; } } },
  { id: "bloodline", name: "Bloodline", tier: 2, cost: 9, rarity: "rare", cat: "mult",
    text: "+1.5 mult if every counted card is the same colour.",
    onCount: (ctx) => {
      const red = (c) => c.suit === "H" || c.suit === "D";
      if (ctx.all.every(red) || ctx.all.every((c) => !red(c))) { ctx.mult += 1.5; return true; } } },

  { id: "thebank", name: "The Bank", tier: 3, cost: 12, rarity: "legendary", cat: "mult",
    text: "x1.04 mult for every Glim you are holding.",
    onCount: (ctx) => { const g = Math.min(40, ctx.run.essence);
      if (g) { ctx.mult *= Math.pow(1.04, g); return true; } } },
];

/* ---------------------------------------------------------------- decks */
const CRIB_DECKS = {
  /* Each deck should dictate a playstyle from the first deal, the way Balatro's
     decks do — a real upside paired with a real constraint. */
  pip: {
    name: "Pip", suit: "S",
    text: "RUNS: +9 base and x2.0 mult. But pairs score half.",
    rule: { pairScale: 0.5 },
    charm: { onEvent: (e, ctx) => { if (e.kind === "run") { ctx.base += 9; return true; } },
             onCount: (ctx) => { if (ctx.events.some((e) => e.kind === "run")) { ctx.mult *= 2.0; return true; } } },
  },
  thump: {
    name: "Thump", suit: "H",
    text: "FIFTEENS: each one adds +0.2 mult. Stack them.",
    rule: {},
    charm: { onCount: (ctx) => { const n = ctx.events.filter((e) => e.kind === "fifteen").length;
      if (n) { ctx.mult += 0.2 * n; return true; } } },
  },
  clover: {
    name: "Clover", suit: "C",
    text: "FLUSHES: 3-card flushes count, x2.1 mult, and you start with two Mimic cards.",
    rule: { flushNeed: 3, startMimics: 2 },
    charm: {
      onEvent: (e, ctx) => { if (e.kind === "flush") { ctx.base += 9; return true; } },
      onCount: (ctx) => { if (ctx.events.some((e) => e.kind === "flush")) { ctx.mult *= 2.1; return true; } },
    },
  },
  nib: {
    name: "Nib", suit: "S",
    text: "THE CUT: +2 recuts a round, and whatever the cut adds, it adds twice.",
    rule: { recuts: 2, doubleCutValue: true },
  },
  muggins: {
    name: "Muggins", suit: "C",
    text: "THE THIEF: when a Spoiler blocks points, take half of them anyway.",
    rule: { muggins: true },
  },
  facet: {
    name: "Facet", suit: "D",
    text: "BIG HANDS: dealt 7, keep 5 — but your deck starts 26 cards lighter.",
    rule: { dealtBonus: 1, keepBonus: 1, deckTrim: 26 },
  },
};

/* ---------------------------------------------------------------- bosses */
/* A pool, drawn per act by severity — so no two runs meet the same five bosses.
   Each attacks a different build, and severity rises with the act. */
/* Each Spoiler is aligned to a suit. Cards of that suit score at a penalty
   against it, and cards of the opposing suit score at a bonus — so the boss plan
   you can see at run start actually informs which Meldling you take. */
const SUIT_OPPOSE = { S: "H", H: "S", C: "D", D: "C" };
const AFFINITY_WEAK = 0.6, AFFINITY_STRONG = 1.35;

const BOSS_POOL = [
  // severity 1
  { id: "ashfall",  name: "Ashfall",       art: "deadwood", sev: 1, text: "One suit turns to ash — those cards are inert.", rule: { noFlush: true, deadSuitRandom: true } , align: "S" },
  { id: "auditor",  name: "The Auditor",   art: "shuffler", sev: 1, text: "Fifteens score 1 instead of 2.",      rule: { fifteenPoints: 1 } , align: "H" },
  { id: "shortstop",name: "Shortstop",     art: "jokester", sev: 1, text: "Runs score nothing, and pairs score half.", rule: { noRuns: true, pairScale: 0.5 } , align: "C" },
  { id: "blight",   name: "Blight",        art: "deadwood", sev: 1, text: "Pairs score half.",                   rule: { pairScale: 0.5 } , align: "D" },
  { id: "chains",   name: "Chains",        art: "kingpin",  sev: 1, text: "No mulligans and no recuts.",         rule: { mulliganBonus: -9, recuts: 0 } },
  // severity 2
  { id: "irongrip", name: "Iron Grip",     art: "shuffler", sev: 2, text: "You keep one card fewer.",            rule: { keepPenalty: 1 } , align: "S" },
  { id: "famine",   name: "Famine",        art: "deadwood", sev: 2, text: "One fewer deal this round.",          rule: { dealBonus: -1 } , align: "H" },
  { id: "thief",    name: "The Thief",     art: "shuffler", sev: 2, text: "10 cards are stolen from your deck.",  rule: { roundTrim: 10 } , align: "C" },
  { id: "curse",    name: "Miser's Curse", art: "kingpin",  sev: 2, text: "The Crib scores nothing.",            rule: { cribZero: true } },
  { id: "fog",      name: "The Fog",       art: "shuffler", sev: 2, text: "Your deck tracker is hidden.",        rule: { hideTracker: true } , align: "D" },
  // severity 3
  { id: "leaden",   name: "Leaden",        art: "kingpin",  sev: 3, text: "Your multiplier is capped at x4.",    rule: { multCap: 4 } },
  { id: "puritan",  name: "Puritan",       art: "jokester", sev: 3, text: "Pairs score nothing at all.",         rule: { noPairs: true } , align: "S" },
  { id: "drought",  name: "Drought",       art: "deadwood", sev: 3, text: "One fewer deal, and no mulligans.",    rule: { dealBonus: -1, mulliganBonus: -9 } , align: "H" },
  { id: "hush",     name: "The Hush",      art: "shuffler", sev: 2, text: "Charms score nothing this round.", rule: { noCharms: true }, align: "H" },
  { id: "levy",     name: "The Levy",      art: "kingpin",  sev: 2, text: "You start the round with no Glim.",  rule: { levy: true }, align: "C" },
  { id: "shears",   name: "Shears",        art: "jokester", sev: 3, text: "Your deck is cut to 30 cards for this round.", rule: { roundTrim: 99 }, align: "D" },
  { id: "eclipse",  name: "Eclipse",       art: "kingpin",  sev: 3, text: "Fifteens score 1, flushes and nobs score nothing.", rule: { fifteenPoints: 1, noFlush: true, noNobs: true } },
];
const ACT_SEVERITY = [1, 1, 2, 2, 3];

function planBosses() {
  const used = new Set();
  const plan = [];
  for (let act = 1; act <= CRIB_ACTS; act++) {
    const sev = ACT_SEVERITY[act - 1];
    let band = BOSS_POOL.filter((b) => b.sev === sev && !used.has(b.id));
    if (!band.length) band = BOSS_POOL.filter((b) => !used.has(b.id));
    const pick = band[Math.floor(Math.random() * band.length)];
    used.add(pick.id);
    plan.push(pick);
  }
  return plan;
}

/* ---------------------------------------------------------------- run */
class CribRun {
  constructor(meldling, street) {
    this.street = street || { id: 1, name: "First Street", mods: {} };
    this.meldling = meldling;
    this.deck = CRIB_DECKS[meldling];
    this.act = 1; this.round = 1;
    this.essence = 6;
    /* Score above the target is no longer wasted: it banks as Surplus, and
       Surplus buys the right to skip a round. */
    this.surplus = 0;
    this.skips = 0;
    this.charms = [];
    this.levels = { fifteen: 0, pair: 0, run: 0, flush: 0 };
    /* Gilding a RANK is this game's answer to Balatro's card enhancements:
       every gilded card adds base whenever it appears in a scoring hand. */
    this.gilded = {};
    /* The deck is a persistent object you modify across the run, and each round
       shuffles YOUR deck and deals it down without reshuffling. That's what makes
       deck knowledge a skill and deck-building passives possible. */
    this.cards = cDeck();
    const mim = (this.deck.rule && this.deck.rule.startMimics) || 0;
    for (let i = 0; i < mim; i++) {
      const pick = Math.floor(Math.random() * this.cards.length);
      this.cards[pick] = Object.assign({}, this.cards[pick], { enh: "chameleon" });
    }
    const trim = ((this.deck.rule && this.deck.rule.deckTrim) || 0) +
                 ((this.street.mods && this.street.mods.deckTrim) || 0);
    if (trim) this.removeRandom(trim);
    this.bossPlan = planBosses();
    this.planWagers();
  }

  deckSize() { return this.cards.length; }

  addCards(list) { for (const c of list) this.cards.push(Object.assign({}, c)); }

  removeWhere(pred) {
    const before = this.cards.length;
    this.cards = this.cards.filter((c) => !pred(c));
    return before - this.cards.length;
  }

  removeRandom(n) {
    const d = cShuf(this.cards.slice());
    this.cards = d.slice(n);
    return n;
  }

  /* Rank histogram, for the deck viewer. */
  histogram() {
    const h = {};
    for (const c of this.cards) h[c.rank] = (h[c.rank] || 0) + 1;
    return h;
  }

  levelCostFor(cat) { return levelCost(this.levels[cat]); }
  gildCostFor(rank) { return 6 + (this.gilded[rank] || 0) * 5; }
  gild(rank) {
    const c = this.gildCostFor(rank);
    if (this.essence < c) return false;
    this.essence -= c;
    this.gilded[rank] = (this.gilded[rank] || 0) + 1;
    return true;
  }
  gildTotal() { return Object.values(this.gilded).reduce((a, b) => a + b, 0); }
  buyLevel(cat) {
    const c = this.levelCostFor(cat);
    if (this.essence < c) return false;
    this.essence -= c;
    this.levels[cat]++;
    return true;
  }
  roundIndex() { return (this.act - 1) * CRIB_ROUNDS + this.round; }
  target() {
    const mul = (this.street && this.street.mods.targetMul) || 1;
    if (this.isWager())
      return Math.round(CRIB_LADDER.baseTarget *
        Math.pow(CRIB_LADDER.growth, this.roundIndex() - 1) * mul * 0.55);
    return Math.round(CRIB_LADDER.baseTarget *
      Math.pow(CRIB_LADDER.growth, this.roundIndex() - 1) * mul);
  }
  /* A Wager can appear on any non-Spoiler round. It is optional, brutal, and it
     pays in a system unlock rather than Glim. */
  /* Wagers are placed once, at run start, on random non-Spoiler rounds. */
  planWagers() {
    this.wagerAt = {};
    if (typeof Achv === "undefined" || !Achv.lockedSystems().length) return;
    const slots = [];
    for (let a = 1; a <= CRIB_ACTS; a++)
      for (let r = 2; r < CRIB_ROUNDS; r++) slots.push(`${a}-${r}`);
    cShuf(slots);
    const n = 1 + (Math.random() < 0.45 ? 1 : 0);      // one, sometimes two
    for (let i = 0; i < n && i < slots.length; i++) this.wagerAt[slots[i]] = true;
  }
  isWager() { return !this.isBoss() && !!(this.wagerAt || {})[`${this.act}-${this.round}`]; }

  isBoss() {
    if (this.round === CRIB_ROUNDS) return true;
    return !!(this.street && this.street.mods.extraSpoiler) && this.round === 3;
  }
  slots() {
    const bonus = (typeof Achv !== "undefined" && Achv.hasSystem("sixth_slot")) ? 1 : 0;
    return Math.max(3, CHARM_SLOTS + bonus + ((this.street && this.street.mods.slots) || 0));
  }
  boss() {
    if (!this.isBoss()) return null;
    if (this.round === 3) return BOSS_POOL[(this.act * 7 + 3) % BOSS_POOL.length];
    return this.bossPlan[this.act - 1];
  }

  /* All passive rules merged: deck + charms + boss. */
  rules() {
    const r = { nobsPoints: 1, fifteenPoints: 2, flushNeed: 4, recuts: 0,
                dealBonus: 0, dealtBonus: 0, keepPenalty: 0,
                mulliganBonus: 0, cribKeep: 4, keepBonus: 0, pairScale: 1,
                roundTrim: 0, multCap: 0, deadSuit: null };
    const merge = (src) => { for (const k in src) {
      if (typeof src[k] === "number" && k in r) r[k] =
        (k === "flushNeed" || k === "fifteenPoints" || k === "nobsPoints" || k === "cribKeep")
          ? src[k]
          : (k === "pairScale" ? r[k] * src[k] : r[k] + src[k]);
      else r[k] = src[k];
    } };
    if (this.deck.rule) merge(this.deck.rule);
    for (const c of this.charms) if (c.rule) merge(c.rule);
    const b = this.boss();
    if (b) merge(b.rule);
    return r;
  }

  /* Deck bonus behaves as a permanent charm. */
  activeCharms() {
    const list = this.charms.slice();
    if (this.deck.charm) list.unshift(Object.assign({ name: this.deck.name, tier: 0 }, this.deck.charm));
    return list;
  }

  advance() {
    this.round++;
    if (this.round > CRIB_ROUNDS) { this.round = 1; this.act++; }
    return this.act > CRIB_ACTS;
  }

  isFull() { return this.charms.length >= this.slots(); }
  /* Charms resolve left to right, so a x1.5 placed before an additive charm
     produces a different total than the same pair reversed. Order is a real
     optimisation layer — it just needed to be reachable. */
  moveCharm(from, to) {
    if (from === to || from < 0 || to < 0) return false;
    if (from >= this.charms.length || to >= this.charms.length) return false;
    const [c] = this.charms.splice(from, 1);
    this.charms.splice(to, 0, c);
    return true;
  }

  /* What would this hand score with the charms in a given order? Lets the UI
     show the gain before you commit to a rearrangement. */
  scoreWithOrder(round, hand, order) {
    const saved = this.charms;
    this.charms = order.filter((i) => i >= 0 && i < saved.length).map((i) => saved[i]);
    const total = round.runCount(hand).total;
    this.charms = saved;
    return total;
  }

  /* The best arrangement of what you own, for the "auto-sort" button. */
  bestOrder(round, hand) {
    const n = this.charms.length;
    if (n < 2 || n > 6) return null;
    const idx = [...Array(n).keys()];
    let best = null;
    const permute = (arr, cur) => {
      if (!arr.length) {
        const t = this.scoreWithOrder(round, hand, cur);
        if (!best || t > best.total) best = { order: cur.slice(), total: t };
        return;
      }
      for (let i = 0; i < arr.length; i++)
        permute(arr.slice(0, i).concat(arr.slice(i + 1)), cur.concat([arr[i]]));
    };
    permute(idx, []);
    return best;
  }

  sell(id) {
    const i = this.charms.findIndex((c) => c.id === id);
    if (i < 0) return 0;
    const refund = Math.max(2, Math.floor(this.charms[i].cost / 2));
    this.charms.splice(i, 1);
    this.essence += refund;
    return refund;
  }

  /* Roll by rarity first, then pick within that band — so legendaries stay rare
     regardless of how many exist. */
  rollShop(n = 3) {
    const owned = new Set(this.charms.map((c) => c.id));
    const pool = CCHARMS.filter((c) => !owned.has(c.id));
    const out = [];
    let guard = 0;
    while (out.length < n && guard++ < 200) {
      const rar = rollRarity();
      const band = pool.filter((c) => (c.rarity || "common") === rar && !out.includes(c));
      const from = band.length ? band : pool.filter((c) => !out.includes(c));
      if (!from.length) break;
      out.push(from[Math.floor(Math.random() * from.length)]);
    }
    return out;
  }

  openShop() {
    this.shopState = {
      offer: this.rollShop(3),
      cards: (typeof Achv !== "undefined" && Achv.hasSystem("deep_stall"))
        ? [rollCardOffer(), rollCardOffer(), rollCardOffer(), rollCardOffer()]
        : [rollCardOffer(), rollCardOffer(), rollCardOffer()],
      rerolls: 0,
    };
    return this.shopState;
  }

  buyCard(entry) {
    if (this.essence < entry.cost) return false;
    this.essence -= entry.cost;
    this.cards.push(Object.assign({}, entry.card));
    return true;
  }
  rerollCost() { return 3 + 2 * ((this.shopState && this.shopState.rerolls) || 0); }
  reroll() {
    const c = this.rerollCost();
    if (this.essence < c) return false;
    this.essence -= c;
    this.shopState.rerolls++;
    this.shopState.offer = this.rollShop(3);
    this.shopState.cards = [rollCardOffer(), rollCardOffer(), rollCardOffer()];
    return true;
  }

  shopOffer(n = 3) { return this.rollShop(n); }

  /* What carried the whole run? */
  runMVP() {
    const c = this.contribRun || {};
    let best = null;
    for (const k in c) if (!best || c[k] > c[best]) best = k;
    return best ? { name: best, points: Math.round(c[best]) } : null;
  }
}

/* ---------------------------------------------------------------- round */
class CribRound {
  constructor(run) {
    this.run = run;
    this.mods = run.rules();
    this.target = run.target();
    this.dealsLeft = CRIB_DEALS + this.mods.dealBonus;
    this.dealIndex = 0;
    this.score = 0;
    this.crib = [];
    this.over = false; this.won = false;
    this.stock = cShuf(run.cards.slice());     // YOUR deck, dealt down once
    if (this.mods.roundTrim === 99) this.stock = this.stock.slice(0, 30);
    else if (this.mods.roundTrim) this.stock = this.stock.slice(this.mods.roundTrim);
    if (this.mods.levy) this.run.essence = 0;
    if (this.mods.deadSuitRandom)
      this.mods.deadSuit = ["S", "H", "C", "D"][Math.floor(Math.random() * 4)];
    this.startingStock = this.stock.length;
    this.seen = [];                             // everything revealed this round
    this.dealt = null; this.starter = null; this.starter2 = null;
    this.recutsLeft = 0;
    this.wager = run.isWager() ? { kind: "exact" } : null;
    this.mulligansLeft = Math.max(0, BASE_MULLIGANS + this.mods.mulliganBonus);
    this.startMulligans = this.mulligansLeft;
    this.cycle = 1;
    this.used = [];
    this.startMulligans = this.mulligansLeft;
    this.outOfCards = false;
    this.used = [];
    this.phase = "deal";      // deal -> keep -> counted
    this.lastCount = null;
  }

  keepCount() { return Math.max(2, CRIB_KEEP + this.mods.keepBonus - this.mods.keepPenalty); }
  dealtCount() { return CRIB_DEALT + this.mods.dealtBonus - this.mods.keepPenalty; }

  needed() { return this.dealtCount() + (this.mods.doubleCut ? 2 : 1); }

  /* Real cribbage order: you are dealt six, you commit four, and ONLY THEN is the
     starter cut. That is what makes the keep an expected-value decision instead of
     a lookup — and it turns the cut into an anticipation beat. */
  /* A card you have seen does not come back until the deck is spent. When it is
     spent, everything used is gathered and reshuffled — a new cycle. The round now
     ends on deals, not on running dry. */
  recycle() {
    const back = (this.used || []).concat(this.burned || []);
    if (!back.length) return false;
    /* Gathering the deck costs you a deal. Without that, thinning your deck would
       be pure upside — you'd simply meet your good cards more often. */
    this.stock = cShuf(this.stock.concat(back));
    this.used = [];
    this.burned = [];
    this.seen = [];
    this.cycle = (this.cycle || 1) + 1;
    this.dealsLeft = Math.max(0, this.dealsLeft - 1);
    this.recycled = true;
    return this.dealsLeft > 0;
  }

  newDeal() {
    if (this.over || this.dealsLeft <= 0) return null;
    if (this.stock.length < this.needed()) this.recycle();
    if (this.stock.length < this.needed()) { this.outOfCards = true; this.settle(); return null; }
    this.dealt = this.stock.splice(0, this.dealtCount());
    this.starter = null;
    this.starter2 = null;
    this.seen.push(...this.dealt);
    this.recutsLeft = this.mods.recuts;
    this.phase = "keep";
    // Foresight reverses the order back, as a paid advantage
    if (this.mods.foresight) this.cutStarter();
    return this.dealt;
  }

  cutStarter() {
    if (this.starter) return this.starter;
    this.starter = this.stock.pop();
    this.seen.push(this.starter);
    if (this.mods.doubleCut && this.stock.length) {
      this.starter2 = this.stock.pop();
      this.seen.push(this.starter2);
    }
    return this.starter;
  }

  /* Mulligan: the current six go to the Crib and you draw fresh.
     Costs a mulligan and depletes your deck, so it is never free. */
  mulligan() {
    if (this.mulligansLeft <= 0 || this.phase !== "keep") return null;
    if (this.stock.length < this.dealtCount()) return null;
    this.mulligansLeft--;
    const room = Math.max(0, CRIB_SIZE - this.crib.length);
    this.crib.push(...this.dealt.slice(0, room));
    this.burned = (this.burned || []).concat(this.dealt.slice(room));
    this.dealt = this.stock.splice(0, this.dealtCount());
    this.seen.push(...this.dealt);
    return this.dealt;
  }

  /* How lucky was that cut, really? Score the kept hand against EVERY card still
     in the deck, then rank the one you actually got. Exact, not a guess. */
  cutQuality(hand, starter) {
    const pool = this.stock.concat([starter]);
    const scores = pool.map((c) => ({
      card: c, total: this.runCount(hand, false, c, { noAffinity: false }).total,
    }));
    scores.sort((a, b) => b.total - a.total);
    const mine = this.runCount(hand, false, starter).total;
    const bare = this.runCount(hand, false, null, { noStarter: true }).total;
    let rank = scores.findIndex((x) => x.card === starter);
    if (rank < 0) rank = scores.findIndex((x) => x.total === mine);
    const of = scores.length;
    const pct = 1 - (rank / Math.max(1, of - 1));   // 1.0 = the best card there was
    const best = scores[0].total;
    const gain = mine - bare;

    /* Being the best available card only earns the fanfare if it actually paid.
       Otherwise a great-sounding cut on a dead hand feels hollow. */
    let tier = "cold";
    if (rank === 0 && gain >= 6) tier = "perfect";
    else if (rank === 0) tier = "great";
    else if (pct >= 0.92) tier = "great";
    else if (pct >= 0.72) tier = "good";
    else if (pct >= 0.35 || gain > 0) tier = "okay";
    return { tier, rank: rank + 1, of, pct, mine, best, gain, bare };
  }

  /* Which starter is live. With Double Cut we count against the better one. */
  liveStarter(hand) {
    if (!this.starter2) return this.starter;
    const a = countHand(hand, this.starter, false, this.mods).base;
    const b = countHand(hand, this.starter2, false, this.mods).base;
    return b > a ? this.starter2 : this.starter;
  }

  /* Cards not yet seen this round — powers the deck viewer. */
  remaining() {
    const used = {};
    for (const c of this.seen) used[c.rank + c.suit] = true;
    return this.stock.filter((c) => !used[c.rank + c.suit]);
  }

  remainingHistogram() {
    const h = {};
    for (const c of this.stock) h[c.rank] = (h[c.rank] || 0) + 1;
    return h;
  }

  recut() {
    if (this.recutsLeft <= 0 || !this.starter) return null;
    this.recutsLeft--;
    this.stock.unshift(this.starter);
    this.starter = this.stock.pop();
    return this.starter;
  }

  /* The scoring pipeline. Charms fire per-event and once per count, and the
     returned cascade is what the UI ticks up. */
  runCount(hand, isCrib = false, starterOverride = null, opts = {}) {
    const st = opts.noStarter ? null
      : (starterOverride || (isCrib ? this.starter : this.liveStarter(hand)));
    const res = countHand(hand, st, isCrib, this.mods);
    let suppressed = 0;
    const boss = this.run.boss();
    if (boss) {
      const clean = countHand(hand, st, isCrib, { flushNeed: this.mods.flushNeed });
      suppressed = Math.max(0, clean.base - res.base);
      if (suppressed && this.mods.muggins) {
        const claw = Math.round(suppressed / 2);
        res.base += claw;
        res.mugginsClaw = claw;
        suppressed -= claw;
      }
    }
    const ctx = { base: res.base, mult: 1, events: res.events, starter: st,
                  round: this, run: this.run, fired: [], isCrib,
                  suppressed, suppressedBy: (boss && boss.name) || null };
    ctx.all = st ? hand.concat([st]) : hand.slice();
    // category levels: flat base per scoring event of that kind
    // Nib doubles whatever the cut brought to the hand
    if (this.mods.doubleCutValue && st && !opts.noStarter) {
      const bare = countHand(hand, null, isCrib, this.mods).base;
      const gain = Math.max(0, res.base - bare);
      if (gain) { ctx.base += gain; ctx.nibBonus = gain; }
    }

    // suit affinity against the Spoiler
    const bossA = boss && boss.align;
    if (bossA && !opts.noAffinity) {
      const inHand = st ? hand.concat([st]) : hand;
      const weak = inHand.filter((c) => c.suit === bossA).length;
      const strong = inHand.filter((c) => c.suit === SUIT_OPPOSE[bossA]).length;
      if (weak || strong) {
        const f = Math.pow(AFFINITY_WEAK, weak / inHand.length) *
                  Math.pow(AFFINITY_STRONG, strong / inHand.length);
        ctx.mult *= f;
        ctx.affinity = { suit: bossA, weak, strong, factor: f };
      }
    }

    // per-card enhancements
    if (!opts.noEnh) {
      const inHand = st ? hand.concat([st]) : hand;
      let eb = 0, em = 1;
      for (const c of inHand) {
        if (c.enh === "gilded") eb += 6;
        else if (c.enh === "glass") em *= 1.4;
        else if (c.enh === "lucky" && Math.random() < 0.25) eb += 25;
      }
      if (isCrib) for (const c of hand) if (c.enh === "steel") ctx.mult += 0.6;
      if (eb) { ctx.base += eb; ctx.enhBase = eb; }
      if (em !== 1) { ctx.mult *= em; ctx.enhMult = em; }
    }

    // gilded ranks pay out for every copy present in the counted hand
    if (!opts.noGild) {
      let g = 0;
      for (const c of (st ? hand.concat([st]) : hand))
        g += 4 * (this.run.gilded[c.rank] || 0);
      if (g) { ctx.base += g; ctx.gildBonus = g; }
    }
    let lvGain = 0;
    if (!opts.noLevels)
      for (const e of res.events) lvGain += LEVEL_GAIN * (this.run.levels[e.kind] || 0);
    if (lvGain) { ctx.base += lvGain; ctx.levelBonus = lvGain; }
    const snap = () => Math.max(0, Math.round(ctx.base * ctx.mult));
    ctx.steps = [];
    let prev = snap();
    ctx.baseOnly = prev;
    for (const ch of this.run.activeCharms()) {
      if (this.mods.noCharms) break;
      if (opts.skip && opts.skip === ch) continue;
      let hit = false;
      if (ch.onEvent) for (const e of res.events) if (ch.onEvent(e, ctx)) hit = true;
      if (ch.onCount && ch.onCount(ctx)) hit = true;
      if (hit) {
        ctx.fired.push(ch.name);
        const now = snap();
        ctx.steps.push({ name: ch.name, gain: now - prev, total: now,
                         base: ctx.base, mult: ctx.mult });
        prev = now;
      }
    }
    if (ctx.squareMult) ctx.mult = ctx.mult * ctx.mult;
    if (this.mods.multCap) ctx.mult = Math.min(ctx.mult, this.mods.multCap);
    if (isCrib && this.mods.cribZero) ctx.mult = 0;
    else if (isCrib) {
      if (this.mods.miser) ctx.mult *= 3;
      else if (!this.mods.cribFull) ctx.mult *= 0.5;
    } else if (this.mods.miser) ctx.mult *= 0.5;
    ctx.total = Math.max(0, Math.round(ctx.base * ctx.mult));
    return ctx;
  }

  /* With the starter unknown, the honest preview is: points already locked in from
     your four cards, plus the expected value of the cut against what's left. */
  preview(keepIdx) {
    if (!this.dealt) return null;
    const hand = keepIdx.map((i) => this.dealt[i]);
    if (this.starter) return this.runCount(hand);
    const sure = countPoints(hand, null, false, this.mods);
    const ev = keepEVFast(hand, this.stock, this.mods);
    return { blind: true, sure, ev, events: countHand(hand, null, false, this.mods).events };
  }

  /* Coaching now compares against the best EV keep, not hindsight — the lesson a
     cribbage player actually needs. */
  bestKeepEV() {
    const opts = keepOptionsEV(this.dealt, this.stock, this.keepCount(), this.mods);
    return opts[0];
  }
  keepRank(keepIdx) {
    const opts = keepOptionsEV(this.dealt, this.stock, this.keepCount(), this.mods);
    const key = keepIdx.slice().sort((a, b) => a - b).join(",");
    const at = opts.findIndex((o) => o.idx.slice().sort((a, b) => a - b).join(",") === key);
    return { rank: at + 1, of: opts.length, best: opts[0] };
  }

  commit(keepIdx) {
    if (this.phase !== "keep") return null;
    this.cutStarter();                       // the reveal happens here
    const hand = keepIdx.map((i) => this.dealt[i]);
    const thrown = this.dealt.filter((_, i) => !keepIdx.includes(i));
    const res = this.runCount(hand);

    /* Counterfactual attribution — the "I'd have lost without this" engine.
       Re-score the same hand with each charm removed, and with no cut at all. */
    res.contrib = {};
    for (const ch of this.run.activeCharms()) {
      const without = this.runCount(hand, false, null, { skip: ch });
      const d = res.total - without.total;
      if (d !== 0) res.contrib[ch.name] = d;
    }
    const noLevels = this.runCount(hand, false, null, { noLevels: true });
    res.levelContrib = res.total - noLevels.total;
    const noCut = this.runCount(hand, false, null, { noStarter: true });
    res.cutGain = res.total - noCut.total;
    res.handOnly = noCut.total;

    // Glass can break, and Coin pays out — both resolve on the real commit only
    res.shattered = [];
    res.coins = 0;
    const counted = hand.concat([this.starter]);
    for (const c of counted) {
      if (c.enh === "coin") res.coins += 3;
      if (c.enh === "glass" && Math.random() < 0.25) {
        res.shattered.push(c);
        const i = this.run.cards.findIndex(
          (x) => x.rank === c.rank && x.suit === c.suit && x.enh === "glass");
        if (i >= 0) this.run.cards.splice(i, 1);
      }
    }
    if (res.coins) this.run.essence += res.coins;
    this.shatteredAll = (this.shatteredAll || []).concat(res.shattered);
    this.coinsAll = (this.coinsAll || 0) + res.coins;

    this.contribTotals = this.contribTotals || {};
    for (const k in res.contrib) this.contribTotals[k] = (this.contribTotals[k] || 0) + res.contrib[k];
    this.levelTotal = (this.levelTotal || 0) + res.levelContrib;
    this.cutTotal = (this.cutTotal || 0) + res.cutGain;

    const before = this.score;
    /* A cribbage crib holds exactly four. Only your earliest throws reach it —
       after that, discards are burned. That makes the first keeps the ones that
       decide what the Crib will be worth. */
    const room = Math.max(0, CRIB_SIZE - this.crib.length);
    this.crib.push(...thrown.slice(0, room));
    this.burned = (this.burned || []).concat(thrown.slice(room));
    this.used = (this.used || []).concat(hand, this.starter ? [this.starter] : []);
    this.used = (this.used || []).concat(hand, this.starter);
    res.toCrib = Math.min(room, thrown.length);
    res.burnedNow = thrown.length - res.toCrib;
    this.score += res.total;
    res.scoreBefore = before;
    res.crossedTarget = before < this.target && this.score >= this.target;
    res.wasFinalDeal = this.dealsLeft <= 1;
    this.lastCount = res;
    this.dealIndex++;
    this.dealsLeft--;
    this.phase = "counted";
    return res;
  }

  /* Best possible keep for this deal, for the coaching readout. */
  bestKeep() {
    const opts = keepOptions(this.dealt, this.starter, this.keepCount(), this.mods);
    const best = opts[0];
    return { idx: best.idx, total: this.runCount(best.idx.map((i) => this.dealt[i])).total };
  }

  /* Round end: the Crib pays out. */
  /* The Gathering: feeding the Crib well raises what it pays. */
  cribMult() {
    if (typeof Achv === "undefined" || !Achv.hasSystem("crib_mult")) return 1;
    let m = 1;
    const suits = {};
    for (const c of this.crib) {
      suits[c.suit] = (suits[c.suit] || 0) + 1;
      if (c.rank >= 11) m += 0.2;
    }
    for (const k in suits) if (suits[k] >= 2) m += 0.3 * (suits[k] - 1);
    return m;
  }

  settleCrib() {
    let hand = this.crib.slice();
    const ck = this.mods.cribKeep || CRIB_SIZE;
    if (hand.length > ck) {
      const opts = keepOptions(hand, this.starter, ck, this.mods);
      hand = opts[0].idx.map((i) => this.crib[i]);
    }
    /* The Crib's Own Cut: a second starter, drawn only for the Crib. */
    if (typeof Achv !== "undefined" && Achv.hasSystem("crib_cut") && this.stock.length) {
      this.cribStarter = this.stock.pop();
    }
    const cs = this.cribStarter || this.starter;
    const res = hand.length >= 2 ? this.runCount(hand, true, cs)
      : { base: 0, mult: 1, total: 0, events: [], fired: [] };
    const gm = this.cribMult();
    if (gm !== 1) { res.gathering = gm; res.total = Math.round(res.total * gm); }
    this.cribResult = res;
    this.score += res.total;
    return res;
  }

  /* Who carried the round, and would you have failed without them? */
  mvp() {
    const all = Object.assign({}, this.contribTotals || {});
    if (this.levelTotal) all["Category levels"] = this.levelTotal;
    if (this.cutTotal) all["The cut"] = this.cutTotal;
    let best = null;
    for (const k in all) if (!best || all[k] > all[best]) best = k;
    if (!best) return null;
    const without = this.score - all[best];
    return { name: best, points: all[best], without,
             decisive: this.score >= this.target && without < this.target };
  }

  /* Finish the moment you're over the line, and bank what you didn't spend. */
  cashOut() {
    if (this.over) return this.won;
    this.cashedOut = true;
    return this.settle();
  }

  settle() {
    if (this.over) return this.won;
    this.settleCrib();
    this.over = true;
    if (this.wager) {
      this.won = this.score === this.target;
      this.wagerWon = this.won;
    } else {
      this.won = this.score >= this.target;
    }
    this.margin = this.score - this.target;
    const band = Math.max(8, Math.round(this.target * 0.12));
    this.narrow = this.won && this.margin <= band;
    this.soClose = !this.won && -this.margin <= band;
    // fold this round's attribution into the run total
    this.run.contribRun = this.run.contribRun || {};
    const add = (k, v) => { if (v) this.run.contribRun[k] = (this.run.contribRun[k] || 0) + v; };
    for (const k in (this.contribTotals || {})) add(k, this.contribTotals[k]);
    add("Category levels", this.levelTotal || 0);
    add("The cut", this.cutTotal || 0);

    /* Income scales with the round, because targets scale exponentially while
       upgrade costs scale linearly — late rounds must fund late upgrades. */
    /* Three ways to be paid: clearing, clearing EARLY, and clearing CLEAN. */
    this.dealsSpared = Math.max(0, this.dealsLeft);
    this.mulligansSpared = Math.max(0, this.mulligansLeft);
    this.earlyBonus = this.won ? this.dealsSpared * 4 : 0;
    this.cleanBonus = this.won ? this.mulligansSpared * 3 : 0;
    this.baseGlim = this.won
      ? Math.max(4, 6 + Math.round(this.run.roundIndex() * 0.9)
          + Math.floor(Math.max(0, this.score - this.target) / Math.max(15, this.target * 0.25)))
      : 0;
    this.essenceEarned = this.won
      ? this.baseGlim + this.earlyBonus + this.cleanBonus
      : 0;
    return this.won;
  }
}

if (typeof module !== "undefined")
  module.exports = { CCHARMS, CRIB_DECKS, CribRun, CribRound,
    CRIB_ACTS, CRIB_ROUNDS, CRIB_LADDER, CRIB_DEALS, CRIB_DEALT, CRIB_KEEP, CHARM_SLOTS,
    LEVEL_CATS, LEVEL_GAIN, levelCost, BASE_MULLIGANS, CRIB_SIZE, SURPLUS_PER_SKIP,
    RARITY, RARITY_ORDER, rollRarity,
    ENHANCEMENTS, CARD_WEIGHT, RANK_PREMIUM, rollCardOffer, rollCardRank,
    BOSS_POOL, ACT_SEVERITY, planBosses, SUIT_OPPOSE, CRIB_SIZE };
