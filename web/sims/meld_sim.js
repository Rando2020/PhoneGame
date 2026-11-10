// Run from the repo root: node web/sims/meld_sim.js "$PWD/web" <variant> <meldling> <N> [street]. The variants record the 2026-10-18 balance trials; "base" is the game as it is.
// Clear rate per Meldling under candidate balance changes (today's flow:
// the round ends at the target). VARIANT picks the change; same seeds.
const path = require("path");
const WEB = process.argv[2], VARIANT = process.argv[3], DECK = process.argv[4], N = +process.argv[5];
process.env.STREET = process.argv[6] || "1";
process.env.NRUNS = "1";
const sim = require(path.join(WEB, "cribsim.js"));
const M = require(path.join(WEB, "meta.js")); Object.assign(global, M);
const R = require(path.join(WEB, "cribrogue.js"));
const { CribRun, CRIB_DECKS } = R;
const V = {
  base: () => {},
  // Nib sees the cut before keeping, so its recuts work
  nib_fore: () => { CRIB_DECKS.nib.rule = Object.assign({}, CRIB_DECKS.nib.rule, { foresight: true }); },
  // Nib: when the cut adds points, x1.5
  nib_mult: () => { CRIB_DECKS.nib.charm = { onCount: (ctx) => { if (ctx.nibBonus) { ctx.mult *= 1.5; return true; } } }; },
  // both
  nib_both: () => { V.nib_fore(); V.nib_mult(); },
  // Muggins skims every count: x1.3
  mug_skim: () => { CRIB_DECKS.muggins.charm = { onCount: (ctx) => { ctx.mult *= 1.3; return true; } }; },
  // Muggins: +3 base per scoring event (a little off every count)
  mug_events: () => { CRIB_DECKS.muggins.charm = { onEvent: (e, ctx) => { ctx.base += 3; return true; } }; },
  // Muggins: +1.5 mult when a Spoiler is blocking, +0.4 mult otherwise
  mug_thief2: () => { CRIB_DECKS.muggins.charm = { onCount: (ctx) => { ctx.mult += ctx.suppressedBy ? 1.0 : 0.3; return true; } }; },
  mug_thief3: () => { CRIB_DECKS.muggins.charm = { onCount: (ctx) => { ctx.mult += ctx.suppressedBy ? 1.2 : 0.3; return true; } }; },
  // Facet: a 32-card deck (4 deals of 8 without recycling) instead of 22
  facet_t20: () => { CRIB_DECKS.facet.rule = Object.assign({}, CRIB_DECKS.facet.rule, { deckTrim: 20 }); },
  facet_t20m: () => { V.facet_t20(); CRIB_DECKS.facet.charm = { onCount: (ctx) => { ctx.mult *= 0.85; return true; } }; },
  facet_m85: () => { CRIB_DECKS.facet.charm = { onCount: (ctx) => { ctx.mult *= 0.85; return true; } }; },
  mug_thief: () => { CRIB_DECKS.muggins.charm = { onCount: (ctx) => { ctx.mult += ctx.suppressedBy ? 1.5 : 0.4; return true; } }; },
};
V[VARIANT]();
let sum = 0, cl = 0;
for (let i = 0; i < N; i++) {
  Math.random = makeRng(1000 + i);
  const r = sim.fullRun(DECK);
  sum += r.reached; if (r.reached >= 25) cl++;
}
console.log(JSON.stringify({ street: +process.env.STREET, variant: VARIANT, deck: DECK, N, avgRound: +(sum / N).toFixed(2), clears: +(100 * cl / N).toFixed(1) }));
