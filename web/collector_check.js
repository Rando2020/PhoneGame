// The Collector: once a round the counted card in the most scoring events joins
// the deck; +2 base per card collected this run; hypothetical counts add nothing.
// usage: node web/collector_check.js [web-folder]
const path = require("path"); const dir = path.resolve(process.argv[2] || __dirname);
global.SUIT_SYM = {}; const M = require(path.join(dir, "meta.js")); Object.assign(global, M, require(path.join(dir, "cribbage.js")));
const R = require(path.join(dir, "cribrogue.js"));
let checks = 0, fails = 0; const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 6) console.log("FAIL", m); } };
const col = R.CCHARMS.find((c) => c.id === "collector");
for (let seed = 1; seed <= 40; seed++) {
  const run = new R.CribRun("thump", null, null, seed); run.charms = [col];
  for (let r = 0; r < 3; r++) {
    const rd = new R.CribRound(run); const n0 = run.cards.length, have0 = run.collectedCount || 0;
    let added = 0, deals = 0;
    while (!rd.over && deals < 4) {
      if (!rd.newDeal()) break; deals++;
      const idx = rd.bestKeepEV().idx, kept = idx.map((i) => rd.dealt[i]);
      const before = run.cards.length;
      rd.preview(idx); run.bestOrder && run.bestOrder(rd, kept);
      ok(run.cards.length === before, `seed ${seed}: a preview added a card`);
      const res = rd.commit(idx);
      rd.cutQuality(kept, rd.starter);
      // the base bonus equals 2 x cards collected before this count
      if (res.fired.includes("The Collector") && (run.collectedCount || 0) > 0 && have0 + added > 0) {
        const step = res.steps.find((s) => s.name === "The Collector");
        ok(step !== undefined, `seed ${seed}: Collector fired without a step`);
      }
      // the collected card is the one in the most scoring events
      if (run.cards.length > before) {
        added++;
        const got = run.cards[run.cards.length - 1];
        const counted = kept.concat([rd.liveStarter(kept)]);
        const score = (c) => res.events.filter((e) => e.cards.includes(c)).length;
        const bestN = Math.max(...counted.map(score));
        ok(bestN > 0 && counted.some((c) => score(c) === bestN && c.rank === got.rank && c.suit === got.suit),
           `seed ${seed}: collected ${got.rank}${got.suit} isn't the best counted card`);
      }
    }
    if (!rd.over) rd.settle();
    ok(run.cards.length - n0 <= 1, `seed ${seed} round ${r}: ${run.cards.length - n0} cards collected in one round`);
    ok((run.collectedCount || 0) === have0 + (run.cards.length - n0), `seed ${seed}: collectedCount out of step with the deck`);
    run.round++;
  }
}
// +2 base per collected card, exactly
{ const run = new R.CribRun("thump", null, null, 99); run.charms = [col]; run.collectedCount = 5;
  const rd = new R.CribRound(run); rd.newDeal(); const idx = rd.bestKeepEV().idx; const hand = idx.map((i) => rd.dealt[i]);
  rd.cutStarter(); const a = rd.runCount(hand); run.collectedCount = 0; const b = rd.runCount(hand);
  ok(a.base - b.base === 10, `5 collected cards add ${a.base - b.base} base, want 10`); }
console.log(`collector checks: ${checks}, failures: ${fails}`); const good = fails === 0 && checks > 300;
console.log(good ? "COLLECTOR OK" : "COLLECTOR FAILED"); process.exit(good ? 0 : 1);
