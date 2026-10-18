/* Cribbage mode UI. The count-up cascade is the whole point — every sub-score
   ticks in sequence with a running total, then the multiplier lands. */

/* Cross-run persistence — the "one more run" hook. This is a standalone local
   file, so localStorage is available and appropriate here. */
/* Meta shares the one store rather than racing Achv for the same key. */
const Meta = {
  KEY: SAVE_KEY,
  load() { return Store.read(); },
  save(o) { Store.write(o); },
  record(run, reached, score) {
    const m = this.load();
    m.runs = (m.runs || 0) + 1;
    m.bestRound = Math.max(m.bestRound || 0, reached);
    m.bestScore = Math.max(m.bestScore || 0, score || 0);
    if (reached >= CRIB_ACTS * CRIB_ROUNDS) m.clears = (m.clears || 0) + 1;
    m.decks = m.decks || {};
    m.decks[run.meldling] = Math.max(m.decks[run.meldling] || 0, reached);
    this.save(m);
    return m;
  },
  line() {
    const m = this.load();
    if (!m.runs) return "No runs yet.";
    const act = Math.ceil((m.bestRound || 1) / CRIB_ROUNDS);
    const rd = ((m.bestRound - 1) % CRIB_ROUNDS) + 1;
    return `Runs ${m.runs}  ·  Best Act ${act}-${rd}  ·  Cleared ${m.clears || 0}  ·  Best hand ${m.bestScore || 0}`;
  },
};

const Cb = { run: null, round: null, keep: [], busy: false };

const cbCard = (card, scale = 1.45) => cardEl(card, scale);

/* ---------------------------------------------------------------- select */
/* The select flow is three small steps instead of one long screen:
   road -> street -> Meldling. Each step shows one decision. */
function showCribSelect() {
  Audio16.playMusic("menu");
  Cb.step = Cb.step || "road";
  ({ road: selRoad, street: selStreet, meld: selMeld, trial: selTrial }[Cb.step] || selRoad)();
}

function selHeader(c, kicker, title) {
  c.append(el("p", "small gold selkicker", kicker));
  c.append(el("h2", "title", title));
}

function selRoad() {
  screen("selRoad");
  const c = el("div", "col center");
  selHeader(c, "STEP ONE", "CHOOSE YOUR ROAD");

  const dk = dailyKey();
  const doneToday = Achv.dailyDone(dk);
  const streak = Achv.dailyStreak();

  const ROADS = [
    { id: "daily", name: "The Daily", art: "facet",
      note: doneToday
        ? `Done — reached ${doneToday.reached}. Come back tomorrow.`
        : `Everyone gets the same deck today. One attempt.${streak ? `  Streak ${streak}.` : ""}` },
    { id: "run", name: "The Five Acts", art: "pip",
      note: "Twenty-five rounds. Five Spoilers. The road as it was meant." },
    { id: "trial", name: "Trials", art: "muggins",
      note: `One rule taken to its limit. ${TRIALS.filter((t) => Achv.trialDone(t.id)).length} of ${TRIALS.length} done.` },
    { id: "endless", name: "The Long Count", art: "nib",
      note: Achv.has("long_road")
        ? `No ceiling. Best round ${Achv.bestEndless() || 0}.`
        : "Locked — clear the Five Acts first." },
  ];
  for (const r of ROADS) {
    const open = (r.id !== "endless" || Achv.has("long_road")) &&
                 (r.id !== "daily" || !doneToday);
    const b = el("button", "roadcard" + (open ? "" : " locked"));
    b.append(creatureEl(r.art, "idle", 1.8));
    const t = el("div", "col tight grow");
    t.append(el("div", "roadname", r.name));
    t.append(el("div", "small dim", r.note));
    b.append(t);
    b.disabled = !open;
    b.onclick = () => {
      Cb.mode = r.id;
      sfx16("select");
      if (r.id === "daily") {
        // fixed deck, fixed Meldling, one attempt
        const seed = dailySeed(dk);
        const decks = ["pip", "thump", "clover", "facet"];
        Cb.run = new CribRun(decks[seed % decks.length], STREETS[0], null, seed);
        Cb.run.daily = dk;
        Cb.step = "road";
        return cribRoundIntro();
      }
      Cb.step = r.id === "trial" ? "trial" : (r.id === "endless" ? "meld" : "street");
      showCribSelect();
    };
    c.append(b);
  }
  c.append(btn("Back", showTitle, "small"));
  root().append(c);
}

function selStreet() {
  screen("selStreet");
  const c = el("div", "col center");
  selHeader(c, "STEP TWO", "HOW HARD");

  const maxStreet = Achv.streetUnlocked();
  Cb.street = Cb.street && Cb.street.id <= maxStreet ? Cb.street : STREETS[0];
  const i = STREETS.indexOf(Cb.street);

  const stepper = el("div", "row center stepper");
  const prev = btn("\u25C0", () => {
    Cb.street = STREETS[Math.max(0, i - 1)]; sfx16("click"); showCribSelect();
  }, "small");
  prev.disabled = i === 0;
  const next = btn("\u25B6", () => {
    Cb.street = STREETS[Math.min(maxStreet - 1, i + 1)]; sfx16("click"); showCribSelect();
  }, "small");
  next.disabled = i >= maxStreet - 1;
  const face = el("div", "col tight streetface");
  face.append(el("div", "streetnum", ["I","II","III","IV","V","VI","VII","VIII"][i]));
  face.append(el("div", "gold", Cb.street.name));
  face.append(el("div", "small dim", Cb.street.text));
  stepper.append(prev, face, next);
  c.append(stepper);

  const pips = el("div", "row center gap");
  STREETS.forEach((st, k) => {
    const d = el("div", "streetpip" + (k === i ? " on" : "") + (k >= maxStreet ? " locked" : ""));
    pips.append(d);
  });
  c.append(pips);
  if (maxStreet < STREETS.length)
    c.append(el("p", "tiny dim", `Clear ${STREETS[maxStreet - 1].name} to open the next.`));

  c.append(btn("CONTINUE", () => { Cb.step = "meld"; sfx16("select"); showCribSelect(); }, "big"));
  c.append(btn("Back", () => { Cb.step = "road"; showCribSelect(); }, "small"));
  root().append(c);
}

function selTrial() {
  screen("selTrial");
  const c = el("div", "col center");
  selHeader(c, "STEP TWO", "PICK A TRIAL");
  for (const t of TRIALS) {
    const done = Achv.trialDone(t.id);
    const b = el("button", "roadcard" + (done ? " done" : ""));
    b.append(creatureEl(t.deck, "idle", 1.5));
    const l = el("div", "col tight grow");
    l.append(el("div", "roadname", t.name + (done ? "  \u2714" : "")));
    l.append(el("div", "small dim", t.text));
    b.append(l);
    b.onclick = () => {
      sfx16("buy");
      Cb.run = new CribRun(t.deck, STREETS[0], t);
      Cb.step = "road";
      cribRoundIntro();
    };
    c.append(b);
  }
  c.append(btn("Back", () => { Cb.step = "road"; showCribSelect(); }, "small"));
  root().append(c);
}

/* A carousel, not a list — one Meldling at a time, large. */
function selMeld() {
  screen("selMeld");
  const c = el("div", "col center");
  selHeader(c, "STEP THREE", "YOUR MELDLING");

  const ids = Object.keys(CRIB_DECKS);
  Cb.meldIdx = ((Cb.meldIdx || 0) + ids.length) % ids.length;
  const id = ids[Cb.meldIdx];
  const d = CRIB_DECKS[id];
  const open = Achv.meldlingUnlocked(id);

  const stage = el("div", "row center meldstage");
  const prev = btn("\u25C0", () => { Cb.meldIdx--; sfx16("click"); showCribSelect(); }, "small");
  const next = btn("\u25B6", () => { Cb.meldIdx++; sfx16("click"); showCribSelect(); }, "small");
  const mid = el("div", "col center tight");
  const cre = creatureEl(id, "idle", 4);
  if (!open) cre.classList.add("silhouette");
  mid.append(cre);
  mid.append(el("div", "meldname", open ? d.name : "???"));
  mid.append(el("div", "small gold", open ? SUIT_SYM[d.suit] : ""));
  stage.append(prev, mid, next);
  c.append(stage);

  const info = el("div", "panel col tight meldinfo");
  if (open) info.append(el("div", "small", d.text));
  else if (d.ascended)
    info.append(el("div", "small dim", `Locked — clear a run with ${CRIB_DECKS[d.art].name}.`));
  else {
    const req = ACHIEVEMENTS.find((a) => a.id === MELDLING_UNLOCKS[id]);
    info.append(el("div", "small dim", req ? `Locked — ${req.name}` : "Locked."));
  }
  c.append(info);

  const dots = el("div", "row center gap");
  ids.forEach((k, n) => dots.append(el("div", "streetpip" + (n === Cb.meldIdx ? " on" : ""))));
  c.append(dots);

  const go = btn("BEGIN", () => {
    sfx16("buy");
    Cb.run = new CribRun(id, Cb.street || STREETS[0]);
    if (Cb.mode === "endless") { Cb.run.enterEndless(); Cb.run.endlessRound = 0; }
    Cb.step = "road";
    cribRoundIntro();
  }, "big");
  go.disabled = !open;
  c.append(go);
  c.append(btn("Back", () => {
    Cb.step = Cb.mode === "endless" ? "road" : "street"; showCribSelect();
  }, "small"));
  root().append(c);
}

