/* The round-end screen must pay the Crib exactly once.
   cribRoundEnd used to settle the Crib and then call settle(), which settles it
   again: every round that ended naturally paid the Crib twice (40 of 40 seeds
   with a scoring Crib, before cribend.patch). This plays real rounds in the
   built meldlings.html and calls the web's own cribRoundEnd.
     node web/cribend_check.js        (after python3 tools/build_web.py) */
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
let checks = 0, fails = 0, scored = 0, cut = 0;
for (const sys of [[], ["crib_cut"], ["crib_mult"]]) {
  for (let seed = 1; seed <= 40; seed++) {
    const out = run(`(() => {
      Achv.save({ __v: 3 }); for (const s of ${JSON.stringify(sys)}) Achv.grantSystem(s);
      Cb.street = STREETS[0];
      Cb.run = new CribRun(["pip","thump","clover","facet"][${seed} % 4], STREETS[0], null, ${seed});
      Cb.round = new CribRound(Cb.run);
      const rd = Cb.round;
      while (!rd.over) {
        if (!rd.newDeal()) break;
        rd.commit(rd.bestKeepEV().idx);
        if (!(rd.dealsLeft > 0 && rd.score < rd.target)) break;
      }
      if (rd.over) return null;
      const before = rd.score, stock = rd.stock.length;
      cribRoundEnd();
      return { before, after: rd.score, crib: rd.cribResult.total, popped: stock - rd.stock.length, stock };
    })()`);
    if (!out) continue;
    checks++;
    if (out.crib) scored++;
    if (out.popped) cut++;
    // the Crib's Own Cut draws one card, if one is left (Facet's 32 cards can run out exactly)
    const good = out.after - out.before === out.crib && out.popped === (sys.includes("crib_cut") && out.stock > 0 ? 1 : 0);
    if (!good) { fails++; if (fails <= 5) console.log("FAIL", sys, seed, out); }
  }
}
console.log(`round-end checks: ${checks} (Crib scored in ${scored}, Crib's Own Cut drawn in ${cut}), failures: ${fails}`);
const ok = fails === 0 && scored >= 60 && cut >= 25;
console.log(ok ? "CRIBEND OK" : "CRIBEND FAILED");
process.exit(ok ? 0 : 1);
