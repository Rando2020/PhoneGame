/* Meldlings — web UI. Rules come from rules.js (identical logic to the Godot build). */

const $ = (sel, root = document) => root.querySelector(sel);

/* Tooltips. `title` is desktop-only, so named effects need something tappable.
   Attach with tip(node, "Name", "What it does"). */
let _tipEl = null;
function hideTip() { if (_tipEl) { _tipEl.remove(); _tipEl = null; } }
function tip(node, title, body) {
  if (!node) return node;
  node.classList.add("hastip");
  const show = (ev) => {
    ev.stopPropagation();
    hideTip();
    const t = document.createElement("div");
    t.className = "tipbox";
    t.innerHTML = `<div class="tiptitle"></div><div class="tipbody"></div>`;
    t.querySelector(".tiptitle").textContent = title;
    t.querySelector(".tipbody").textContent = body || "";
    document.body.appendChild(t);
    const r = node.getBoundingClientRect();
    const w = Math.min(260, window.innerWidth - 24);
    t.style.width = w + "px";
    let left = r.left + r.width / 2 - w / 2;
    left = Math.max(12, Math.min(window.innerWidth - w - 12, left));
    t.style.left = left + "px";
    const above = r.top > 150;
    t.style.top = (above ? r.top - t.offsetHeight - 10 : r.bottom + 10) + "px";
    _tipEl = t;
  };
  node.addEventListener("click", show);
  node.addEventListener("mouseenter", show);
  node.addEventListener("mouseleave", hideTip);
  return node;
}
document.addEventListener("click", hideTip);
const el = (tag, cls, txt) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (txt !== undefined) n.textContent = txt;
  return n;
};

// ---------------------------------------------------------------- audio
let AC = null;
const ac = () => (AC ||= new (window.AudioContext || window.webkitAudioContext)());
function tone(freq, dur = 0.08, type = "square", gain = 0.06, delay = 0) {
  try {
    const c = ac(), o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.value = freq;
    g.gain.setValueAtTime(0, c.currentTime + delay);
    g.gain.linearRampToValueAtTime(gain, c.currentTime + delay + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + delay + dur);
    o.connect(g); g.connect(c.destination);
    o.start(c.currentTime + delay); o.stop(c.currentTime + delay + dur + 0.02);
  } catch (e) {}
}
const SFX = {
  click: () => tone(660, 0.05),
  select: () => tone(880, 0.05),
  deselect: () => tone(560, 0.05),
  bad: () => { tone(300, 0.07); tone(282, 0.1, "square", 0.06, 0.07); },
  draw: () => tone(500, 0.06, "triangle", 0.04),
  place: () => tone(220, 0.08, "triangle", 0.06),
  BRACE: () => [294, 440, 587].forEach((f, i) => tone(f, 0.3, "triangle", 0.05, i * 0.02)),
  PREP: () => [392, 494, 587].forEach((f, i) => tone(f, 0.12, "square", 0.05, i * 0.05)),
  STRIKE: () => { tone(1200, 0.1, "square", 0.07); tone(300, 0.16, "sawtooth", 0.06, 0.06); },
  RALLY: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.13, "square", 0.055, i * 0.055)),
  "GRAND MELD": () => [523, 659, 784, 1047, 1319, 1568]
    .forEach((f, i) => tone(f, 0.2, "square", 0.06, i * 0.05)),
  hit: () => tone(160, 0.14, "sawtooth", 0.07),
  win: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.35, "square", 0.06, i * 0.1)),
  lose: () => [440, 349, 294].forEach((f, i) => tone(f, 0.4, "triangle", 0.06, i * 0.16)),
};
const sfx = (k) => SFX[k] && SFX[k]();

// ---------------------------------------------------------------- sprites
const SPLIT_RANKS = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"];
const SPLIT_SUITS = ["S","H","C","D"];

/* Built from four shared images at runtime, so any of 2704 combinations renders
   without a dedicated asset. */