/* The achievement list — the reason to keep going once you can clear a run. */
/* The Peddler — outside a run, paid in Pegs, which stay with your profile. */
function showPeddler() {
  Audio16.playMusic("menu");
  screen("peddler");
  const c = el("div", "col");
  c.append(el("h2", "title", "THE PEDDLER"));
  c.append(el("p", "gold", `${Achv.pegs()} Pegs`));
  c.append(el("p", "small dim",
    "Pegs are earned for how far you get, not for grinding. They stay with your profile."));

  c.append(sectionHead("CARD BACKS", "tap to equip"));
  const grid = el("div", "backgrid");
  for (const b of CARD_BACKS) {
    const owned = Achv.ownsBack(b.id);
    const active = Achv.activeBack() === b.id;
    const slot = el("div", "backslot" + (active ? " on" : "") + (owned ? "" : " locked"));
    const img = el("div", "backimg");
    if (ART.backs && ART.backs[b.id]) img.style.backgroundImage = `url(${ART.backs[b.id]})`;
    slot.append(img);
    slot.append(el("div", "small", b.name));
    slot.append(el("div", "tiny " + (owned ? "green" : "gold"),
      owned ? (active ? "EQUIPPED" : "owned") : `${b.cost} Pegs`));
    tip(slot, b.name, b.text);
    slot.onclick = () => {
      if (owned) { Achv.setBack(b.id); sfx16("select"); }
      else if (Achv.buyBack(b.id)) {
        Achv.setBack(b.id); sfx16("buy");
        Juice.burst(window.innerWidth / 2, window.innerHeight * 0.4, 18, ["gold", "white"]);
      } else { sfx16("bad"); flash("Not enough Pegs"); }
      showPeddler();
    };
    grid.append(slot);
  }
  c.append(grid);

  c.append(btn("Back", showCribSelect, "small"));
  root().append(c);
}

/* Your last ten runs, and which Meldling actually suits you. */
function showHistory() {
  Audio16.playMusic("menu");
  screen("history");
  const c = el("div", "col");
  c.append(el("h2", "title", "THE RECORD"));

  const stats = Achv.deckStats();
  const keys = Object.keys(stats);
  if (keys.length) {
    c.append(sectionHead("BY MELDLING", "average act reached"));
    const g = el("div", "col tight");
    keys.sort((a, b) => stats[b].avg - stats[a].avg).forEach((k) => {
      const d = stats[k];
      const row = el("div", "row between histrow");
      row.append(el("span", "gold", CRIB_DECKS[k] ? CRIB_DECKS[k].name : k));
      row.append(el("span", "small dim", `${d.runs} run${d.runs === 1 ? "" : "s"}`));
      row.append(el("span", "small", `avg ${d.avg}`));
      row.append(el("span", "small green", `best ${d.best}`));
      g.append(row);
    });
    c.append(g);
  }

  c.append(sectionHead("LAST TEN", ""));
  const h = Achv.history();
  if (!h.length) c.append(el("p", "small dim", "No runs recorded yet."));
  for (const r of h) {
    const row = el("div", "row between histrow" + (r.cleared ? " cleared" : ""));
    const act = Math.max(1, Math.ceil(r.reached / CRIB_ROUNDS));
    const rd = ((Math.max(1, r.reached) - 1) % CRIB_ROUNDS) + 1;
    row.append(el("span", "small", CRIB_DECKS[r.deck] ? CRIB_DECKS[r.deck].name : r.deck));
    row.append(el("span", "small dim", STREETS[r.street - 1].name));
    row.append(el("span", r.cleared ? "small gold" : "small",
      r.cleared ? "CLEARED" : `Act ${act}-${rd}`));
    c.append(row);
  }
  c.append(btn("Back", showCribSelect, "small"));
  root().append(c);
}

/* A system unlock is a bigger deal than a deed, so it gets the screen. */
function announceSystem(sys) {
  const overlay = el("div", "sysunlock");
  overlay.append(el("div", "small gold", "THE GAME CHANGES"));
  overlay.append(el("div", "sysname", sys.name));
  overlay.append(el("div", "small", sys.text));
  overlay.append(el("div", "tiny dim", "This is yours from now on, in every run."));
  document.body.append(overlay);
  Audio16.sfx("milestone");
  Audio16.duck(0.35, 0.1, 1.6);
  Juice.burst(window.innerWidth / 2, window.innerHeight * 0.4, 46, ["gold", "white", "green"]);
  Juice.shake(14, 500);
  setTimeout(() => overlay.remove(), 4200);
}

/* The Play — pegging toward 31 against the Spoiler. */
function showPegging(hand, done) {
  Audio16.playMusic("play");
  const rd = Cb.round;
  const opp = rd.stock.splice(0, 4);
  Cb.peg = new PegPlay(rd, hand, opp);
  // the play rides your multiplier, so it scales with your build instead of
  // becoming irrelevant by Act 3
  Cb.pegMult = Math.max(1, (rd.lastCount && rd.lastCount.mult) || 1);
  Cb.peg.step();
  renderPegging(done);
}

function renderPegging(done) {
  const p = Cb.peg;
  const rd = Cb.round;
  const run = Cb.run;
  const boss = run.boss();
  screen("pegging");
  const c = el("div", "col center pegscreen");

  c.append(el("p", "small gold pegkicker", "THE PLAY"));

  // --- the two sides, facing each other across the count
  const field = el("div", "row between pegfield");
  const mine = el("div", "col center tight");
  const meSprite = creatureEl(run.meldling, "idle", 1.8);
  meSprite.id = "pegMe";
  mine.append(meSprite);
  mine.append(el("div", "small gold", String(p.score)));
  field.append(mine);

  const middle = el("div", "col center tight grow");
  const tot = el("div", "pegtotal", String(p.total));
  if (p.total >= 26) tot.classList.add("near");
  if (p.total === PEG_TARGET) tot.classList.add("hit");
  middle.append(tot);
  middle.append(el("div", "tiny dim", `of ${PEG_TARGET}`));
  const bar = el("div", "pegbar");
  const fill = el("div", "pegfill");
  fill.style.width = Math.min(100, 100 * p.total / PEG_TARGET) + "%";
  bar.append(fill);
  middle.append(bar);
  field.append(middle);

  const theirs = el("div", "col center tight");
  const foeSprite = creatureEl(boss ? boss.art : "shuffler", "idle", 1.8);
  foeSprite.id = "pegFoe";
  if (boss) foeSprite.style.filter = `hue-rotate(${(boss.id.charCodeAt(0) * 37) % 360}deg)`;
  theirs.append(foeSprite);
  theirs.append(el("div", "small red", String(p.oppScore)));
  const backs = el("div", "row center pegbacks");
  for (let i = 0; i < p.theirs.length; i++) backs.append(backEl(0.34));
  theirs.append(backs);
  field.append(theirs);
  c.append(field);

  // --- the pile, newest card arriving
  const pile = el("div", "row center pegpile");
  if (!p.pile.length) pile.append(el("div", "small dim", "the pile is clear"));
  p.pile.forEach((cd, i) => {
    const n = cardEl(cd, 0.68);
    if (i === p.pile.length - 1 && Cb.pegAnim) {
      n.classList.add(Cb.pegAnim === "you" ? "pegfromyou" : "pegfromfoe");
    }
    pile.append(n);
  });
  c.append(pile);

  // --- what the last lay earned
  const last = p.lastLay;
  if (last && last.events && last.events.length) {
    const call = el("div", "pegcall " + (last.who === "you" ? "mineCall" : "foeCall"));
    call.textContent = last.events.map((e) => `${e.label} +${e.points}`).join("   ");
    c.append(call);
  } else if (last) {
    c.append(el("div", "small dim pegcall", "—"));
  }
  Cb.pegAnim = null;

  if (p.over) {
    /* The Spoiler's pegging eats into yours — otherwise it's a score you cannot
       lose to, which makes the whole exchange decorative. */
    const net = Math.max(0, p.score - Math.floor(p.oppScore / 2));
    const gain = Math.round(net * (Cb.pegMult || 1));
    const winner = p.score >= p.oppScore;
    c.append(el("h3", winner ? "green" : "red",
      winner ? `You pegged ${p.score}` : `The Spoiler pegged ${p.oppScore}`));
    const box = el("div", "panel col tight pegresult");
    box.append(rowLR("Your pegs", `+${p.score}`, "green"));
    if (p.oppScore) box.append(rowLR("Spoiler's pegs", `−${Math.floor(p.oppScore / 2)}`, "red"));
    box.append(rowLR("Net", String(net), "gold"));
    if ((Cb.pegMult || 1) > 1.01)
      box.append(rowLR("× your multiplier", `×${(Cb.pegMult || 1).toFixed(2)}`, "blue"));
    box.append(rowLR("TO YOUR SCORE", `+${gain}`, "gold"));
    c.append(box);
    c.append(btn("CONTINUE", () => {
      Cb.round.score += gain;
      Audio16.sfx(gain > 0 ? "win" : "bad");
      done();
    }, "big"));
  } else {
    const row = el("div", "row center gap peghand");
    p.mine.forEach((cd, i) => {
      const n = cardEl(cd, 0.82);
      if (!p.playable(i)) n.classList.add("unplayable");
      else {
        n.classList.add("pegplayable");
        n.onclick = () => pegLay(cd, done);
      }
      row.append(n);
    });
    c.append(row);
    const canAny = p.canPlay(p.mine);
    c.append(el("p", "small " + (canAny ? "dim" : "gold"),
      canAny ? "Lay a card. You cannot pass 31."
             : "Nothing fits — the Spoiler must play on."));
  }
  root().append(c);
}

