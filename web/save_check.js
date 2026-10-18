/* Save and resume, web side (mirrors godot/tests/resume_test.gd). A bot plays
   real runs in the built meldlings.html through the real UI functions and
   buttons, twice: once straight through, once "killing the tab" every few saves
   (a brand new page loaded from the same localStorage, resumed through the
   title's CONTINUE). Every decision the bot makes must see the same state in
   both, and the runs must end the same. Kills land on every kind of save: the
   intro, a deal, a half-picked keep, a mulligan, a settled count, The Play
   mid-hand and between your lay and the Spoiler's answer, a won round, the shop
   and right after a purchase.
     node web/save_check.js        (after python3 tools/build_web.py) */
const vm = require("vm"), fs = require("fs"), path = require("path");
const dom = require(path.join(__dirname, "domtest.js"));
const html = fs.readFileSync(path.join(__dirname, "../meldlings.html"), "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const scripts = blocks.map((b) => new vm.Script(b));

let checks = 0, fails = 0;
const ok = (c, m) => { checks++; if (!c) { fails++; if (fails <= 10) console.log("FAIL", m); } };

/* A fresh page: its own globals, a timer queue the bot drains, and a seeded
   Math.random (presentation draws from it; the engine must not, on a seeded run). */
function page(mathSeed) {
  const timers = [];
  let now = 0;
  const setTimeout = (fn, ms) => { timers.push({ at: now + (ms || 0), fn, n: timers.length + Math.random() }); return timers.length; };
  let s = mathSeed >>> 0 || 1;
  const M = Object.create(Math);
  M.random = () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  const sb = Object.assign({}, dom, { console: { log() {} }, setTimeout, clearTimeout() {}, setInterval: () => 0,
    clearInterval() {}, Math: M, Date, JSON, Object, Array, String, Number, Boolean, Set, Map, Promise, Error,
    isNaN, parseInt, parseFloat, requestAnimationFrame: (f) => setTimeout(() => f(now), 16),
    performance: { now: () => now } });
  sb.globalThis = sb;
  sb.window = Object.assign({}, dom.window, sb);
  const ctx = vm.createContext(sb);
  for (const sc of scripts) { try { sc.runInContext(ctx); } catch (e) { console.log("load", e.message); } }
  const run = (code) => vm.runInContext(code, ctx);
  const flush = () => {
    for (let guard = 0; timers.length && guard < 20000; guard++) {
      timers.sort((a, b) => a.at - b.at || a.n - b.n);
      const t = timers.shift();
      now = Math.max(now, t.at);
      try { t.fn(); } catch (e) { console.log("timer", e.message); }
    }
  };
  return { run, flush, ctx };
}

/* Buttons in the live screen. */
const buttons = (P) => P.run(`(() => { const out = []; const walk = (n) => { for (const c of n.children || []) {
  if (c.tagName === "BUTTON") out.push(c); walk(c); } }; walk(document.getElementById("app")); return out; })()`);
const label = (b) => (b._text || "") + (b.children || []).map((c) => label(c)).join(" ");
const find = (P, re) => buttons(P).find((b) => re.test(label(b)) && !b.disabled);

function snap(P) {
  return P.run(`(() => { const r = Cb.run, sc = document.getElementById("app").dataset.screen;
    let s = sc + " " + r.act + "-" + r.round + " g" + r.essence + " deck" + r.cards.length + " ch" + r.charms.map((c) => c.id) +
      " lv" + JSON.stringify(r.levels);
    if ((sc === "crib" || sc === "pegging") && Cb.round) { const rd = Cb.round;
      s += " sc" + rd.score + " dl" + rd.dealsLeft + " st" + rd.stock.length + " ph" + rd.phase + " ml" + rd.mulligansLeft +
        " dealt" + (rd.dealt || []).map((c) => c.rank + c.suit).join(",") + " keep" + Cb.keep.join(","); }
    if (sc === "pegging") { const p = Cb.peg; s += " peg" + p.score + "/" + p.oppScore + " tot" + p.total + " mine" + p.mine.length +
      " pile" + p.pile.map((c) => c.rank + c.suit).join(","); }
    return s; })()`);
}

const killedOn = {};
let kills = 0, totalSaves = 0;

/* One run by the bot. killEvery = 0: never kill. */
function play(seed, killEvery) {
  // a clean profile with The Play and the cut ceremony earned
  let P = page(seed);
  P.run(`localStorage.removeItem(RunSave.KEY); Achv.save({ __v: 3 }); Achv.grantSystem("the_play"); Achv.grantSystem("crib_cut");`);
  P.run(`Cb.run = new CribRun(${JSON.stringify(["thump", "pip", "clover"][seed % 3])}, STREETS[0], null, ${seed}); cribRoundIntro();`);
  const log = [];
  let seenSaves = P.run("RunSave.saves || 0"), since = 0, killNow = false;
  const mulled = {}, bought = {}, shopKilled = {};
  let lastLen = 0, stall = 0, end = "";
  for (let guard = 0; guard < 6000; guard++) {
    // ---- the kill: a new page from the same storage, via the title's CONTINUE
    const saves = P.run("RunSave.saves || 0");
    if (killEvery > 0 && (saves > seenSaves || killNow)) {
      since += saves - seenSaves; seenSaves = saves;
      const sc = P.run(`document.getElementById("app").dataset.screen`);
      const ri = P.run("Cb.run.roundIndex()");
      // also once on every shop and intro visit (the cadence alone can miss them)
      const shopKill = (sc === "cribShop" || sc === "cribIntro") && !shopKilled[sc + ri];
      if (shopKill) shopKilled[sc + ri] = true;
      if ((since >= killEvery || shopKill || killNow) && P.run("RunSave.has()")) {
        const where = JSON.parse(P.run(`localStorage.getItem(RunSave.KEY)`)).s.v.screen;
        const beat = where === "peg" && P.run("!Cb.peg.over && Cb.peg.turn === 'them'") ? "/beat" : "";
        killedOn[where + beat] = (killedOn[where + beat] || 0) + 1;
        killNow = false; since = 0;
        P = page(seed * 7 + kills);            // the new page's presentation randomness differs, on purpose
        P.run("showTitle()");
        const cont = find(P, /^CONTINUE/);
        ok(!!cont, "no CONTINUE on the title with a save");
        if (!cont) break;
        cont.onclick();
        seenSaves = P.run("RunSave.saves || 0");
        kills++;
        continue;
      }
    }
    P.flush();
    const sc = P.run(`document.getElementById("app").dataset.screen`);
    if (sc === "cribIntro") {
      log.push(snap(P));
      find(P, /^DEAL$/).onclick();
    } else if (sc === "crib") {
      const need = P.run("Cb.round.keepCount()");
      const have = P.run("Cb.keep.length");
      if (have === 0) {
        log.push(snap(P));
        const key = P.run(`Cb.run.act + "-" + Cb.run.round + "-" + Cb.round.dealIndex`);
        const ev = P.run("Cb.round.bestKeepEV().ev");
        const mb = find(P, /^MULLIGAN/);
        if (ev < 6 && mb && !mulled[key]) { mulled[key] = true; mb.onclick(); continue; }
      }
      if (have < need) {
        // pick one card at a time through the real toggle (a kill can land mid-pick)
        const next = P.run(`Cb.round.bestKeepEV().idx.find((i) => !Cb.keep.includes(i))`);
        P.run(`cribToggle(${next})`);
        continue;
      }
      log.push(snap(P));
      find(P, /^COUNT IT/).onclick();
    } else if (sc === "pegging") {
      log.push(snap(P));
      if (P.run("Cb.peg.over")) find(P, /^CONTINUE/).onclick();
      else {
        const lay = P.run(`(() => { const out = []; const walk = (n) => { for (const c of n.children || []) {
          if (c.classList && c.classList.contains("pegplayable")) out.push(c); walk(c); } };
          walk(document.getElementById("app")); return out; })()`);
        if (!lay.length) { ok(false, `seed ${seed}: The Play waits on nothing to lay: ${snap(P)}`); break; }
        lay[0].onclick();
      }
    } else if (sc === "cribEnd") {
      // a won round's end is saved as "go to the shop": a resume lands in the
      // shop, so only a lost end is a decision both runs see
      const shop = find(P, /^SHOP$/);
      if (!shop) { log.push(snap(P)); break; }
      shop.onclick();
    } else if (sc === "cribShop") {
      const ri = P.run("Cb.run.roundIndex()");
      if (!bought[ri]) {
        bought[ri] = true;
        log.push(snap(P));
        const items = buttons(P).filter((b) => b.classList.contains("shopitem") && !b.disabled);
        const lv = buttons(P).filter((b) => b.classList.contains("lvbtn") && !b.disabled);
        const pick = items[0] || lv[0];
        if (pick) { pick.onclick(); if (killEvery > 0) { killNow = true; continue; } }
      }
      find(P, /^NEXT ROUND/).onclick();
    } else if (sc === "cascade" || sc === "cut") {
      const c = find(P, /^CONTINUE/);      // the count shows its total, then waits for a tap
      if (c) c.onclick();
      else if (++stall > 50) { ok(false, `seed ${seed}: ${sc} never offered CONTINUE`); break; }
      continue;
    } else if (sc === "cribWon") {
      log.push(snap(P)); break;
    } else { log.push("screen " + sc); break; }
    if (log.length === lastLen) { if (++stall > 400) { ok(false, `seed ${seed}: stuck on ${snap(P)}`); break; } }
    else { stall = 0; lastLen = log.length; }
    if (P.run("Cb.run.roundIndex()") > 8) { log.push("stop " + snap(P)); break; }
  }
  P.flush();
  end = snap(P);
  totalSaves += P.run("RunSave.saves || 0");
  return [log, end, P];
}

const seeds = [4401, 4402, 4403, 4404, 4405, 4406];
let pairs = 0;
for (const seed of seeds) {
  const [a, aEnd] = play(seed, 0);
  ok(a.length > 30, `seed ${seed}: the straight run made only ${a.length} decisions`);
  for (const k of [2, 5]) {
    const [b, bEnd] = play(seed, k);
    let first = -1;
    for (let i = 0; i < Math.min(a.length, b.length); i++) if (a[i] !== b[i]) { first = i; break; }
    ok(first === -1 && a.length === b.length,
      `seed ${seed} kill every ${k}: decisions differ at ${first} (${a.length} vs ${b.length})\n   straight: ${a[first]}\n   resumed:  ${b[first]}`);
    ok(aEnd === bEnd, `seed ${seed} kill every ${k}: ended\n   ${aEnd}\n   ${bEnd}`);
    pairs++;
  }
}

/* A lost run and a won run leave no save behind (no CONTINUE into a dead run). */
{
  const P = page(9);
  P.run(`Achv.save({ __v: 3 }); Cb.run = new CribRun("pip", STREETS[0], null, 9); cribRoundIntro();`);
  ok(P.run("RunSave.has()"), "the intro saved");
  P.run(`Cb.round = new CribRound(Cb.run); Cb.round.over = true; Cb.round.won = false; Cb.round.settled = true;
         Cb.round.cribResult = { total: 0, events: [] }; Cb.round.settle = () => {}; cribRoundEnd();`);
  ok(!P.run("RunSave.has()"), "a lost run left its save behind");
  P.run(`Cb.run = new CribRun("pip", STREETS[0], null, 9); cribRoundIntro();`);
  P.run(`screen("cribWon"); cribRunWon();`);
  ok(!P.run("RunSave.has()"), "a won run left its save behind");
  P.run("showTitle()");
  ok(!find(P, /^CONTINUE/) && !!find(P, /^PLAY/), "the title offers CONTINUE without a save");
}

console.log(`save: ${pairs} run pairs, ${kills} kills, ${totalSaves} saves, killed on ${JSON.stringify(killedOn)}`);
const good = fails === 0 && kills >= 60 && ["intro", "crib", "counted", "peg", "peg/beat", "roundwon", "shop"].every((k) => killedOn[k] > 0);
console.log(`save checks: ${checks}, failures: ${fails}`);
console.log(good ? "SAVE OK" : "SAVE FAILED");
process.exit(good ? 0 : 1);
