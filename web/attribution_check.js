// The Meldling's own bonus must be credited in round attribution, and fixing
// that must not change any score. Compares this engine to OLD=<web-folder>.
// usage: OLD=/path/to/old/web node web/attribution_check.js [web-folder]
const path = require("path");
const dir = path.resolve(process.argv[2] || __dirname), old = process.env.OLD && path.resolve(process.env.OLD);
global.SUIT_SYM = {};
function load(d) { const M = require(path.join(d, "meta.js")); Object.assign(global, M, require(path.join(d, "cribbage.js"))); return require(path.join(d, "cribrogue.js")); }
function play(R, meld, seed) {
  const run = new R.CribRun(meld, null, null, seed);
  run.charms = ["keystone2", "fifteener"].map((id) => R.CCHARMS.find((c) => c.id === id));
  const out = [];
  for (let r = 0; r < 3; r++) {
    const rd = new R.CribRound(run);
    while (!rd.over) { if (!rd.newDeal()) break; const res = rd.commit(rd.bestKeepEV().idx);
      out.push({ total: res.total, deckCredit: res.contrib[run.deck.name] || 0, fired: res.fired.includes(run.deck.name), contrib: res.contrib }); }
    if (!rd.over) rd.settle();
    out.push({ round: rd.score, mvp: rd.mvp() && rd.mvp().name });
    run.round++;
  }
  return out;
}
const MELDS = ["pip", "thump", "clover", "pip_asc", "thump_asc", "clover_asc", "facet_asc"];
const R = load(dir); const RO = old ? (() => { for (const k of Object.keys(require.cache)) delete require.cache[k]; return load(old); })() : null;
let checks = 0, fails = 0, credited = 0, firedDeals = 0, mvpMeld = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 5) console.log("FAIL", m); } };
for (const meld of MELDS) for (let seed = 1; seed <= 25; seed++) {
  const a = play(R, meld, seed);
  for (const d of a) {
    if (d.fired) { firedDeals++; if (d.deckCredit) credited++; }
    if (d.mvp && R.CRIB_DECKS[meld].name === d.mvp) mvpMeld++;
  }
  if (RO) {
    const b = play(RO, meld, seed);
    ok(a.length === b.length && a.every((d, i) => (d.total ?? d.round) === (b[i].total ?? b[i].round)),
       `${meld} seed ${seed}: a score changed (attribution must not change outcomes)`);
  }
}
ok(firedDeals > 100, `only ${firedDeals} deals where the Meldling fired`);
ok(credited > 0.5 * firedDeals, `Meldling credited in ${credited} of ${firedDeals} deals where it fired`);
console.log(`attribution checks: ${checks}, failures: ${fails}; Meldling fired in ${firedDeals} deals, credited in ${credited}; Meldling was a round's MVP ${mvpMeld} times`);
const good = fails === 0 && (RO ? checks > 150 : true);
console.log(good ? "ATTRIBUTION OK" : "ATTRIBUTION FAILED"); process.exit(good ? 0 : 1);