/* One lay: animate it in, call the score, then let the Spoiler answer. */
function pegLay(card, done) {
  const p = Cb.peg;
  const gained = p.lay("you", card);
  Cb.pegAnim = "you";
  if (gained) {
    Audio16.tick(Math.min(6, gained), "pair");
    Juice.shake(3 + gained, 180);
    const me = document.getElementById("pegMe");
    if (me) playAnim(me, Cb.run.meldling, "attack", 1.8);
  } else {
    Audio16.sfx("place");
  }
  if (p.lastLay && p.lastLay.hit31) { Audio16.slam(1.2); Juice.shake(9, 280); }
  p.turn = "them";
  renderPegging(done);

  // the Spoiler answers after a beat, so the exchange reads as turns
  setTimeout(() => {
    const before = p.oppScore;
    p.step();
    if (p.oppScore > before) {
      Audio16.voice(196, 0.22, { type: "sawtooth", gain: 0.1, detune: 10 });
      const foe = document.getElementById("pegFoe");
      const boss = Cb.run.boss();
      if (foe && boss) playAnim(foe, boss.art, "attack", 1.8);
      Juice.shake(4, 160);
    }
    Cb.pegAnim = "foe";
    renderPegging(done);
  }, Speed.ms(620));
}

function showDeeds() {
  Audio16.playMusic("menu");
  screen("deeds");
  const c = el("div", "col");
  c.append(el("h2", "title", "DEEDS"));
  c.append(el("p", "small dim", `${Achv.count()} of ${ACHIEVEMENTS.length} earned`));
  for (const a of ACHIEVEMENTS) {
    const got = Achv.has(a.id);
    const row = el("div", "deedrow" + (got ? " got" : ""));
    row.append(el("div", "deedmark", got ? "✔" : "·"));
    const t = el("div", "col tight grow");
    t.append(el("div", got ? "gold" : "dim", got || !a.secret ? a.name : "???"));
    t.append(el("div", "small dim", got || !a.secret ? a.text : "A hidden deed."));
    row.append(t);
    c.append(row);
  }
  c.append(btn("Back", showCribSelect, "small"));
  root().append(c);
}

/* Steam-style deed notifications: bottom-right, queued, slide in and out. */
const DeedQueue = { items: [], busy: false };
function announceDeeds(ids) {
  for (const id of ids) {
    const a = ACHIEVEMENTS.find((x) => x.id === id);
    if (a) DeedQueue.items.push(a);
  }
  pumpDeeds();
}
function pumpDeeds() {
  if (DeedQueue.busy || !DeedQueue.items.length) return;
  DeedQueue.busy = true;
  const a = DeedQueue.items.shift();

  const t = el("div", "deedtoast");
  const icon = el("div", "deedicon", "★");
  const body = el("div", "col tight grow");
  body.append(el("div", "deedkicker", "DEED UNLOCKED"));
  body.append(el("div", "deedname", a.name));
  body.append(el("div", "small dim", a.text));
  t.append(icon, body);
  document.body.append(t);

  Audio16.voice(880, 0.09, { type: "square", gain: 0.09, send: 0.3 });
  Audio16.voice(1318, 0.16, { type: "square", gain: 0.08, delay: 0.09, send: 0.35 });
  Audio16.voice(1760, 0.3, { type: "square", gain: 0.06, delay: 0.19, send: 0.4, detune: 8 });

  setTimeout(() => t.classList.add("out"), 3400);
  setTimeout(() => {
    t.remove();
    DeedQueue.busy = false;
    pumpDeeds();
  }, 3900);
}

function cribRoundIntro() {
  const run = Cb.run, boss = run.boss(), m = run.rules();
  Audio16.playMusic(boss ? "boss" : run.endless ? "endless" : `act${Math.min(5, run.act)}`);
  setSurface(boss ? "felt_boss" : "felt_table");
  screen("cribIntro");
  const c = el("div", "col center");
  c.append(el("p", "dim", `ACT ${run.act}  ·  ROUND ${run.round} / ${CRIB_ROUNDS}`));
  if (run.isWager()) {
    c.append(el("p", "small gold", "A WAGER"));
    c.append(el("h2", "title wagertitle", "SCORE IT EXACTLY"));
    c.append(creatureEl("jokester", "idle", 4));
    const w = el("div", "panel bossbox wagerbox");
    w.append(el("div", "gold", "THE TERMS"));
    w.append(el("div", "", `Finish on exactly ${run.target()}. Not one point more.`));
    const locked = Achv.lockedSystems();
    if (locked.length)
      w.append(el("div", "small green", `Win and you keep: ${locked[0].name} — ${locked[0].text}`));
    w.append(el("div", "small dim", "Lose and the run ends. You may walk away instead."));
    c.append(w);
  } else if (boss) {
    const sevName = ["", "A SPOILER", "A GRIM SPOILER", "A RUINOUS SPOILER"][boss.sev];
    c.append(el("p", `small sev${boss.sev}`, `${sevName}  ·  ACT ${run.act} BOSS`));
    c.append(el("h2", `title sev${boss.sev}`, boss.name));
    const cr = creatureEl(boss.art, "idle", 4);
    cr.classList.add("bossart", `sev${boss.sev}`, `spoil-${boss.id}`);
    cr.style.filter =
      `drop-shadow(0 0 12px rgba(224,90,90,.5)) hue-rotate(${(boss.id.charCodeAt(0) * 37) % 360}deg) ` +
      `saturate(${1 + boss.sev * 0.35}) contrast(${1 + boss.sev * 0.12})`;
    c.append(cr);
    const w = el("div", `panel bossbox sev${boss.sev}`);
    w.append(el("div", `sev${boss.sev}`, "THE SPOILER DECREES"), el("div", "", boss.text));
    c.append(w);
    setTimeout(() => {
      Audio16.sfx("bad");
      Audio16.voice(110, 1.2, { gain: 0.14, type: "sawtooth", detune: 14, send: 0.4 });
      Audio16.voice(164.81, 1.2, { gain: 0.09, type: "sawtooth", detune: 12, delay: 0.1 });
      Audio16.kick({ gain: 0.5 });
      Juice.shake(9, 420);
      Juice.burst(window.innerWidth / 2, window.innerHeight * 0.34, 20, ["gold", "white"]);
    }, 220);
  } else {
    c.append(el("h2", "title", `TARGET ${run.target()}`));
    c.append(creatureEl(run.meldling, "idle", 4));
  }
  c.append(el("p", "gold", `Score ${run.target()} in ${CRIB_DEALS + m.dealBonus} deals`));
  c.append(cribCharmRow(run));
  c.append(cribLevelRow(run));
  c.append(el("p", "small dim", `${run.street.name}  ·  deck ${run.deckSize()}  ·  charms ${run.charms.length}/${run.slots()}`));
  const plan = el("div", "bossplan");
  run.bossPlan.forEach((b, i) => {
    const chip = el("div", "planchip sev" + b.sev + (i + 1 < run.act ? " past" : i + 1 === run.act ? " now" : ""));
    chip.textContent = `A${i + 1} ${b.name}`;
    tip(chip, `${b.name}  ·  Act ${i + 1}`,
      `${b.text}${b.align ? `  Aligned to ${SUIT_SYM[b.align]} — those cards score weakly against it, ${SUIT_SYM[SUIT_OPPOSE[b.align]]} scores strongly.` : ""}`);
    plan.append(chip);
  });
  c.append(el("p", "small gold", "SPOILERS ON THE ROAD"), plan);
  if (run.skips > 0 && !boss) {
    const sk = btn(`SKIP THIS ROUND  ·  ${run.skips} banked`, () => {
      run.skips--;
      run.essence += 8 + Math.round(run.roundIndex() * 0.6);
      sfx16("buy");
      flash("Round skipped — you take the Glim and move on.");
      run.openShop();
      showCribShop();
    }, "small");
    sk.classList.add("skipbtn");
    c.append(sk);
    c.append(el("p", "tiny dim",
      "Skips are earned by overshooting targets. Spoilers can never be skipped."));
  }
  if (run.isWager()) {
    c.append(btn("WALK AWAY", () => {
      run.wagerAt[`${run.act}-${run.round}`] = false;
      sfx16("click");
      flash("You let the wager pass.");
      cribRoundIntro();
    }, "small"));
  }
  c.append(btn("DEAL", () => {
    Cb.round = new CribRound(run);
    Cb.round.newDeal();
    Cb.keep = [];
    Cb.dealAnim = true;
    Audio16.setProximity(0);
    renderCrib();
    sfx16("cut");
  }, "big"));
  root().append(c);
}

