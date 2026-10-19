/* Fixtures for the menu screens: the WEB's own Deeds, Record, Gallery and How to
   play, rendered in the built meldlings.html for a few stores, as the list of
   texts a player reads (top to bottom). The Godot screens must show the same.
     node tools/parity/gen_menus.js   (after python3 tools/build_web.py)
   -> godot/tests/fixtures/menus.json */
const vm = require("vm"), fs = require("fs"), path = require("path");
const ROOT = path.join(__dirname, "../..");
const dom = require(path.join(ROOT, "web/domtest.js"));
const html = fs.readFileSync(path.join(ROOT, "meldlings.html"), "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const sb = Object.assign({}, dom, { console: { log() {} }, setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0,
  clearInterval() {}, Math, Date, JSON, Object, Array, String, Number, Boolean, Set, Map, Promise, Error,
  isNaN, parseInt, parseFloat });
sb.globalThis = sb; sb.window = Object.assign(sb.window, sb);
const ctx = vm.createContext(sb);
blocks.forEach((b) => { try { vm.runInContext(b, ctx); } catch (e) {} });
const run = (s) => vm.runInContext(s, ctx);

/* The texts on the screen, in document order, skipping buttons and empties. */
run(`globalThis.__texts = () => { const out = []; const walk = (n) => {
  for (const c of n.children || []) {
    if (c.tagName === "BUTTON") continue;
    const t = (c._text || "").trim();
    if (t) out.push(t);
    walk(c);
  } }; walk(document.getElementById("app")); return out; }`);

const STORES = [
  { name: "fresh", store: { __v: 3 } },
  { name: "some", store: { __v: 3, got: { counted: 1, twentynine: 1, his_heels: 1 },
      history: [
        { deck: "pip", reached: 7, street: 1, score: 30, cleared: false, when: 1 },
        { deck: "thump", reached: 25, street: 2, score: 0, cleared: true, when: 2 },
        { deck: "pip", reached: 0, street: 1, score: 12, cleared: false, when: 3 },
        { deck: "clover", reached: 13, street: 3, score: 88, cleared: false, when: 4 },
      ] } },
  { name: "many", store: { __v: 3, history: Array.from({ length: 10 }, (_, i) => ({
      deck: ["pip", "thump", "clover", "facet", "nib"][i % 5], reached: (i * 7) % 26, street: 1 + (i % 3),
      score: i * 11, cleared: (i * 7) % 26 === 25, when: i })) } },
];
// every deed earned, to show the secret ones' real names
STORES.push({ name: "all", store: { __v: 3, got: Object.fromEntries(run("ACHIEVEMENTS.map((a) => a.id)").map((id) => [id, 1])) } });

const out = { stores: [], tutorial: [] };
for (const S of STORES) {
  run(`Store._cache = null; Achv.save(${JSON.stringify(S.store)}); Store._cache = null;`);
  const rec = { name: S.name, store: run("JSON.parse(JSON.stringify(Achv.load()))") };
  run("showDeeds()"); rec.deeds = run("__texts()");
  run("showHistory()"); rec.record = run("__texts()");
  rec.gallery = {};
  for (const tab of ["marks", "backs", "meld", "spoil"]) {
    run(`GAL.tab = "${tab}"; showGallery()`);
    rec.gallery[tab] = run("__texts()");
  }
  out.stores.push(rec);
}
// How to play: each step's texts
run("Tut.step = 0; Tut.active = true");
for (let i = 0; i < run("TUT_STEPS.length"); i++) {
  run(`Tut.step = ${i}; renderTutStep()`);
  out.tutorial.push(run("__texts()"));
}
const OUT = path.join(ROOT, "godot/tests/fixtures/menus.json");
fs.writeFileSync(OUT, JSON.stringify(out, null, 1));
console.log(`wrote ${OUT}: ${out.stores.length} stores, ${out.tutorial.length} tutorial steps`);