function splitCardEl(card, scale = 2) {
  const n = el("div", "card splitcard");
  n.style.width = 70 * scale + "px";
  n.style.height = 98 * scale + "px";
  if (ART.split) n.style.backgroundImage = `url(${ART.split.frame})`;

  const put = (rank, suit, x, y, big) => {
    const gi = SPLIT_RANKS.indexOf(CRANK_LABEL[rank]);
    if (gi < 0) return;
    const red = suit === "H" || suit === "D" ? 1 : 0;
    const gw = big ? 22 : 11, gh = big ? 14 : 7;
    const g = el("div", "sg");
    g.style.width = gw * scale + "px";
    g.style.height = gh * scale + "px";
    g.style.left = x * scale + "px";
    g.style.top = y * scale + "px";
    if (ART.split) g.style.backgroundImage = `url(${big ? ART.split.glyphsBig : ART.split.glyphs})`;
    g.style.backgroundSize = `${gw * 13 * scale}px ${gh * 2 * scale}px`;
    g.style.backgroundPosition = `${-gi * gw * scale}px ${-red * gh * scale}px`;
    n.appendChild(g);
    if (!big) {
      const p = el("div", "sg");
      const si = SPLIT_SUITS.indexOf(suit);
      p.style.width = 7 * scale + "px";
      p.style.height = 7 * scale + "px";
      p.style.left = (x + 2) * scale + "px";
      p.style.top = (y + 8) * scale + "px";
      if (ART.split) p.style.backgroundImage = `url(${ART.split.pips})`;
      p.style.backgroundSize = `${7 * 4 * scale}px ${7 * 2 * scale}px`;
      p.style.backgroundPosition = `${-si * 7 * scale}px ${-red * 7 * scale}px`;
      n.appendChild(p);
    }
  };
  put(card.rank, card.suit, 5, 7, false);
  put(card.rank2, card.suit2 || card.suit, 70 - 16, 98 - 22, false);
  put(card.rank, card.suit, 6, 34, true);
  put(card.rank2, card.suit2 || card.suit, 70 - 28, 52, true);
  n.title = `${CRANK_LABEL[card.rank]} or ${CRANK_LABEL[card.rank2]} — counts as whichever scores better`;
  return n;
}

function cardEl(card, scale = 2) {
  if (card && card.rank2 !== undefined) return splitCardEl(card, scale);
  const n = el("div", "card");
  if (card && card.enh) {
    n.classList.add("enh", "enh-" + card.enh);
    const meta = (typeof ENHANCEMENTS !== "undefined") && ENHANCEMENTS[card.enh];
    if (ART.marks && ART.marks[card.enh]) {
      const ov = el("div", "markov");
      ov.style.backgroundImage = `url(${ART.marks[card.enh]})`;
      n.appendChild(ov);
    }
    n.title = meta ? `${meta.name} — ${meta.text}` : "";
  }
  const col = card.rank - 1;
  const row = SUITS.indexOf(card.suit);
  const w = 70 * scale, h = 98 * scale;
  n.style.width = w + "px";
  n.style.height = h + "px";
  n.style.backgroundImage = `url(${ART.atlas})`;
  n.style.backgroundSize = `${13 * w}px ${4 * h}px`;
  n.style.backgroundPosition = `-${col * w}px -${row * h}px`;
  return n;
}

function backEl(scale = 2) {
  const n = el("div", "card");
  n.style.width = 70 * scale + "px";
  n.style.height = 98 * scale + "px";
  const skin = (typeof Achv !== "undefined") ? Achv.activeBack() : "indigo";
  const src = (ART.backs && ART.backs[skin]) || ART.back;
  n.style.backgroundImage = `url(${src})`;
  n.style.backgroundSize = "100% 100%";
  return n;
}