function charmChip(ch, opts = {}) {
  const rar = ch.rarity || (ch.tier === 0 ? "deckbonus" : "common");
  const chip = el("div", "charm r-" + rar);
  const plq = el("div", "charmgem");
  if (ART.rarity && ART.rarity[rar]) plq.style.backgroundImage = `url(${ART.rarity[rar]})`;
  const cat = el("div", "charmcat");
  const catSrc = (ART.icons && ART.icons[ch.cat]) || (ART.cats && ART.cats[ch.cat]);
  if (catSrc) cat.style.backgroundImage = `url(${catSrc})`;
  plq.append(cat);
  chip.append(plq, el("div", "charmname", ch.name));
  tip(chip, ch.name + (ch.rarity ? `  ·  ${RARITY[ch.rarity].name}` : ""),
    ch.text || "Your Meldling's own knack.");
  if (opts.onSell) {
    const x = el("button", "sellx", "×");
    x.title = "Sell";
    x.onclick = (e) => { e.stopPropagation(); opts.onSell(ch); };
    chip.append(x);
  }
  return chip;
}

/* The HUD. Pinned to both the table and the count screen so the goal never
   leaves the screen — the single biggest clarity gap the audit found. */
function cribHUD(rd, run, opts = {}) {
  const wrap = el("div", "panel col tight hud");
  const boss = run.boss();

  const top = el("div", "row between");
  top.append(el("span", "small dim", `ACT ${run.act}-${run.round}`));
  if (boss) {
    const chip = el("span", `bosschip sev${boss.sev}`, boss.name);
    if (boss.align) chip.textContent = `${boss.name} ${SUIT_SYM[boss.align]}`;
    chip.title = boss.text;
    top.append(chip);
  }
  top.append(el("span", "small dim", `DEAL ${Math.min(rd.dealIndex + 1, rd.dealsLeft + rd.dealIndex)}`));
  wrap.append(top);

  const shown = opts.shownScore !== undefined ? opts.shownScore : rd.score;
  const scoreRow = el("div", "row between scoreline");
  const sc = el("span", "hudscore", String(shown));
  sc.id = "hudScore";
  scoreRow.append(sc, el("span", "hudtarget", `/ ${rd.target}`));
  wrap.append(scoreRow);

  const b = bar(shown / rd.target, shown >= rd.target ? "green" : "red");
  b.id = "hudBar";
  wrap.append(b);

  if (run.skips > 0 || run.surplus > 0) {
    const sr = el("div", "row between small");
    sr.append(el("span", "gold", `SURPLUS ${run.surplus}/${SURPLUS_PER_SKIP}`));
    if (run.skips > 0) sr.append(el("span", "green", `${run.skips} SKIP${run.skips > 1 ? "S" : ""} BANKED`));
    wrap.append(sr);
  }
  const need = Math.max(0, rd.target - shown);
  const deals = Math.max(1, rd.dealsLeft);
  const per = Math.ceil(need / deals);
  const pace = el("div", "row between small");
  if (need === 0) {
    pace.append(el("span", "green", "TARGET MET"),
                el("span", "green", "cash out any time"));
  } else {
    const tight = per > 60;
    pace.append(el("span", tight ? "red" : "gold", `NEED ${need}`),
      el("span", "dim", `${rd.dealsLeft} deal${rd.dealsLeft === 1 ? "" : "s"} left`),
      el("span", tight ? "red" : "dim", `${per} / deal`));
  }
  wrap.append(pace);
  if (boss) wrap.append(el("p", `small sev${boss.sev}`, boss.text +
    (rd.mods.deadSuit ? `  (${SUIT_SYM[rd.mods.deadSuit]} is ash)` : "")));
  return wrap;
}

function cribCharmRow(run, opts = {}) {
  const row = el("div", "charmrow");
  const list = run.activeCharms();
  const offset = list.length - run.charms.length;   // deck bonus sits first and is innate
  list.forEach((ch, i) => {
    const chip = charmChip(ch, ch.tier === 0 ? {} : opts);
    if (opts.reorder && ch.tier !== 0) {
      const slot = i - offset;
      chip.classList.add("movable");
      if (Cb.pickedCharm === slot) chip.classList.add("picked");
      chip.onclick = () => {
        if (Cb.pickedCharm === null || Cb.pickedCharm === undefined) {
          Cb.pickedCharm = slot;
        } else if (Cb.pickedCharm === slot) {
          Cb.pickedCharm = null;
        } else {
          run.moveCharm(Cb.pickedCharm, slot);
          Cb.pickedCharm = null;
          sfx16("place");
        }
        opts.rerender();
      };
    }
    row.append(chip);
  });
  for (let i = run.charms.length; i < run.slots(); i++)
    row.append(el("div", "charm empty", ""));
  return row;
}

/* Charms resolve left to right. An additive charm before a multiplier is worth
   far more than after it, so the order is a puzzle in itself. */
function charmOrderPanel(run) {
  const box = el("div", "panel col tight");
  box.append(sectionHead("CHARM ORDER", "they resolve left to right"));
  box.append(cribCharmRow(run, { reorder: true, rerender: showCribShop }));
  box.append(el("p", "tiny dim", Cb.pickedCharm === null || Cb.pickedCharm === undefined
    ? "Tap a charm, then tap where it should go."
    : "Now tap the slot to move it to."));

  if (run.charms.length >= 2 && Cb.orderProbe) {
    const p = Cb.orderProbe;
    box.append(el("p", "small " + (p.gain > 0 ? "gold" : "dim"),
      p.gain > 0 ? `A better arrangement exists — worth about ${p.gain} more on a typical hand.`
                 : "This is the strongest arrangement for a typical hand."));
  }
  const test = btn("Test arrangement", () => {
    const rd = Cb.round || new CribRound(run);
    if (!rd.dealt) rd.newDeal();
    const hand = rd.bestKeepEV().idx.map((i) => rd.dealt[i]);
    if (!rd.starter) rd.cutStarter();
    const cur = run.scoreWithOrder(rd, hand, [...Array(run.charms.length).keys()]);
    const best = run.bestOrder(rd, hand);
    Cb.orderProbe = { gain: best ? Math.max(0, best.total - cur) : 0 };
    sfx16("click");
    showCribShop();
  }, "small");
  box.append(test);
  return box;
}

