/* Parity fixtures for the Godot port.
   Runs the REAL web/ engine on generated inputs and writes inputs + outputs to
   godot/tests/fixtures/parity.json. The GDScript test replays the same inputs
   and must reproduce every output.

   Math.random is replaced with a seeded xorshift, so even the unseeded code
   paths (Fickle, Brittle, deck trims) are reproducible on both sides.

   usage: node tools/parity/gen_fixtures.js         (from the repo root)
          WEB=path/to/web node tools/parity/gen_fixtures.js */
const path = require("path");
const fs = require("fs");
const WEB = process.env.WEB || path.join(__dirname, "../../web");
const OUT = process.env.OUT || path.join(__dirname, "../../godot/tests/fixtures/parity.json");

global.SUIT_SYM = { S: "\u2660", H: "\u2665", C: "\u2663", D: "\u2666" };
const meta = require(path.join(WEB, "meta.js"));
Object.assign(global, meta);
Object.assign(global, require(path.join(WEB, "cribbage.js")));
Object.assign(global, require(path.join(WEB, "cribrogue.js")));
Object.assign(global, require(path.join(WEB, "pegging.js")));

const UNSEEDED = 0xC0FFEE;
Math.random = makeRng(UNSEEDED);
const g = makeRng(20260924);                       // input generator
const ri = (n) => Math.floor(g() * n);
const pick = (a) => a[ri(a.length)];
const SU = ["S", "H", "C", "D"];

const cardOut = (c) => {
  const o = { rank: c.rank, suit: c.suit };
  for (const k of ["enh", "rank2", "suit2", "split"]) if (c[k] !== undefined) o[k] = c[k];
  return o;
};
const evOut = (e) => ({ kind: e.kind, label: e.label, points: e.points, cards: e.cards.map(cardOut) });

function randCard() {
  const c = { rank: 1 + ri(13), suit: pick(SU) };
  const x = g();
  if (x < 0.05) { c.rank2 = 1 + ri(13); c.suit2 = pick(SU); }
  else if (x < 0.10) c.enh = "wild";
  else if (x < 0.15) c.enh = pick(Object.keys(ENHANCEMENTS));
  return c;
}

const MOD_BAGS = [
  {}, {}, {},
  { aceEleven: true }, { fifteenPoints: 1 }, { noFifteens: true }, { pairDouble: true },
  { pairScale: 0.5 }, { noPairs: true }, { noRuns: true }, { runNeed: 2 }, { runCap: 3 },
  { runCardBonus: 2 }, { flushNeed: 3 }, { flushNeed: 2, flushPairs: true }, { noFlush: true },
  { noNobs: true }, { nobsPoints: 3 }, { deadSuit: "H" }, { deadSuit: "S", flushPairs: true },
  { fifteenPoints: 1, noFlush: true, noNobs: true }, { runNeed: 0, flushNeed: 0 },
  { wrapRuns: true }, { wrapRuns: true }, { wrapRuns: true, runNeed: 2 }, { wrapRuns: true, runCap: 3, runCardBonus: 2 },
];

const fx = { unseeded: UNSEEDED, rng: [], daily: [], count: [], keep: [], keepev: [], peg: [], pegplay: [], runs: [] };

/* ---- rng */
for (const seed of [1, 2, 12345, 0xFFFFFFFF, 0x80000000, 20260924]) {
  const r = makeRng(seed); const seq = [];
  for (let i = 0; i < 40; i++) seq.push(r());
  fx.rng.push({ seed, seq });
}
for (const k of ["2026-09-24", "2026-01-01", "1999-12-31", "abc", ""]) fx.daily.push({ key: k, seed: dailySeed(k) });

/* ---- count */
for (let i = 0; i < 4000; i++) {
  const n = 2 + ri(5);                          // 2..6 cards
  const hand = Array.from({ length: n }, randCard);
  const starter = g() < 0.85 ? randCard() : null;
  const isCrib = g() < 0.2;
  const mods = pick(MOD_BAGS);
  const r = countHand(hand, starter, isCrib, mods);
  fx.count.push({ hand: hand.map(cardOut), starter: starter && cardOut(starter), isCrib, mods,
                  base: r.base, events: r.events.map(evOut) });
}