function creatureEl(id, anim = "idle", scale = 3) {
  const s = SPRITES[id][anim];
  const n = el("div", "creature");
  n.dataset.id = id;
  const size = s.h * scale;
  n.style.width = size + "px";
  n.style.height = size + "px";
  n.style.backgroundImage = `url(${s.url})`;
  n.style.backgroundSize = `${s.frames * size}px ${size}px`;
  n.style.setProperty("--frames", s.frames);
  n.style.setProperty("--span", `-${s.frames * size}px`);
  n.style.animation = `sprite ${anim === "idle" ? 0.9 : 0.4}s steps(${s.frames}) ${anim === "idle" ? "infinite" : "1"}`;
  return n;
}

function playAnim(node, id, anim, scale = 3) {
  const s = SPRITES[id][anim];
  const size = s.h * scale;
  node.style.backgroundImage = `url(${s.url})`;
  node.style.backgroundSize = `${s.frames * size}px ${size}px`;
  node.style.setProperty("--span", `-${s.frames * size}px`);
  node.style.animation = "none";
  void node.offsetWidth;
  node.style.animation = `sprite 0.42s steps(${s.frames}) 1`;
  if (anim !== "idle") {
    setTimeout(() => {
      const idle = SPRITES[id].idle;
      const isz = idle.h * scale;
      node.style.backgroundImage = `url(${idle.url})`;
      node.style.backgroundSize = `${idle.frames * isz}px ${isz}px`;
      node.style.setProperty("--span", `-${idle.frames * isz}px`);
      node.style.animation = `sprite 0.9s steps(${idle.frames}) infinite`;
    }, 440);
  }
}

// ---------------------------------------------------------------- app state
const App = {
  run: null, combat: null, node: 0, mode: "gauntlet",
  selected: [], busy: false, sandbox: false, meldling: "pip",
};
const root = () => $("#app");

function screen(name) {
  root().innerHTML = "";
  root().dataset.screen = name;
}

// ---------------------------------------------------------------- title
function showTitle() {
  screen("title");
  const c = el("div", "col center");
  c.append(el("h1", "title", "MELDLINGS"));
  c.append(el("p", "dim", "Count it. Cut it. Break it."));

  const parade = el("div", "row center gap");
  for (const id of Object.keys(ROSTER).filter((k) => ROSTER[k].kind === "meldling"))
    parade.append(creatureEl(id, "idle", 2));
  c.append(parade);

  c.append(btn("PLAY", () => { sfx("RALLY"); showCribSelect(); }, "big"));
  c.append(el("p", "dim small",
    "A cribbage roguelite. Charms, Marks, and Spoilers on the road."));
  root().append(c);
}

function showSelect() {
  screen("select");
  const c = el("div", "col");
  c.append(el("h2", "title", "CHOOSE YOUR MELDLING"));
  const row = el("div", "row center gap wrap");
  const info = el("div", "panel col");
  const nameL = el("h3", "gold", "");
  const blurb = el("p", "dim", "");
  info.append(nameL, blurb);

  const ids = Object.keys(ROSTER).filter((k) => ROSTER[k].kind === "meldling");
  const pick = (id) => {
    App.meldling = id;
    sfx("select");
    [...row.children].forEach((n) => n.classList.toggle("chosen", n.dataset.id === id));
    nameL.textContent = `${ROSTER[id].name} — ${ROSTER[id].hp} HP`;
    blurb.textContent = ROSTER[id].blurb;
  };
  for (const id of ids) {
    const slot = el("div", "slot");
    slot.dataset.id = id;
    slot.append(creatureEl(id, "idle", 3));
    slot.onclick = () => pick(id);
    row.append(slot);
  }
  c.append(row, info);
  c.append(btn(App.mode === "training" ? "ENTER TRAINING" : "START", () => {
    App.run = new Run(App.meldling);
    App.node = 0;
    sfx("RALLY");
    if (App.mode === "training") startBattle("deadwood", true);
    else if (App.mode === "gin") startGin("deadwood");
    else showTrack();
  }, "big"));
  c.append(btn("Back", showTitle, "small"));
  root().append(c);
  pick(ids[0]);
}

