// The Daily must be the same game for everyone: the same Daily seed must give
// an identical deck (and, with STRICT=1, identical outcomes for identical play),
// whatever state Math.random is in.
// usage: [STRICT=1] node web/daily_check.js [web-folder]
// Takes a FOLDER, not a file: cribsim.js loads its own cribrogue.js, so pointing
// at one file would play the rounds with whatever engine sits beside cribsim.
const path = require("path");
const dir = path.resolve(process.argv[2] || __dirname);
if (!require("fs").statSync(dir).isDirectory()) { console.log("pass a web FOLDER"); process.exit(2); }
const crPath = path.join(dir, "cribrogue.js");
global.SUIT_SYM = {};
const M = require(path.join(dir, "meta.js")); Object.assign(global, M, require(path.join(dir, "cribbage.js")));
const R = require(crPath); Object.assign(global, R);
const { playRound, shop } = require(path.join(dir, "cribsim.js"));
const STRICT = process.env.STRICT === "1";
const DECKS = ["pip", "thump", "clover", "facet"];
const sig = (cards) => cards.map((c) => c.rank + c.suit + (c.enh || "")).join(",");
function play(seed, deck, noise) {
  Math.random = makeRng(noise);
  const run = new R.CribRun(deck, M.STREETS[0], null, seed);
  const deckSig = sig(run.cards), trace = [];
  for (let i = 0; i < 25; i++) {
    const rd = playRound(run, "best");
    trace.push([rd.score, rd.won, run.essence, run.cards.length]);
    if (!rd.won) break;
    run.essence += rd.essenceEarned; shop(run); run.shopState = null;
    if (run.advance()) break;
  }
  return { deckSig, trace: JSON.stringify(trace) };
}
let checks = 0, fails = 0; const by = {};
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 6) console.log("FAIL", m); } };
const day = new Date(2026, 9, 2);
for (let d = 0; d < 160; d++) {
  const dt = new Date(day.getTime() + d * 86400000);
  const key = `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`;
  const seed = dailySeed(key), deck = DECKS[seed % DECKS.length];
  const a = play(seed, deck, 1), b = play(seed, deck, 987654321);
  const s = (by[deck] = by[deck] || { days: 0, deckDiffers: 0, outcomeDiffers: 0 });
  s.days++;
  if (a.deckSig !== b.deckSig) s.deckDiffers++;
  if (a.trace !== b.trace) s.outcomeDiffers++;
  ok(a.deckSig === b.deckSig, `${key} (${deck}): the deck differs between two players`);
  if (STRICT) ok(a.trace === b.trace, `${key} (${deck}): same play, different outcome`);
}
// Whittled (removes 8 random cards when bought) inside a seeded run
for (let s = 1; s <= 40; s++) {
  const w = (noise) => { Math.random = makeRng(noise); const r = new R.CribRun("pip", null, null, s);
    const ch = R.CCHARMS.find((c) => c.id === "thindeck"); r.charms.push(ch); ch.onAcquire(r); return sig(r.cards); };
  ok(w(1) === w(55555), `seed ${s}: Whittled removes different cards for different players`);
}
console.log("per Daily Meldling:", JSON.stringify(by));
console.log(`daily checks: ${checks}, failures: ${fails}${STRICT ? " (strict: outcomes too)" : " (decks only)"}`);
console.log(fails === 0 && checks >= 200 ? "DAILY OK" : "DAILY FAILED");
process.exit(fails === 0 && checks >= 200 ? 0 : 1);
