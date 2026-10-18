/* A lost Daily must lock the Daily for that date, and a lost Long Count must
   save its best round. Plays real runs in the built meldlings.html, losing on
   purpose (keeping the worst four cards), and calls the web's own cribRoundEnd.
     node web/record_check.js        (after python3 tools/build_web.py) */
const vm = require("vm"), fs = require("fs"), path = require("path");
const dom = require(path.join(__dirname, "domtest.js"));
const html = fs.readFileSync(path.join(__dirname, "../meldlings.html"), "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const sb = Object.assign({}, dom, { console, setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0,
  clearInterval() {}, Math, Date, JSON, Object, Array, String, Number, Boolean, Set, Map, Promise, Error,
  isNaN, parseInt, parseFloat });
sb.globalThis = sb; sb.window = Object.assign(sb.window, sb);
const ctx = vm.createContext(sb);
blocks.forEach((b) => { try { vm.runInContext(b, ctx); } catch (e) { console.log("load", e.message); } });
const run = (s) => vm.runInContext(s, ctx);
let checks = 0, fails = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; console.log("FAIL", m); } };
// lose a round on purpose: keep the lowest four by rank
// every round ends through the web's cribRoundEnd; stop at the first real loss
const LOSE = `(() => { for (let r = 0; r < 25; r++) { const rd = Cb.round;
  while (!rd.over) { if (!rd.newDeal()) break;
    const idx = rd.dealt.map((c, i) => i).sort((a, b) => rd.dealt[a].rank - rd.dealt[b].rank).slice(0, rd.keepCount());
    rd.commit(idx); if (!(rd.dealsLeft > 0 && rd.score < rd.target)) break; }
  cribRoundEnd();                          // the Crib can still win it here
  if (!rd.won) return { won: false, score: rd.score, idx: Cb.run.roundIndex() };
  if (Cb.run.endless) Cb.run.endlessRound++; else Cb.run.advance();
  Cb.round = new CribRound(Cb.run); } return { won: true }; })()`;
for (const key of ["2026-10-18", "2026-11-02", "2027-01-01"]) {
  const out = run(`(() => { Achv.save({ __v: 3 });
    const seed = dailySeed("${key}"), decks = ["pip","thump","clover","facet"];
    Cb.run = new CribRun(decks[seed % decks.length], STREETS[0], null, seed); Cb.run.daily = "${key}";
    Cb.round = new CribRound(Cb.run); return ${LOSE}; })()`);
  ok(!out.won, `daily ${key}: meant to lose ${JSON.stringify(out)}`);
  const done = run(`Achv.dailyDone("${key}")`);
  ok(done && done.reached === out.idx - 1 && done.score === out.score, `daily ${key}: recorded ${JSON.stringify(done)}`);
  ok(run(`Achv.dailyDone("1999-01-01")`) === null, "another date stays open");
}
for (const meld of ["pip", "facet"]) {
  const out = run(`(() => { Achv.save({ __v: 3 });
    Cb.run = new CribRun("${meld}", STREETS[0]); Cb.run.enterEndless(); Cb.run.endlessRound = 2;
    Cb.round = new CribRound(Cb.run); return ${LOSE}; })()`);
  ok(!out.won && run(`Achv.bestEndless()`) === out.idx - 1, `endless ${meld}: best ${run("Achv.bestEndless()")}, expected ${out.idx - 1}`);
  run(`Achv.setEndless(5)`);
  ok(run(`Achv.bestEndless()`) === out.idx - 1, "a worse Long Count doesn't lower the best");
}
console.log(`record checks: ${checks}, failures: ${fails}`);
console.log(fails === 0 && checks >= 13 ? "RECORD OK" : "RECORD FAILED");
process.exit(fails === 0 && checks >= 13 ? 0 : 1);