function cribLevelRow(run) {
  const row = el("div", "charmrow");
  for (const cat of LEVEL_CATS) {
    const lv = run.levels[cat];
    const chip = el("div", "lvchip" + (lv ? " on" : ""));
    chip.textContent = `${cat} ${lv}`;
    row.append(chip);
  }
  return row;
}

/* ---------------------------------------------------------------- play */
function renderCrib() {
  const rd = Cb.round, run = Cb.run;
  screen("crib");
  const c = el("div", "col tight");

  c.append(cribHUD(rd, run));

  if (Cb.shuffled) {
    // the deck ran dry and gathered itself back up
    const sh = el("div", "shufflebanner");
    sh.append(el("span", "small gold", "THE DECK IS GATHERED"));
    c.append(sh);
    const deck = el("div", "row center shuffledeck");
    for (let i = 0; i < 5; i++) {
      const b = backEl(0.55);
      b.classList.add("shuffcard");
      b.style.animationDelay = (i * 60) + "ms";
      deck.append(b);
    }
    c.append(deck);
    Cb.shuffled = false;
    setTimeout(() => sfx16("cut"), 60);
  }

  // On a Spoiler round the Spoiler sits across the table and reacts to the play.
  const bossNow = run.boss();
  if (bossNow) {
    const stage = el("div", "row center spoilerStage");
    const foe = creatureEl(bossNow.art, "idle", 2.2);
    foe.id = "spoilerSprite";
    foe.classList.add("bossart", `sev${bossNow.sev}`);
    foe.style.filter =
      `hue-rotate(${(bossNow.id.charCodeAt(0) * 37) % 360}deg) saturate(${1 + bossNow.sev * 0.3})`;
    tip(foe, bossNow.name, bossNow.text);
    stage.append(foe);
    c.append(stage);
  }
  c.append(cribCharmRow(run));

  // the cut — unknown until you commit, unless you own Foresight
  const st = el("div", "row center gap");
  if (rd.starter) {
    const w = el("div", "pilewrap");
    const n = cbCard(rd.starter, 1.3); n.classList.add("starterflip");
    w.append(n, el("p", "small gold", "STARTER"));
    st.append(w);
    if (rd.starter2) {
      const w2 = el("div", "pilewrap");
      const n2 = cbCard(rd.starter2, 1.3); n2.classList.add("starterflip");
      w2.append(n2, el("p", "small gold", "STARTER 2"));
      st.append(w2);
    }
    if (rd.recutsLeft > 0)
      st.append(btn("Recut", () => { rd.recut(); sfx16("cut"); renderCrib(); }, "small"));
  } else {
    const w = el("div", "pilewrap");
    const n = backEl(1.3); n.classList.add("cutwait");
    w.append(n, el("p", "small dim", "THE CUT"));
    st.append(w);
    st.append(el("p", "small dim cutnote",
      "Cut after you commit. Keep for expected value, not for certainty."));
  }
  c.append(st);

  // ---- the Table: reference material, collapsed unless you've pinned it
  const pinCrib = Achv.pinned("crib");
  const pinDeck = Achv.pinned("counter");
  const pinCharms = Achv.pinned("ledger");

  const cribBlock = () => {
    const w = el("div", "cribwrap");
    const h = el("div", "row between");
    h.append(el("span", "small gold", `YOUR CRIB  (${rd.crib.length}/${CRIB_SIZE})`),
      el("span", "small dim", rd.mods.cribZero ? "scores nothing"
        : rd.crib.length >= CRIB_SIZE ? "full — later throws burn"
        : `first ${CRIB_SIZE} throws land here`));
    w.append(h);
    const r = el("div", "cribrow");
    if (!rd.crib.length) r.append(el("div", "small dim", "empty"));
    for (const cc of rd.crib) r.append(cardEl(cc, 0.7));
    w.append(r);
    return w;
  };
  const deckBlock = () => {
    const w = el("div", "col tight");
    if (rd.mods.hideTracker) {
      w.append(el("p", "small red", "The Fog — your tracker is hidden this round."));
      return w;
    }
    const trk = el("div", "decktrack");
    const hist = rd.remainingHistogram();
    for (let r = 1; r <= 13; r++) {
      const n = hist[r] || 0;
      const cell = el("div", "trkcell" + (n === 0 ? " gone" : ""));
      cell.append(el("div", "trkr", CRANK_LABEL[r]));
      cell.append(el("div", "trkn", String(n)));
      trk.append(cell);
    }
    w.append(trk);
    return w;
  };

  if (pinCharms) c.append(cribCharmRow(run));
  if (pinCrib) c.append(cribBlock());
  if (pinDeck) c.append(deckBlock());

  // one compact strip that always tells you the state, and opens the rest
  const strip = el("button", "tablestrip");
  strip.append(el("span", "small",
    `TABLE  ·  deck ${rd.stock.length}  ·  crib ${rd.crib.length}/${CRIB_SIZE}  ·  cycle ${rd.cycle}`));
  strip.append(el("span", "small gold", Cb.tableOpen ? "hide ▲" : "show ▼"));
  strip.onclick = () => { Cb.tableOpen = !Cb.tableOpen; sfx16("click"); renderCrib(); };
  c.append(strip);

  if (Cb.tableOpen) {
    const drawer = el("div", "col tight tabledrawer");
    if (!pinCharms) drawer.append(cribCharmRow(run));
    if (!pinCrib) drawer.append(cribBlock());
    if (!pinDeck) drawer.append(deckBlock());
    const opts = el("div", "row gap wrap");
    opts.append(btn(`Animation ${Speed.label()}`, () => { Speed.cycle(); renderCrib(); }, "small"));
    opts.append(btn(`Build-up: ${Audio16.rampStyleName()}`, () => {
      Audio16.cycleRamp();
      Audio16.rampStart(); Audio16.rampTo(0.85, 0.5);
      setTimeout(() => Audio16.rampBurst(), 700);
      renderCrib();
    }, "small"));
    drawer.append(opts);
    drawer.append(el("p", "tiny dim",
      "Pin any of these open for good with a Lens, bought from the Peddler."));
    c.append(drawer);
  }

  c.append(el("p", "banner",
    `Keep ${rd.keepCount()} of ${rd.dealt.length}. The other ${rd.dealt.length - rd.keepCount()} are thrown to your Crib.`));

  // dealt cards
  const hand = el("div", "hand cribhand");
  rd.dealt.forEach((card, i) => {
    const n = cbCard(card);
    if (Cb.dealAnim) {
      n.classList.add("dealin");
      n.style.animationDelay = (i * 65) + "ms";
    }
    n.dataset.i = i;
    if (Cb.keep.includes(i)) n.classList.add("sel");
    else {
      n.classList.add("tocrib");
      if (Cb.keep.length === rd.keepCount()) {
        n.classList.add("throwing");
        const full = rd.crib.length >= CRIB_SIZE;
        const tag = el("div", "throwtag" + (full ? " burn" : ""), full ? "BURNED" : "→ CRIB");
        n.appendChild(tag);
      }
    }
    n.onclick = () => cribToggle(i);
    if (Cb.dealAnim) {
      n.classList.add("dealin");
      n.style.animationDelay = (i * 70) + "ms";
      setTimeout(() => sfx16("deal"), i * 70);
    }
    hand.append(n);
  });
  c.append(hand);
  if (Cb.dealAnim) Cb.dealAnim = false;

  // live preview: locked-in points vs expected value of the cut
  const need = rd.keepCount();
  if (Cb.keep.length === need && typeof Guide !== "undefined" && Guide.on)
    setTimeout(() => guideShow("kept"), 120);
  if (Cb.keep.length === need) {
    const p = rd.preview(Cb.keep);
    const box = el("div", "panel col tight");
    if (p.blind) {
      // one compact line instead of a row per event
      if (p.events.length)
        box.append(el("div", "small blue previewline",
          p.events.map((e) => `${e.label} +${e.points}`).join("   ")));
      else box.append(el("p", "small dim", "Nothing locked in yet."));
      box.append(rowLR("LOCKED IN", String(p.sure), "green"));
      box.append(rowLR("EXPECTED AFTER CUT", p.ev.toFixed(1), "gold"));

    } else {
      for (const e of p.events) box.append(rowLR(e.label, `+${e.points}`, "blue"));
      if (p.levelBonus) box.append(rowLR("Category levels", `+${p.levelBonus}`, "gold"));
      box.append(rowLR("Base × Mult", `${p.base} × ${p.mult.toFixed(2)}`, "gold"));
      box.append(rowLR("SCORE", String(p.total), "green"));
      if (p.fired.length) box.append(el("p", "small gold", p.fired.join(" · ")));
    }
    c.append(box);
  } else {
    c.append(el("div", "selcount",
      `${Cb.keep.length} / ${need} kept — select ${need - Cb.keep.length} more`));
  }

  if (rd.score >= rd.target) {
    const co = btn(`CASH OUT  ·  +${rd.dealsLeft * 4 + rd.mulligansLeft * 3} bonus Glim`, () => {
      rd.cashOut(); sfx16("win"); cribRoundEnd();
    }, "big");
    co.classList.add("cashout");
    c.append(co);
  }
  const go = btn("COUNT IT", doCribCount, "big");
  go.disabled = Cb.keep.length !== need;
  c.append(go);


  const mull = btn(`MULLIGAN  (${rd.mulligansLeft})`, () => {
    if (!rd.mulligan()) { sfx16("bad"); return; }
    Cb.keep = []; Cb.dealAnim = true;
    sfx16("toCrib");
    renderCrib();
  }, "small");
  mull.disabled = rd.mulligansLeft <= 0 || rd.stock.length < rd.dealtCount();
  c.append(mull);


  root().append(c);
}