// ---------------------------------------------------------------- gauntlet track
function showTrack() {
  screen("track");
  const c = el("div", "col");
  c.append(el("h2", "title", "THE GAUNTLET"));
  c.append(el("p", "dim",
    `${ROSTER[App.run.meldling].name} — ${App.run.hp}/${App.run.maxHp} HP` +
    (App.run.relics.length ? ` · ${App.run.relics.map((r) => r.name).join(", ")}` : "")));

  const track = el("div", "track");
  GAUNTLET.forEach((n, i) => {
    const node = el("div", "tnode " + (i < App.node ? "done" : i === App.node ? "now" : ""));
    node.textContent = { battle: "⚔", cache: "◆", rest: "✚", elite: "☠", boss: "♛" }[n.type];
    node.title = n.enemy ? ROSTER[n.enemy].name : n.type;
    track.append(node);
  });
  c.append(track);

  const entry = GAUNTLET[App.node];
  const label = { battle: "Battle", cache: "Cache", rest: "Rest", elite: "Elite", boss: "BOSS" }[entry.type];
  c.append(el("p", "gold", `Next: ${label}${entry.enemy ? " — " + ROSTER[entry.enemy].name : ""}`));
  c.append(btn("ADVANCE", () => {
    sfx("place");
    if (entry.type === "cache") showReward(true);
    else if (entry.type === "rest") showRest();
    else if (App.mode === "gin") startGin(entry.enemy);
    else startBattle(entry.enemy);
  }, "big"));
  c.append(btn("Abandon", showTitle, "small"));
  root().append(c);
}

// ---------------------------------------------------------------- battle
function startBattle(enemyId, sandbox = false) {
  App.sandbox = sandbox;
  App.combat = new Combat(App.run, enemyId);
  App.selected = [];
  App.busy = false;
  renderBattle();
}

function renderBattle() {
  const C = App.combat;
  screen("battle");
  const c = el("div", "col tight");

  // enemy
  const ep = el("div", "panel col tight");
  ep.append(rowLR(C.enemy.name, `${C.enemy.hp} / ${C.enemy.maxHp}`, "red"));
  ep.append(bar(C.enemy.hp / C.enemy.maxHp, "red"));
  ep.append(el("p", "small blue", C.enemy.statusLine()));
  ep.append(el("p", "small gold", C.intentText()));
  c.append(ep);

  // arena
  const arena = el("div", "row center gap arena");
  const hero = creatureEl(C.player.id, "idle", 3);
  hero.id = "hero";
  const foe = creatureEl(C.enemy.id, "idle", 3);
  foe.id = "foe";
  foe.style.transform = "scaleX(-1)";
  arena.append(hero, el("div", "verdict", ""), foe);
  c.append(arena);

  // player
  const pp = el("div", "panel col tight");
  pp.append(rowLR(ROSTER[C.player.id].name,
    `${C.player.hp} / ${C.player.maxHp}`, "green"));
  pp.append(bar(C.player.hp / C.player.maxHp, "green"));
  pp.append(el("p", "small blue", C.player.statusLine()));
  pp.append(el("p", "small gold",
    `FOCUS ${C.focus}/${C.maxFocus} · TURN ${C.turn} · DECK ${C.deck.length}`));
  c.append(pp);

  c.append(el("p", "banner", "Tap cards to build a meld"));

  // hand
  const hand = el("div", "hand");
  C.hand.forEach((card, i) => {
    const n = cardEl(card, 2);
    n.dataset.i = i;
    if (App.selected.includes(i)) n.classList.add("sel");
    else if (App.selected.length &&
      !canJoin(App.selected.map((j) => C.hand[j]), card)) n.classList.add("dim");
    n.onclick = () => toggleCard(i);
    hand.append(n);
  });
  c.append(hand);

  // buttons
  const b1 = el("div", "row gap");
  b1.append(btn("Sort", () => { C.hand.sort((a, b) => a.rank - b.rank || SUITS.indexOf(a.suit) - SUITS.indexOf(b.suit)); App.selected = []; sfx("click"); renderBattle(); }, "small"));
  b1.append(btn("Suit", () => { C.hand.sort((a, b) => SUITS.indexOf(a.suit) - SUITS.indexOf(b.suit) || a.rank - b.rank); App.selected = []; sfx("click"); renderBattle(); }, "small"));
  b1.append(btn("Hint", doHint, "small"));
  c.append(b1);

  const b2 = el("div", "row gap");
  const playB = btn("PLAY MELD", doPlay);
  playB.id = "playBtn";
  b2.append(playB, btn("Cycle", doCycle, "small"), btn("End Turn", doEndTurn, "small"));
  c.append(b2);

  if (App.sandbox) c.append(sandboxDrawer());
  root().append(c);
  updateVerdict();
}