/* ---- keep choice */
for (let i = 0; i < 300; i++) {
  const dealt = Array.from({ length: 5 + ri(3) }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  const starter = { rank: 1 + ri(13), suit: pick(SU) };
  const pool = Array.from({ length: 10 + ri(30) }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  const keep = Math.min(4, dealt.length - 1);
  const mods = pick(MOD_BAGS);
  const hand = dealt.slice(0, keep);
  fx.keep.push({ dealt, starter, pool, keep, mods,
    options: keepOptions(dealt, starter, keep, mods),
    evfast: keepEVFast(hand, pool, mods),
    optionsEV: keepOptionsEV(dealt, pool, keep, mods) });
}
for (let i = 0; i < 25; i++) {
  const dealt = Array.from({ length: 6 }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  const mods = pick(MOD_BAGS);
  fx.keepev.push({ dealt, mods, ev: keepEV(dealt, [0, 1, 2, 3], mods), best: bestKeepByEV(dealt, 4, mods) });
}

/* ---- pegging */
for (let i = 0; i < 1500; i++) {
  const pile = Array.from({ length: 1 + ri(7) }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  fx.peg.push({ pile, out: pegScore(pile) });
}
for (let i = 0; i < 300; i++) {
  const mine = Array.from({ length: 4 }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  const theirs = Array.from({ length: 4 }, () => ({ rank: 1 + ri(13), suit: pick(SU) }));
  const p = new PegPlay(null, mine, theirs);
  p.step();
  let guard = 0;
  while (!p.over && guard++ < 20) {
    const i2 = p.mine.findIndex((_, k) => p.playable(k));   // policy: first playable
    p.lay("you", p.mine[i2]); p.turn = "them"; p.step();
  }
  fx.pegplay.push({ mine, theirs, score: p.score, oppScore: p.oppScore,
    log: p.log.map((l) => ({ who: l.who, label: l.label, points: l.points })) });
}


/* ---- full runs. A fixed, simple policy drives the real engine through every
   Meldling, Street and Trial. The same policy lives in parity_runs.gd; if the
   two engines agree, every step of every trace matches. */
const pad = (x) => (x === undefined ? null : x);
function playRun(cfg) {
  Achv.save({ __v: 3 });                                // fresh save, in memory
  for (const s of cfg.systems) Achv.grantSystem(s);
  Math.random = makeRng(cfg.unseeded);
  const street = STREETS[cfg.street - 1];
  const trial = cfg.trial ? TRIALS.find((t) => t.id === cfg.trial) : null;
  const run = new CribRun(cfg.meld, street, trial, cfg.seed === null ? undefined : cfg.seed);
  if (cfg.endless) { run.enterEndless(); run.endlessRound = 0; }
  const T = { cards: run.cards.map(cardOut), bosses: run.bossPlan.map((b) => b.id),
              wagers: Object.keys(run.wagerAt).sort(), rounds: [] };
  for (let r = 0; r < cfg.maxRounds; r++) {
    const rd = new CribRound(run);
    const RT = { idx: run.roundIndex(), target: rd.target, boss: pad(run.boss() && run.boss().id),
                 deadSuit: pad(rd.mods.deadSuit), stock: rd.stock.length, wager: !!rd.wager, deals: [] };
    let guard = 0;
    while (!rd.over && guard++ < 30) {
      if (!rd.newDeal()) break;
      let best = rd.bestKeepEV();
      let mull = false;
      if (rd.dealIndex === 0 && rd.mulligansLeft > 0 && best.ev < 4 && rd.mulligan()) { mull = true; best = rd.bestKeepEV(); }
      const kept = best.idx.map((i) => rd.dealt[i]);
      let ord = null;
      if (run.charms.length >= 2 && rd.dealIndex === 1) ord = run.bestOrder(rd, kept);
      const rank = rd.keepRank(best.idx);
      const pv = rd.preview(best.idx);
      const res = rd.commit(best.idx);
      const q = rd.cutQuality(kept, rd.starter);
      RT.deals.push({
        dealt: rd.dealt.map(cardOut), keep: best.idx, ev: best.ev, mull, rank: rank.rank,
        pv: pv.blind ? [pv.sure, pv.ev] : pv.total, ord: ord && [ord.order, ord.total],
        starter: cardOut(rd.starter), total: res.total, base: res.base, mult: res.mult,
        labels: res.events.map((e) => e.label), fired: res.fired,
        steps: res.steps.map((x) => [x.name, x.gain, x.total]), contrib: res.contrib,
        levelContrib: res.levelContrib, cutGain: res.cutGain, coins: res.coins,
        shattered: res.shattered.length, q: [q.tier, q.rank, q.of, q.mine, q.best, q.bare],
        essence: run.essence, deck: run.cards.length, stock: rd.stock.length, score: rd.score });
      if (rd.score >= rd.target && !rd.mods.noCashOut && !rd.wager) rd.cashOut();
    }
    if (!rd.over) rd.settle();
    const cr = rd.cribResult;
    Object.assign(RT, { won: rd.won, score: rd.score, crib: cr.total, cribLabels: cr.events.map((e) => e.label),
      earned: rd.essenceEarned, mvp: rd.mvp(), cycle: rd.cycle, outOfCards: rd.outOfCards,
      wagerWon: !!rd.wagerWon, narrow: rd.narrow });
    T.rounds.push(RT);
    if (!rd.won) break;
    run.essence += rd.essenceEarned;
    if (!rd.mods.noShop) {
      const shop = run.openShop();
      RT.shop = { offer: shop.offer.map((c) => c.id), cards: shop.cards.map((e) => [cardOut(e.card), e.cost]) };
      for (const c of shop.offer)
        if (!run.isFull() && run.essence >= c.cost) {
          run.essence -= c.cost; run.charms.push(c); if (c.onAcquire) c.onAcquire(run); RT.bought = c.id; break;
        }
      for (const e of shop.cards) if (run.buyCard(e)) break;
      if (run.essence >= 20 && run.reroll()) RT.reroll = shop.offer.map((c) => c.id);
      for (const cat of LEVEL_CATS) if (run.buyLevel(cat)) break;
      if (run.essence >= 15) run.gild(5);
      if (run.charms.length >= 3 && run.roundIndex() % 4 === 0) RT.sold = run.sell(run.charms[0].id);
      if (run.charms.length >= 2) run.moveCharm(run.charms.length - 1, 0);
    }
    if (run.endless) { run.endlessRound = (run.endlessRound || 0) + 1; continue; }
    if (run.advance()) { T.cleared = true; break; }
  }
  T.end = { essence: run.essence, deck: run.cards.length, charms: run.charms.map((c) => c.id),
            levels: run.levels, mvp: run.runMVP() };
  return JSON.parse(JSON.stringify(T));
}

const MELDS = Object.keys(CRIB_DECKS);
const SYS = SYSTEMS.map((s) => s.id);
const cfgs = [];
for (const meld of MELDS) for (const st of [1, 3, 5, 8])
  cfgs.push({ meld, street: st, trial: null, seed: 1 + ri(1e9), unseeded: 1 + ri(1e9), systems: [], endless: false });
for (const t of TRIALS)
  cfgs.push({ meld: t.deck, street: 1, trial: t.id, seed: 1 + ri(1e9), unseeded: 1 + ri(1e9), systems: [], endless: false });
for (let i = 0; i < 24; i++)
  cfgs.push({ meld: pick(MELDS), street: 1 + ri(8), trial: null, seed: g() < 0.25 ? null : 1 + ri(1e9),
              unseeded: 1 + ri(1e9), systems: SYS.filter(() => g() < 0.5), endless: g() < 0.2 });
for (const c of cfgs) { c.maxRounds = c.endless ? 6 : 25; fx.runs.push({ cfg: c, trace: playRun(c) }); }
/* Mythic-heavy runs: force the side-effect charms into the build. */
for (const ids of [["cutpurse", "usury", "collector"], ["echo", "thelong", "thebank", "overflow"],
                   ["alchemist", "loaded", "royalblood"], ["foresight", "doublecut", "exchange", "greedycrib"]]) {
  const c = { meld: pick(MELDS), street: 4, trial: null, seed: 1 + ri(1e9), unseeded: 1 + ri(1e9),
              systems: SYS, endless: false, maxRounds: 10, force: ids };
  fx.runs.push({ cfg: c, trace: playRunForced(c) });
}
/* Double Cut on thin decks that reshuffle often: the only place the second
   starter's return to the deck changes play (doublecut-leak). Appended last so
   earlier fixtures keep their inputs. */
for (const [trial, seed] of [[null, 424242], ["thirteen", 131313]]) {
  const c = { meld: "facet", street: 1, trial, seed, unseeded: 77, systems: [], endless: false,
              maxRounds: 12, force: ["doublecut", "fifthdeal"] };
  fx.runs.push({ cfg: c, trace: playRunForced(c) });
}
function playRunForced(c) {
  const orig = CribRun.prototype.planWagers;
  const push = CribRun.prototype.planWagers = function () {
    orig.call(this);
    for (const id of c.force) { const ch = CCHARMS.find((x) => x.id === id); this.charms.push(ch); if (ch.onAcquire) ch.onAcquire(this); }
  };
  try { return playRun(c); } finally { CribRun.prototype.planWagers = orig; }
}

/* ---- the cut ceremony's tier, computed the way the web UI does (cribrogue_ui
   commit flow): snapshot the stock BEFORE commit, then score the live starter
   against that snapshot. Appended last so earlier fixtures keep their inputs. */
fx.cutui = [];
for (let i = 0; i < 90; i++) {
  const meld = ["pip", "thump", "clover", "facet", "nib"][i % 5];
  const build = i % 4 === 3 ? ["doublecut"] : (i % 4 === 2 ? ["foresight"] : []);
  const seed = 9000 + i;
  Achv.save({ __v: 3 }); Math.random = makeRng(UNSEEDED);
  const run = new CribRun(meld, null, null, seed);
  for (const id of build) run.charms.push(CCHARMS.find((c) => c.id === id));
  const rd = new CribRound(run);
  for (let d = 0; d < 3 && !rd.over; d++) {
    if (!rd.newDeal()) break;
    const knew = !!rd.starter;
    const idx = rd.bestKeepEV().idx, kept = idx.map((k) => rd.dealt[k]);
    const preStock = rd.stock.slice();
    rd.commit(idx);
    const starter = rd.liveStarter(kept);
    const live = rd.stock; rd.stock = preStock;
    const q = rd.cutQuality(kept, starter);
    rd.stock = live;
    fx.cutui.push({ seed, meld, build, deal: d, knew, tier: q.tier, rank: q.rank, of: q.of, gain: q.gain,
                    starter: cardOut(starter) });
  }
}

/* ---- the shop, driven the way the web UI's buttons drive it (showCribShop):
   charm buys are done by the UI itself (essence, push, onAcquire, drop from
   offer); cards, reroll, Reckonings and selling call the run. A scripted policy
   picks a legal action each step; every step's state is recorded. Appended last. */
fx.shopui = [];
{
  const snap = (run) => ({
    essence: run.essence, charms: run.charms.map((c) => c.id), levels: Object.assign({}, run.levels),
    deck: run.cards.length, last: cardOut(run.cards[run.cards.length - 1]),
    offer: run.shopState.offer.map((c) => c.id),
    cards: run.shopState.cards.map((e) => [cardOut(e.card), e.cost, !!e.sold]),
    rerolls: run.shopState.rerolls, rerollCost: run.rerollCost(), full: run.isFull(), slots: run.slots() });
  const MELDS = ["pip", "thump", "clover", "facet", "nib", "muggins"];
  const SYS = ["split_cards", "deep_stall", "sixth_slot"];
  for (let i = 0; i < 40; i++) {
    const cfg = { meld: MELDS[i % MELDS.length], street: [1, 4, 6][i % 3], seed: 7000 + i,
                  systems: SYS.filter(() => g() < 0.5), own: [], essence: 30 + ri(90) };
    const nOwn = ri(6);
    while (cfg.own.length < nOwn) { const c = pick(CCHARMS); if (!cfg.own.includes(c.id) && c.rarity !== "mythic") cfg.own.push(c.id); }
    Achv.save({ __v: 3 }); for (const sy of cfg.systems) Achv.grantSystem(sy);
    Math.random = makeRng(UNSEEDED);
    const run = new CribRun(cfg.meld, STREETS[cfg.street - 1], null, cfg.seed);
    for (const id of cfg.own) { const c = CCHARMS.find((x) => x.id === id); if (run.isFull()) break; run.charms.push(c); if (c.onAcquire) c.onAcquire(run); }
    cfg.own = run.charms.map((c) => c.id);
    run.essence = cfg.essence;
    run.openShop();
    const steps = [{ act: null, state: snap(run) }];
    for (let k = 0; k < 10; k++) {
      const cand = [];
      for (const ch of run.shopState.offer)
        if (!run.charms.some((x) => x.id === ch.id) && ch.cost <= run.essence && !run.isFull()) cand.push(["charm", ch.id]);
      run.shopState.cards.forEach((e, j) => { if (!e.sold && run.essence >= e.cost) cand.push(["card", j]); });
      if (run.essence >= run.rerollCost()) cand.push(["reroll"]);
      for (const cat of LEVEL_CATS) if (run.essence >= run.levelCostFor(cat)) cand.push(["level", cat]);
      for (const ch of run.charms) cand.push(["sell", ch.id]);
      if (!cand.length) break;
      const a = cand[ri(cand.length)];
      if (a[0] === "charm") {
        const ch = run.shopState.offer.find((x) => x.id === a[1]);
        run.essence -= ch.cost; run.charms.push(ch); if (ch.onAcquire) ch.onAcquire(run);
        run.shopState.offer = run.shopState.offer.filter((x) => x.id !== ch.id);
      } else if (a[0] === "card") { const e = run.shopState.cards[a[1]]; if (run.buyCard(e)) e.sold = true; }
      else if (a[0] === "reroll") run.reroll();
      else if (a[0] === "level") run.buyLevel(a[1]);
      else if (a[0] === "sell") run.sell(a[1]);
      steps.push({ act: a, state: snap(run) });
    }
    fx.shopui.push({ cfg, steps });
  }
}

if (require.main === module) {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(fx));
  console.log(`wrote ${OUT}: count ${fx.count.length}, keep ${fx.keep.length}, peg ${fx.peg.length}, pegplay ${fx.pegplay.length}, runs ${fx.runs.length}`);
}
module.exports = { fx };