function cribToggle(i) {
  const rd = Cb.round;
  const at = Cb.keep.indexOf(i);
  if (at >= 0) Cb.keep.splice(at, 1);
  else {
    if (Cb.keep.length >= rd.keepCount()) { sfx16("bad"); return; }
    Cb.keep.push(i);
  }
  sfx16("select");
  renderCrib();
}

/* ---------------------------------------------------------------- cascade */
function doCribCount() {
  const rd = Cb.round;
  if (Cb.keep.length !== rd.keepCount()) return;
  const rank = rd.keepRank(Cb.keep);
  const keptCards = Cb.keep.map((i) => rd.dealt[i]);
  const knew = !!rd.starter;

  document.querySelectorAll(".cribhand .card.throwing").forEach((n, i) => {
    n.classList.add("flytocrib");
    n.style.animationDelay = (i * 90) + "ms";
    setTimeout(() => sfx16("place"), i * 90);
  });
  // rank the cut against every card that was still live, BEFORE the deal consumes them
  const preStock = rd.stock.slice();
  const res = rd.commit(Cb.keep.slice());
  if (!res) return;
  Cb.keep = [];
  Cb.optimalStreak = (rank && rank.rank === 1) ? (Cb.optimalStreak || 0) + 1 : 0;
  announceDeeds(Achv.check("count", {
    total: res.total, base: res.base,
    perfect: res.base >= 29 && !res.levelBonus && !res.enhBase,
    cutJack: rd.starter && rd.starter.rank === 11,
    cutSaved: res.crossedTarget && res.scoreBefore + res.handOnly < rd.target,
    optimalStreak: Cb.optimalStreak,
  }));
  const starter = rd.liveStarter(keptCards);
  const scoreBefore = rd.score - res.total;
  const liveStock = rd.stock;
  rd.stock = preStock;
  const quality = rd.cutQuality(keptCards, starter);
  rd.stock = liveStock;

  const afterCount = () => {
    if (typeof Achv !== "undefined" && Achv.hasSystem("the_play") && rd.stock.length >= 4)
      return showPegging(keptCards, () => {
        if (rd.dealsLeft > 0 && rd.score < rd.target) {
          const before = rd.cycle;
    rd.newDeal();
    Cb.dealAnim = true;
    Cb.shuffled = rd.cycle > before;
    renderCrib();
        } else cribRoundEnd();
      });
    if (rd.dealsLeft > 0 && rd.score < rd.target) {
      const before = rd.cycle;
    rd.newDeal();
    Cb.dealAnim = true;
    Cb.shuffled = rd.cycle > before;
    renderCrib();
    } else cribRoundEnd();
  };
  const go = () => cribCascade(res, rank, keptCards, starter, scoreBefore, afterCount);

  if (typeof Guide !== "undefined" && Guide.on) setTimeout(() => guideShow("cut"), 200);
  if (knew) return go();
  cutCeremony(starter, quality, go);
}

/* The reveal, tiered by how lucky the cut actually was.
   A better card rolls LONGER before it lands — so a long roll becomes a tell, and
   the wait itself turns into hope. */
const CUT_TIERS = {
  cold:    { roll: 520,  word: "",        cls: "ct-cold",  pips: 0,  shake: 3,  ramp: 0.35, shine: 0 },
  okay:    { roll: 780,  word: "OKAY",    cls: "ct-okay",  pips: 8,  shake: 5,  ramp: 0.55, shine: 1 },
  good:    { roll: 1080, word: "GOOD",    cls: "ct-good",  pips: 18, shake: 8,  ramp: 0.75, shine: 1 },
  great:   { roll: 1460, word: "GREAT",   cls: "ct-great", pips: 30, shake: 12, ramp: 0.92, shine: 2 },
  perfect: { roll: 2000, word: "THE BEST CARD IN THE DECK",
             cls: "ct-perfect", pips: 52, shake: 18, ramp: 1.0, shine: 3 },
};

function cutSound(tier) {
  const V = (f, d, o) => Audio16.voice(f, d, o);
  if (tier === "cold") {
    V(160, 0.34, { type: "triangle", gain: 0.10 });
    V(190, 0.30, { type: "sawtooth", gain: 0.05, delay: 0.03 });   // sour minor 2nd
  } else if (tier === "okay") {
    [392, 587].forEach((f, i) => V(f, 0.28, { type: "square", gain: 0.09, delay: i * 0.05, send: 0.3 }));
  } else if (tier === "good") {
    [392, 494, 587].forEach((f, i) =>
      V(f, 0.40, { type: "square", gain: 0.095, delay: i * 0.055, send: 0.38, detune: 8 }));
    Audio16.kick({ gain: 0.3 });
  } else if (tier === "great") {
    [523, 659, 784, 1047].forEach((f, i) =>
      V(f, 0.55, { type: "square", gain: 0.10, delay: i * 0.055, send: 0.45, detune: 10 }));
    [1319, 1568].forEach((f, i) => V(f, 0.3, { type: "square", gain: 0.05, delay: 0.26 + i * 0.06 }));
    Audio16.kick({ gain: 0.42 });
  } else {
    // perfect: a full rising fanfare that keeps going a beat longer than you expect
    [523, 659, 784, 1047, 1319, 1568, 2093].forEach((f, i) =>
      V(f, 0.7, { type: "square", gain: 0.10, delay: i * 0.07, send: 0.5, detune: 12 }));
    [261, 392].forEach((f, i) => V(f, 1.1, { type: "triangle", gain: 0.09, delay: i * 0.05 }));
    Audio16.kick({ gain: 0.55 });
    Audio16.snare({ delay: 0.5, gain: 0.3 });
  }
}