function rowLR(l, r, cls) {
  const n = el("div", "row between");
  n.append(el("span", "", l), el("span", cls || "", r));
  return n;
}
function bar(frac, cls) {
  const outer = el("div", "bar");
  const inner = el("div", "fill " + cls);
  inner.style.width = Math.max(0, Math.min(100, frac * 100)) + "%";
  outer.append(inner);
  return outer;
}

function toggleCard(i) {
  const C = App.combat;
  if (App.busy) return;
  const at = App.selected.indexOf(i);
  if (at >= 0) { App.selected.splice(at, 1); sfx("deselect"); }
  else {
    const sel = App.selected.map((j) => C.hand[j]);
    if (sel.length && !canJoin(sel, C.hand[i])) {
      sfx("bad");
      const n = $(`.hand [data-i="${i}"]`);
      if (n) { n.classList.add("shake"); setTimeout(() => n.classList.remove("shake"), 300); }
      return;
    }
    App.selected.push(i);
    sfx("select");
  }
  refreshHandClasses();
  updateVerdict();
}

function refreshHandClasses() {
  const C = App.combat;
  const sel = App.selected.map((j) => C.hand[j]);
  document.querySelectorAll(".hand .card").forEach((n) => {
    const i = +n.dataset.i;
    n.classList.toggle("sel", App.selected.includes(i));
    n.classList.toggle("dim", !!sel.length && !App.selected.includes(i) && !canJoin(sel, C.hand[i]));
  });
}

function updateVerdict() {
  const C = App.combat;
  const sel = App.selected.map((i) => C.hand[i]);
  const v = classify(sel);
  const banner = $(".banner"), verdict = $(".verdict"), playB = $("#playBtn");
  if (!sel.length) {
    banner.textContent = "Tap cards to build a meld";
    verdict.textContent = "";
  } else if (v.valid) {
    banner.textContent = C.preview(sel);
    verdict.textContent = v.action;
  } else {
    banner.textContent = `${sel.length} selected · ${v.label}`;
    verdict.textContent = "—";
  }
  if (playB) playB.disabled = !v.valid || C.focus <= 0 || App.busy;
}

function doHint() {
  const C = App.combat;
  const ms = findMelds(C.hand);
  if (!ms.length) { sfx("bad"); $(".banner").textContent = "No meld — Cycle to draw."; return; }
  App.selected = ms[0].slice();
  sfx("PREP");
  refreshHandClasses();
  updateVerdict();
}

function doPlay() {
  const C = App.combat;
  const sel = App.selected.map((i) => C.hand[i]);
  const v = classify(sel);
  if (!v.valid || C.focus <= 0 || App.busy) return;
  App.busy = true;
  const cards = C.takeFromHand(App.selected);
  const out = C.playMeld(cards);
  App.selected = [];
  sfx(out.action);
  const hero = $("#hero"), foe = $("#foe");
  if (hero) playAnim(hero, C.player.id, "attack");
  if (out.offensive && foe) setTimeout(() => { playAnim(foe, C.enemy.id, "hurt"); sfx("hit"); }, 220);
  setTimeout(() => {
    App.busy = false;
    if (C.over) return endBattle();
    renderBattle();
    $(".banner").textContent = out.text;
  }, 620);
}

