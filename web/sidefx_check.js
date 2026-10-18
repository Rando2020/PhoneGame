// Side-effect charms (Cutpurse, Usury, The Collector) must change the run only
// on REAL counts (commit's main count, settleCrib), exactly once each.
// usage: node web/sidefx_check.js [path/to/cribrogue.js]     exit 0 = pass
const path = require("path");
const crPath = path.resolve(process.argv[2] || path.join(__dirname, "cribrogue.js"));
global.SUIT_SYM = {};
Object.assign(global, require(path.join(__dirname, "meta.js")), require(path.join(__dirname, "cribbage.js")));
const { CribRun, CribRound, CCHARMS } = require(crPath);
let checks = 0, fails = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 10) console.log("FAIL", m); } };
const ch = (id) => CCHARMS.find((x) => x.id === id);
function round(ids, seed, essence = 20) {
  const run = new CribRun("thump", null, null, seed);
  run.charms = ids.map(ch); run.essence = essence;
  const rd = new CribRound(run); rd.newDeal();
  return { run, rd };
}
for (let seed = 1; seed <= 40; seed++) {
  // Cutpurse: hypothetical counts pay nothing; one commit pays exactly +2
  let { run, rd } = round(["cutpurse", "keystone2"], seed);
  const idx = rd.bestKeepEV().idx, kept = idx.map((i) => rd.dealt[i]);
  let e = run.essence;
  rd.preview(idx); run.bestOrder(rd, kept);
  ok(run.essence === e, `seed ${seed}: preview/bestOrder paid ${run.essence - e}`);
  const res = rd.commit(idx);
  ok(run.essence === e + 2 + res.coins, `seed ${seed}: commit paid ${run.essence - e - res.coins}, want 2`);
  ok(res.glim === 2, `seed ${seed}: res.glim ${res.glim}`);
  e = run.essence;
  rd.cutQuality(kept, rd.starter); rd.bestKeep && rd.phase !== "counted" && rd.bestKeep();
  ok(run.essence === e, `seed ${seed}: cutQuality paid ${run.essence - e}`);
  // crib count is a real count: pays once
  e = run.essence; rd.settleCrib();
  ok(run.essence === e + (rd.cribResult.fired.includes("Cutpurse") ? 2 : 0), `seed ${seed}: crib paid ${run.essence - e}`);

  // Usury: -4 per real count, clamped at 0
  ({ run, rd } = round(["usury"], seed, 3));
  const r2 = rd.commit(rd.bestKeepEV().idx);
  ok(run.essence === Math.max(0, 3 - 4) + r2.coins, `seed ${seed}: usury left ${run.essence}`);

  // Collector: exactly one card per real count
  ({ run, rd } = round(["collector"], seed));
  const n0 = run.cards.length;
  const k3 = rd.bestKeepEV().idx; rd.preview(k3);
  const r3 = rd.commit(k3);
  rd.cutQuality(k3.map((i) => rd.dealt[i]), rd.starter);
  ok(run.cards.length === n0 + 1, `seed ${seed}: collector added ${run.cards.length - n0}`);
}
// The Bank must still see Cutpurse placed before it (order is a design feature)
{
  const a = round(["cutpurse", "thebank"], 7, 10), b = round(["thebank", "cutpurse"], 7, 10);
  const idx = a.rd.bestKeepEV().idx;
  const ra = a.rd.commit(idx), rb = b.rd.commit(idx);
  ok(ra.mult > rb.mult, `Bank after Cutpurse (x${ra.mult.toFixed(3)}) should beat Bank first (x${rb.mult.toFixed(3)})`);
  ok(Math.abs(ra.mult / rb.mult - 1.04 ** 2) < 1e-9, `order effect is exactly 1.04^2 (got ${(ra.mult / rb.mult).toFixed(6)})`);
}
console.log(`side-effect checks: ${checks}, failures: ${fails}`);
console.log(fails === 0 && checks > 200 ? "SIDEFX OK" : "SIDEFX FAILED");
process.exit(fails === 0 && checks > 200 ? 0 : 1);