function cutCeremony(starter, quality, done) {
  const T = CUT_TIERS[quality.tier] || CUT_TIERS.okay;
  screen("cut");
  const c = el("div", "col center cutwrap");
  c.append(el("p", "dim", "THE CUT"));

  const holder = el("div", "cutholder");
  const back = backEl(2.2);
  back.classList.add("cutspin");
  holder.append(back);
  c.append(holder);

  const sub = el("p", "small dim", "…");
  c.append(sub);
  root().append(c);

  // roll: strikes tighten and the pitch steps up as the wait stretches
  Audio16.rampStart();
  let n = 0;
  const roll = setInterval(() => {
    const prog = Math.min(1, (n * 90) / T.roll);
    Audio16.noise(0.045, { freq: 1900 + n * 90, gain: 0.05 });
    Audio16.voice(280 + n * 34, 0.045, { gain: 0.04, type: "square" });
    Audio16.rampTo(T.ramp * prog, 0.1);
    // the longer it runs, the more the card shakes with it
    back.style.transform = `rotate(${(Math.random() * 2 - 1) * (2 + prog * 5)}deg)`;
    n++;
  }, 90);

  setTimeout(() => {
    clearInterval(roll);
    holder.innerHTML = "";
    const face = cardEl(starter, 2.2);
    face.classList.add("cutreveal", T.cls);
    if (T.shine) {
      const sh = el("div", "shine s" + T.shine);
      face.appendChild(sh);
    }
    holder.append(face);

    Audio16.rampBurst();
    cutSound(quality.tier);
    Juice.shake(T.shake, 300);
    if (T.pips) {
      const r = holder.getBoundingClientRect();
      Juice.burst(r.left + r.width / 2, r.top + r.height / 2, T.pips,
        quality.tier === "perfect" ? ["gold", "white", "green"]
          : quality.tier === "great" ? ["gold", "white"] : ["blue", "white"]);
    }

    if (T.word) {
      const w = el("h2", "cutword " + T.cls, T.word);
      c.append(w);
    }
    sub.textContent = quality.gain > 0
      ? `+${quality.gain} from the cut  ·  ${quality.rank} of ${quality.of} possible`
      : `nothing from the cut  ·  ${quality.rank} of ${quality.of} possible`;
    sub.className = "small " + (quality.gain > 0 ? "gold" : "dim");

    if (quality.tier === "perfect") {
      Audio16.duck(0.4, 0.1, 1.2);
      setTimeout(() => Juice.burst(window.innerWidth / 2, window.innerHeight * 0.35, 40,
        ["gold", "white", "green"]), 260);
    }
    setTimeout(done, quality.tier === "perfect" ? 1500 : 780);
  }, T.roll);
}

function cribRoundEnd() {
  const rd = Cb.round, run = Cb.run;
  const cribRes = rd.cribResult || rd.settleCrib();
  rd.settle();
  sfx16(rd.won ? "win" : "lose");

  screen("cribEnd");
  const c = el("div", "col center");

  if (rd.wager) {
    if (rd.wagerWon) {
      const locked = Achv.lockedSystems();
      if (locked.length) {
        Achv.grantSystem(locked[0].id);
        setTimeout(() => announceSystem(locked[0]), 500);
      }
    }
  }
  let head = rd.won ? "ROUND CLEARED" : "RUN OVER";
  if (rd.wager) head = rd.wagerWon ? `EXACTLY ${rd.target}` : `MISSED BY ${Math.abs(rd.margin)}`;
  let headCls = rd.won ? "title" : "title red";
  if (rd.narrow) { head = `CLEARED BY ${rd.margin}`; headCls = "title narrowwin"; }
  if (rd.soClose) { head = `${-rd.margin} SHORT`; headCls = "title soclose"; }
  c.append(el("h2", headCls, head));
  if (rd.narrow) { Juice.shake(6, 300); Audio16.sfx("milestone"); }

  // the counterfactual — "you would have lost without this"
  announceDeeds(Achv.check("round", {
    won: rd.won, act: run.act, round: run.round, score: rd.score, target: rd.target,
    deckSize: run.deckSize(), cribTotal: (rd.cribResult && rd.cribResult.total) || 0,
    maxReckoning: Math.max(...Object.values(run.levels)),
    hallowed: run.charms.filter((x) => x.rarity === "legendary").length,
    shattered: (rd.shatteredAll || []).length,
    actCleared: rd.won && run.round === CRIB_ROUNDS,
  }));
  const m = rd.mvp();
  if (m) {
    const box = el("div", "panel col tight " + (m.decisive ? "mvpbox decisive" : "mvpbox"));
    box.append(el("div", "small dim", m.decisive ? "THIS WON YOU THE ROUND" : "BIGGEST CONTRIBUTOR"));
    box.append(el("div", "mvpname", m.name));
    box.append(el("div", "small gold", `+${Math.round(m.points)} points`));
    if (m.decisive)
      box.append(el("div", "small red",
        `Without it you'd have finished on ${Math.round(m.without)} — you needed ${rd.target}.`));
    c.append(box);
    if (m.decisive) {
      Audio16.sfx("milestone");
      Juice.burst(window.innerWidth / 2, window.innerHeight * 0.35, 26, ["gold", "white"]);
    }
  }
  const box = el("div", "panel col tight");
  if (rd.shatteredAll && rd.shatteredAll.length) {
    box.append(el("p", "small glassbreak",
      `Shattered: ${rd.shatteredAll.map((x) => CRANK_LABEL[x.rank] + SUIT_SYM[x.suit]).join(", ")}`));
  }
  if (rd.coinsAll) box.append(rowLR("Minted cards", `+${rd.coinsAll} Glim`, "green"));
  Audio16.setProximity(Math.min(1, rd.score / rd.target));
  const cribShow = el("div", "cribrow center");
  for (const cc of rd.crib.slice(0, 8)) cribShow.append(cardEl(cc, 0.9));
  if (rd.crib.length) { box.append(el("p", "small gold", "YOUR CRIB")); box.append(cribShow); }
  if (cribRes.events && cribRes.events.length)
    box.append(el("p", "small dim", cribRes.events.map((e) => e.label).join(", ")));
  box.append(rowLR("The Crib pays", `+${cribRes.total}`, "gold"));
  (cribRes.events || []).forEach((_, i) => setTimeout(() => Audio16.cribTick(i), 120 + i * 160));
  if (cribRes.events && cribRes.events.length)
    box.append(el("p", "small dim", cribRes.events.map((e) => e.label).join(", ")));
  if (rd.outOfCards) box.append(el("p", "small red", "Your deck ran out."));
  box.append(rowLR("Final score", `${rd.score} / ${rd.target}`, rd.won ? "green" : "red"));
  if (rd.won) box.append(rowLR("Essence", `+${rd.essenceEarned}`, "gold"));
  c.append(box);

  if (!rd.won) {
    const m = Meta.record(run, run.roundIndex() - 1, rd.score);
    c.append(el("p", "dim", `Reached Act ${run.act}, Round ${run.round}.`));
    c.append(el("p", "small gold", Meta.line()));
    c.append(btn("New Run", showCribSelect, "big"));
    c.append(btn("Title", showTitle, "small"));
  } else {
    run.essence += rd.essenceEarned;
    c.append(btn("SHOP", () => { run.openShop(); showCribShop(); }, "big"));
  }
  root().append(c);
}

/* ---------------------------------------------------------------- shop */
/* A result card built to be screenshotted. Short, legible, and it leads with the
   emotional beat rather than the stats — that's what gets shared. */
function shareCard(run, rd) {
  const box = el("div", "panel col tight sharecard");
  const m = rd.mvp();
  const rm = run.runMVP();
  box.append(el("div", "sharehead", "MELDLINGS"));
  box.append(el("div", "small dim",
    `${CRIB_DECKS[run.meldling].name} ${SUIT_SYM[CRIB_DECKS[run.meldling].suit]}  ·  Act ${run.act}-${run.round}`));
  const big = el("div", "sharescore", `${rd.score} / ${rd.target}`);
  box.append(big);
  if (rd.soClose) box.append(el("div", "soclose small", `${-rd.margin} SHORT`));
  if (m && m.decisive) box.append(el("div", "small gold", `Carried by ${m.name}`));
  else if (rm) box.append(el("div", "small gold", `Run MVP: ${rm.name}`));
  const charmLine = run.charms.map((ch) => ch.name).join(" · ") || "no charms";
  box.append(el("div", "small dim", charmLine));

  const copy = btn("COPY RESULT", () => {
    const streak = Achv.dailyStreak();
    const bar = (n) => "\u25A0".repeat(Math.min(10, Math.ceil(n / 2.5))) +
                       "\u25A1".repeat(Math.max(0, 10 - Math.ceil(n / 2.5)));
    const txt = run.daily ? [
      `MELDLINGS Daily ${run.daily}`,
      `${bar(rd.score / Math.max(1, rd.target) * 10)}  Act ${run.act}-${run.round}`,
      streak > 1 ? `Streak ${streak}` : "",
    ].filter(Boolean).join("\n") : [
      `MELDLINGS — ${CRIB_DECKS[run.meldling].name} ${SUIT_SYM[CRIB_DECKS[run.meldling].suit]}`,
      `Act ${run.act}-${run.round}   ${rd.score}/${rd.target}` + (rd.soClose ? `  (${-rd.margin} short!)` : ""),
      m && m.decisive ? `Carried by ${m.name}` : (rm ? `MVP ${rm.name}` : ""),
      charmLine,
    ].filter(Boolean).join("\n");
    try {
      navigator.clipboard.writeText(txt);
      flash("Result copied");
    } catch (e) { flash("Copy unavailable"); }
    sfx16("buy");
  }, "small");
  box.append(copy);
  return box;
}