function doCycle() {
  const C = App.combat;
  if (App.busy || C.focus <= 0) return;
  if (App.selected.length !== 1) { sfx("bad"); $(".banner").textContent = "Select one card to cycle."; return; }
  C.discardCard(App.selected[0]);
  C.cycle();
  App.selected = [];
  sfx("place");
  renderBattle();
}

function doEndTurn() {
  const C = App.combat;
  if (App.busy) return;
  App.busy = true;
  App.selected = [];
  const ev = C.endTurn();
  const foe = $("#foe"), hero = $("#hero");
  let msg = "";
  for (const e of ev) {
    if (e.t === "hit") { if (foe) playAnim(foe, C.enemy.id, "attack"); setTimeout(() => hero && playAnim(hero, C.player.id, "hurt"), 200); sfx("hit"); msg = `${C.enemy.name} hits you for ${e.n}.`; }
    else if (e.t === "block") msg = `${C.enemy.name} braces for ${e.n}.`;
    else if (e.t === "burn") msg = `Burn deals ${e.n}.`;
    else if (e.t === "hex") msg = `You are Hexed (${e.n}).`;
  }
  setTimeout(() => {
    App.busy = false;
    if (C.over) return endBattle();
    renderBattle();
    $(".banner").textContent = msg || "Your turn — Focus restored.";
  }, 700);
}

function endBattle() {
  const C = App.combat;
  App.run.hp = C.player.hp;
  sfx(C.victory ? "win" : "lose");
  if (App.sandbox) { setTimeout(() => startBattle(C.enemy.id, true), 900); return; }
  setTimeout(() => {
    if (!C.victory) { App.run.lastResult = "defeat"; return showEnd(); }
    App.run.essence += GAUNTLET[App.node].type === "boss" ? 40 : 15;
    App.run.heal(App.run.relicValue("heal_after"));
    App.node++;
    if (App.node >= GAUNTLET.length) { App.run.lastResult = "victory"; return showEnd(); }
    showReward(false);
  }, 900);
}

// ---------------------------------------------------------------- reward / rest / end
function showReward(isCache) {
  screen("reward");
  const c = el("div", "col");
  c.append(el("h2", "title", isCache ? "CACHE FOUND" : "VICTORY"));
  c.append(el("p", "dim", `${App.run.hp}/${App.run.maxHp} HP · ${App.run.essence} Essence`));
  const offers = App.run.offerRelics(3);
  if (!offers.length) c.append(el("p", "dim", "Nothing left to find."));
  for (const r of offers) {
    const b = el("button", "relic");
    b.append(el("div", "gold", r.name), el("div", "small dim", r.text));
    b.onclick = () => { App.run.relics.push(r); sfx("RALLY"); if (isCache) App.node++; showTrack(); };
    c.append(b);
  }
  c.append(btn("Skip", () => { if (isCache) App.node++; showTrack(); }, "small"));
  root().append(c);
}

function showRest() {
  screen("rest");
  const c = el("div", "col center");
  c.append(el("h2", "title", "A QUIET SHUFFLE"));
  c.append(creatureEl(App.run.meldling, "idle", 4));
  c.append(el("p", "dim", `${App.run.hp}/${App.run.maxHp} HP`));
  const heal = Math.max(8, Math.round(App.run.maxHp * 0.32));
  c.append(btn(`Rest — heal ${heal}`, () => { App.run.heal(heal); sfx("win"); App.node++; showTrack(); }, "big"));
  c.append(btn("Train — +6 max HP", () => { App.run.maxHp += 6; App.run.heal(6); sfx("GRAND MELD"); App.node++; showTrack(); }));
  root().append(c);
}

function showEnd() {
  screen("end");
  const win = App.run.lastResult === "victory";
  const c = el("div", "col center");
  c.append(el("h2", "title", win ? "GAUNTLET CLEARED" : "RUN ENDED"));
  c.append(creatureEl(win ? App.run.meldling : "kingpin", "idle", 4));
  c.append(el("p", "dim",
    `Reached node ${App.node + 1}/${GAUNTLET.length} · ${App.run.relics.length} relics · ${App.run.essence} Essence`));
  c.append(btn("Play Again", showTitle, "big"));
  root().append(c);
}

