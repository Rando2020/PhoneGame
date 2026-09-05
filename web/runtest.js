const vm = require("vm");
const fs = require("fs");
const dom = require("./domtest.js");

const html = fs.readFileSync("../meldlings.html", "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);

const sandbox = Object.assign({}, dom, {
  console, setTimeout, clearTimeout, setInterval, clearInterval, Math, Date, JSON,
  Object, Array, String, Number, Boolean, Set, Map, Promise, Error, isNaN, parseInt,
  parseFloat, TextServer: {},
});
sandbox.globalThis = sandbox;
sandbox.window = Object.assign(sandbox.window, sandbox);
const ctx = vm.createContext(sandbox);

let failed = 0;
blocks.forEach((b, i) => {
  try { vm.runInContext(b, ctx, { filename: `block${i}.js` }); }
  catch (e) { failed++; console.log(`LOAD ERROR in block ${i}: ${e.message}\n  ${(e.stack||"").split("\n")[1]||""}`); }
});
if (!failed) console.log("all blocks loaded clean");

const step = (label, fn) => {
  try { fn(); console.log(`  ok    ${label}`); }
  catch (e) {
    failed++;
    console.log(`  FAIL  ${label}\n          ${e.message}`);
    const line = (e.stack || "").split("\n").find((l) => l.includes("block"));
    if (line) console.log(`          ${line.trim()}`);
  }
};

console.log("\ndriving the real UI:");
step("showTitle", () => ctx.showTitle());
step("showCribSelect", () => ctx.showCribSelect());
step("showTutorial", () => ctx.showTutorial());
step("showDeeds", () => ctx.showDeeds());
step("showPeddler", () => ctx.showPeddler());
/* top-level `const` lives in lexical scope, so reach it by evaluating source */
const run = (src) => vm.runInContext(src, ctx);
step("start a run", () => run('Cb.street = STREETS[0]; Cb.run = new CribRun("pip", Cb.street); cribRoundIntro();'));
step("begin round + render table", () =>
  run('Cb.round = new CribRound(Cb.run); Cb.round.newDeal(); Cb.keep = []; renderCrib();'));
step("select the keep", () =>
  run('for (let i = 0; i < Cb.round.keepCount(); i++) cribToggle(i);'));
step("commit + cut + cascade", () => run('doCribCount();'));
step("advance timers (cut ceremony)", () => {});
step("shop", () => run('Cb.run.openShop(); showCribShop();'));
step("round end", () => run('Cb.round.settle(); cribRoundEnd();'));
step("mulligan", () => run('Cb.round = new CribRound(Cb.run); Cb.round.newDeal(); Cb.keep=[]; renderCrib(); Cb.round.mulligan(); renderCrib();'));
step("deeds after play", () => run('showDeeds();'));
process.exit(failed ? 1 : 0);