function sectionHead(title, note) {
  const h = el("div", "row between sectionhead");
  h.append(el("span", "sechead", title));
  if (note) h.append(el("span", "small dim", note));
  return h;
}

function showCribShop() {
  Audio16.playMusic("shop");
  const run = Cb.run;
  if (!run.shopState) run.openShop();
  setSurface("felt_shop");
  screen("cribShop");
  const c = el("div", "col");

  const head = el("div", "panel col tight");
  head.append(rowLR("THE PEG HOUSE", `${run.essence} Glim`, "gold"));
  head.append(el("p", "small dim",
    `Act ${run.act}-${run.round} cleared  ·  deck ${run.deckSize()} cards  ·  ` +
    `charms ${run.charms.length}/${run.slots()}`));
  c.append(head);

  c.append(el("p", "small gold", "YOUR CHARMS  (tap × to sell)"));
  c.append(cribCharmRow(run, {
    onSell: (ch) => {
      const got = run.sell(ch.id);
      sfx16("place");
      Juice.burst(window.innerWidth / 2, window.innerHeight * 0.25, 8, ["gold"]);
      flash(`Pawned ${ch.name} for ${got} Glim`);
      showCribShop();
    },
  }));

  // ---- charm offers
  const offHead = el("div", "row between");
  offHead.append(el("span", "sechead", "CHARMS ON OFFER"));
  const rr = btn(`Reroll  ${run.rerollCost()}`, () => {
    if (run.reroll()) { sfx16("cut"); showCribShop(); } else sfx16("bad");
  }, "small");
  rr.disabled = run.essence < run.rerollCost();
  rr.classList.add("rrbtn");
  offHead.append(rr);
  c.append(offHead);

  const full = run.isFull();
  for (const ch of run.shopState.offer) {
    if (run.charms.some((x) => x.id === ch.id)) continue;
    const rar = ch.rarity || "common";
    const b = el("button", `shopitem r-${rar}`);
    const gem = el("div", "shopgem");
    if (ART.rarity && ART.rarity[rar]) gem.style.backgroundImage = `url(${ART.rarity[rar]})`;
    const l = el("div", "col tight grow");
    const title = el("div", "row between");
    title.append(el("span", "shoptitle", ch.name),
                 el("span", "raritytag r-" + rar, RARITY[rar].name));
    l.append(title, el("div", "small dim", ch.text));
    b.append(gem, l, el("div", "cost", String(ch.cost)));
    b.disabled = ch.cost > run.essence || full;
    b.onclick = () => {
      if (ch.cost > run.essence || run.isFull()) { sfx16("bad"); return; }
      run.essence -= ch.cost;
      run.charms.push(ch);
      if (ch.onAcquire) ch.onAcquire(run);
      sfx16(rar === "legendary" ? "milestone" : "buy");
      Juice.burst(window.innerWidth / 2, window.innerHeight * 0.4,
        rar === "legendary" ? 30 : 12,
        rar === "legendary" ? ["gold", "white", "green"] : ["gold", "white"]);
      run.shopState.offer = run.shopState.offer.filter((x) => x.id !== ch.id);
      showCribShop();
    };
    c.append(b);
  }
  if (full) c.append(el("p", "small red", "Every charm slot is spoken for — pawn one first."));

  // ---- the card market
  c.append(sectionHead("THE STALL", "take a card into your deck"));
  c.append(el("p", "small dim",
    "Fives are scarce and dear — a five makes fifteen with every court card."));
  const mrow = el("div", "row gap cardmarket");
  for (const entry of run.shopState.cards) {
    if (entry.sold) continue;
    const slot = el("div", "marketslot");
    slot.append(cardEl(entry.card, 1.05));
    const meta = entry.card.enh ? ENHANCEMENTS[entry.card.enh] : null;
    slot.append(el("div", "small " + (meta ? "gold" : "dim"), meta ? meta.name : "unmarked"));
    const b = btn(String(entry.cost), () => {
      if (run.buyCard(entry)) {
        entry.sold = true;
        sfx16(entry.card.enh ? "buy" : "place");
        Juice.burst(window.innerWidth / 2, window.innerHeight * 0.55,
          entry.card.enh ? 16 : 8, ["gold", "white"]);
        flash(`Added ${CRANK_LABEL[entry.card.rank]}${SUIT_SYM[entry.card.suit]} to your deck`);
        showCribShop();
      } else sfx16("bad");
    }, "small");
    b.disabled = run.essence < entry.cost;
    slot.append(b);
    if (meta) tip(slot, meta.name, meta.text);
    mrow.append(slot);
  }
  if (!mrow.children.length) mrow.append(el("p", "small dim", "The stall is bare."));
  c.append(mrow);

  // ---- category levels
  c.append(sectionHead("RECKONINGS", "study a count, forever"));
  const grid = el("div", "lvgrid");
  for (const cat of LEVEL_CATS) {
    const cost = run.levelCostFor(cat);
    const b = el("button", "lvbtn");
    tip(b, `Reckoning: ${cat}`, `+${LEVEL_GAIN} base for every ${cat} you score, each level. Costs ${cost} Glim.`);
    const ic = el("div", "lvicon2");
    if (ART.icons && ART.icons[cat]) ic.style.backgroundImage = `url(${ART.icons[cat]})`;
    b.append(ic);
    b.append(el("div", "small", cat));
    b.append(el("div", "lvnum", `${run.levels[cat]} → ${run.levels[cat] + 1}`));
    b.append(el("div", "cost small", String(cost)));
    b.disabled = run.essence < cost;
    b.onclick = () => {
      if (run.buyLevel(cat)) { sfx16("level");
        Juice.burst(window.innerWidth / 2, window.innerHeight * 0.6, 10, ["gold", "green"]);
        showCribShop(); }
      else sfx16("bad");
    };
    grid.append(b);
  }
  c.append(grid);
  c.append(el("p", "small dim", `+${LEVEL_GAIN} base per scoring event of that kind, per Reckoning.`));

  c.append(el("p", "small dim",
    "Marks on cards do the rest — buy them at The Stall."));

  c.append(btn("NEXT ROUND", () => {
    run.shopState = null;
    if (run.endless) { run.endlessRound = (run.endlessRound || 0) + 1; cribRoundIntro(); return; }
    if (run.advance()) { screen("cribWon"); return cribRunWon(); }
    cribRoundIntro();
  }, "big"));
  root().append(c);
}

let _flashTimer = null;
function flash(msg) {
  const old = document.querySelector(".toast");
  if (old) old.remove();
  const t = el("div", "toast", msg);
  document.body.append(t);
  clearTimeout(_flashTimer);
  _flashTimer = setTimeout(() => t.remove(), 1600);
}

function cribRunWon() {
  const run = Cb.run;
  const c = el("div", "col center");
  c.append(el("h2", "title", "TWENTY-NINE"));
  c.append(creatureEl(run.meldling, "idle", 5));
  announceDeeds(Achv.check("run", { cleared: true, street: run.street.id }));
  Achv.markCleared(run.meldling);
  if (run.trial) Achv.markTrial(run.trial.id);
  const pegsWon = pegsForRun(CRIB_ACTS * CRIB_ROUNDS, true, run.street.id, Achv.count());
  Achv.addPegs(pegsWon);
  Achv.logRun({ deck: run.meldling, reached: CRIB_ACTS * CRIB_ROUNDS,
                street: run.street.id, score: 0, cleared: true, when: Date.now() });
  c.append(el("p", "gold", `+${pegsWon} Pegs`));
  Meta.record(run, CRIB_ACTS * CRIB_ROUNDS, 0);
  const rmv = run.runMVP();
  if (rmv) c.append(el("p", "gold", `Carried by ${rmv.name} — ${rmv.points} points.`));
  c.append(el("p", "gold", `All ${CRIB_ACTS * CRIB_ROUNDS} rounds cleared on ${run.street.name}.`));
  if (run.street.id < STREETS.length)
    c.append(el("p", "small gold", `${STREETS[run.street.id].name} is open.`));
  c.append(el("p", "small gold", Meta.line()));
  c.append(el("p", "small gold", Meta.line()));
  c.append(cribCharmRow(run));
  c.append(cribLevelRow(run));
  c.append(btn("New Run", showCribSelect, "big"));
  root().append(c);
}