// ---------------------------------------------------------------- sandbox
function sandboxDrawer() {
  const C = App.combat;
  const d = el("details", "drawer");
  d.open = false;
  d.append(el("summary", "", "⚙ TRAINING"));
  const body = el("div", "col tight");

  const give = (cards) => { for (const [r, s] of cards) C.hand.push({ rank: r, suit: s }); sfx("draw"); renderBattle(); };
  const g1 = el("div", "row gap wrap");
  [["Pair", [[7, "H"], [7, "S"]]],
   ["2-Run", [[5, "D"], [6, "D"]]],
   ["3-Run", [[4, "H"], [5, "H"], [6, "H"]]],
   ["5-Run", [[3, "C"], [4, "C"], [5, "C"], [6, "C"], [7, "C"]]],
   ["3-Set", [[9, "H"], [9, "S"], [9, "C"]]],
   ["GRAND", [[12, "S"], [12, "H"], [12, "C"], [12, "D"]]]]
    .forEach(([label, cards]) => g1.append(btn(label, () => give(cards), "small")));
  body.append(el("p", "gold small", "Deal me a meld"), g1);

  const g2 = el("div", "row gap wrap");
  g2.append(btn("+3 Focus", () => { C.focus += 3; renderBattle(); }, "small"));
  g2.append(btn("Draw 3", () => { C.drawToHand(3); renderBattle(); }, "small"));
  g2.append(btn("Foe 1hp", () => { C.enemy.hp = 1; renderBattle(); }, "small"));
  g2.append(btn("Foe full", () => { C.enemy.hp = C.enemy.maxHp; renderBattle(); }, "small"));
  g2.append(btn("+20 HP", () => { C.player.hp = Math.min(C.player.maxHp, C.player.hp + 20); renderBattle(); }, "small"));
  body.append(el("p", "gold small", "Resources"), g2);

  const g3 = el("div", "row gap wrap");
  for (const id of Object.keys(ROSTER).filter((k) => ROSTER[k].kind !== "meldling"))
    g3.append(btn(ROSTER[id].name, () => startBattle(id, true), "small"));
  body.append(el("p", "gold small", "Opponent"), g3);

  const g4 = el("div", "row gap wrap");
  for (const r of RELICS)
    g4.append(btn(r.name, () => { if (!App.run.hasRelic(r.id)) App.run.relics.push(r); sfx("RALLY"); renderBattle(); }, "small"));
  body.append(el("p", "gold small", "Relics"), g4);

  const g5 = el("div", "row gap wrap");
  for (const [k, lo, hi] of [["handSize", 6, 16], ["focus", 1, 5]]) {
    const wrap = el("label", "small dim", `${k} `);
    const inp = el("input");
    inp.type = "number"; inp.value = TUNING[k]; inp.min = lo; inp.max = hi;
    inp.onchange = () => { TUNING[k] = +inp.value; };
    wrap.append(inp);
    g5.append(wrap);
  }
  const wrap2 = el("label", "small dim", "enemyDmg ");
  const inp2 = el("input");
  inp2.type = "number"; inp2.step = "0.05"; inp2.value = TUNING.enemyDmg;
  inp2.onchange = () => { TUNING.enemyDmg = +inp2.value; };
  wrap2.append(inp2);
  g5.append(wrap2);
  body.append(el("p", "gold small", "Live tuning (applies next battle)"), g5);

  body.append(btn("Leave Training", showTitle, "small"));
  d.append(body);
  return d;
}

// ---------------------------------------------------------------- helpers
function btn(label, fn, cls = "") {
  const b = el("button", "btn " + cls, label);
  b.onclick = fn;
  return b;
}

window.addEventListener("DOMContentLoaded", showTitle);
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && App.combat) { App.selected = []; refreshHandClasses(); updateVerdict(); }
});
