// Regression check for the cascade sequencing fix (rebuild meldlings.html first).
// Expect rows: fifteen, level, gild, cut, charm.  usage: node web/cascadecheck.js [path/to/meldlings.html]
// Drives the real cribCascade in the harness DOM with a hand that has a level
// bonus AND a charm step, and reports which cascade rows got rendered.
const vm = require("vm"), fs = require("fs"), dom = require("./domtest.js");
const html = fs.readFileSync(process.argv[2] || "../meldlings.html", "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const q = [];
const fakeTimeout = (fn, ms) => { q.push(fn); return q.length; };
const sandbox = Object.assign({}, dom, { console, setTimeout: fakeTimeout, clearTimeout() {}, setInterval() {}, clearInterval() {},
  Math, Date, JSON, Object, Array, String, Number, Boolean, Set, Map, Promise, Error, isNaN, parseInt, parseFloat, TextServer: {},
  requestAnimationFrame: (f) => q.push(() => f(1e9)) });
sandbox.globalThis = sandbox; sandbox.window = Object.assign(sandbox.window, sandbox);
const ctx = vm.createContext(sandbox);
blocks.forEach((b, i) => vm.runInContext(b, ctx, { filename: `block${i}.js` }));
vm.runInContext(`Cb.run = new CribRun("pip"); Cb.round = new CribRound(Cb.run); Cb.round.newDeal();`, ctx);
const res = { events: [{ kind: "fifteen", label: "Fifteen 2", points: 2, cards: [] }], levelBonus: 3, gildBonus: 4,
  cutGain: 2, suppressed: 0, steps: [{ name: "Keystone", gain: 5, total: 20, base: 10, mult: 2 }], fired: ["Keystone"],
  base: 10, mult: 2, total: 20, baseOnly: 15, isCrib: false, crossedTarget: false, contrib: {} };
ctx.__res = res;
vm.runInContext(`cribCascade(__res, null, Cb.round.dealt.slice(0,4), Cb.round.dealt[4], 0, () => { globalThis.__done = true; });`, ctx);
let n = 0; while (q.length && n++ < 5000) q.shift()();
const rows = {};
const seen = new Set();
const walk = (n) => { if (!n || seen.has(n)) return; seen.add(n);
  const cls = n.className || ""; const m = /casrow k-(\w+)/.exec(cls); if (m) rows[m[1]] = (rows[m[1]] || 0) + 1;
  for (const c of n.children || []) walk(c); };
walk(dom.app); walk(sandbox.document && sandbox.document.body);
console.log(JSON.stringify(rows), "done:", !!ctx.__done);
