/* The Gallery — every asset in the game, in one place.
   Doubles as a collection screen and as the fastest way to spot a missing or
   broken asset without hunting through a run. */

const GAL = { tab: "cards" };
const GAL_TABS = [
  ["cards",   "Cards"],
  ["split",   "Split"],
  ["marks",   "Marks"],
  ["backs",   "Backs"],
  ["meld",    "Meldlings"],
  ["spoil",   "Spoilers"],
];

function showGallery() {
  Audio16.playMusic("menu");
  screen("gallery");
  const c = el("div", "col");
  c.append(el("h2", "title", "THE GALLERY"));

  const tabs = el("div", "row gap wrap galtabs");
  for (const [id, label] of GAL_TABS) {
    const b = el("button", "galtab" + (GAL.tab === id ? " on" : ""), label);
    b.onclick = () => { GAL.tab = id; sfx16("click"); showGallery(); };
    tabs.append(b);
  }
  c.append(tabs);

  const body = el("div", "col tight");
  ({ cards: galCards, split: galSplit, marks: galMarks,
     backs: galBacks, meld: galMeld, spoil: galSpoil }[GAL.tab] || galCards)(body);
  c.append(body);

  c.append(btn("Back", showCribSelect, "small"));
  root().append(c);
}

function galNote(box, txt) { box.append(el("p", "small dim galnote", txt)); }

function galCards(box) {
  galNote(box, "All 52 faces. Every card in the game is generated, not drawn by hand.");
  for (const suit of ["S", "H", "C", "D"]) {
    box.append(el("p", "small gold", `${SUIT_SYM[suit]}  ${
      { S: "Spades", H: "Hearts", C: "Clubs", D: "Diamonds" }[suit]}`));
    const row = el("div", "galgrid");
    for (let r = 1; r <= 13; r++) {
      const w = el("div", "galcell");
      w.append(cardEl({ rank: r, suit }, 0.62));
      row.append(w);
    }
    box.append(row);
  }
}

function galSplit(box) {
  galNote(box, "Split cards count as either rank. Four shared images compose all " +
    "2,704 combinations — nothing here is a pre-rendered asset.");
  const samples = [
    [2, 3, "H", "H"], [1, 13, "S", "D"], [10, 11, "C", "C"], [5, 9, "D", "S"],
    [7, 8, "H", "S"], [4, 12, "C", "H"], [6, 6, "D", "D"], [3, 10, "S", "C"],
  ];
  const row = el("div", "galgrid");
  for (const [a, b, s1, s2] of samples) {
    const w = el("div", "galcell");
    w.append(cardEl({ rank: a, rank2: b, suit: s1, suit2: s2 }, 0.72));
    w.append(el("div", "tiny dim", `${CRANK_LABEL[a]}/${CRANK_LABEL[b]}`));
    row.append(w);
  }
  box.append(row);

  const roll = btn("Roll eight more", () => {
    sfx16("cut");
    showGallery();
  }, "small");
  box.append(roll);

  box.append(el("p", "small gold", "How it scores"));
  const demo = el("div", "panel col tight");
  demo.append(el("div", "small",
    "A hand of [2/3] 4 5 10 with a 6 cut scores 8 — the split takes the 3 to " +
    "complete a run of four. Held as a 2 it would score 7."));
  box.append(demo);
}

function galMarks(box) {
  galNote(box, "Marks sit on individual cards and change what they do.");
  for (const k of Object.keys(ENHANCEMENTS)) {
    const m = ENHANCEMENTS[k];
    const row = el("div", "row gap galrow");
    row.append(cardEl({ rank: 5, suit: "H", enh: k }, 0.6));
    const t = el("div", "col tight grow");
    t.append(el("div", "gold", m.name));
    t.append(el("div", "small dim", m.text));
    row.append(t);
    box.append(row);
  }
}

function galBacks(box) {
  galNote(box, "Card backs, bought from the Peddler with Pegs. Tap an owned back to equip it.");
  const row = el("div", "galgrid");
  for (const b of CARD_BACKS) {
    const owned = Achv.ownsBack(b.id);
    const w = el("div", "galcell" + (Achv.activeBack() === b.id ? " on" : ""));
    const img = el("div", "galback");
    if (ART.backs && ART.backs[b.id]) img.style.backgroundImage = `url(${ART.backs[b.id]})`;
    if (!owned) img.classList.add("locked");
    w.append(img);
    w.append(el("div", "tiny " + (owned ? "gold" : "dim"), owned ? b.name : `${b.cost} Pegs`));
    if (owned) w.onclick = () => { Achv.setBack(b.id); sfx16("select"); showGallery(); };
    row.append(w);
  }
  box.append(row);
}

function galMeld(box) {
  galNote(box, "Six Meldlings. Two are earned.");
  for (const id of Object.keys(CRIB_DECKS)) {
    const d = CRIB_DECKS[id];
    const open = Achv.meldlingUnlocked(id);
    const row = el("div", "row gap galrow" + (open ? "" : " dimmed"));
    row.append(creatureEl(id, "idle", 2));
    const t = el("div", "col tight grow");
    t.append(el("div", open ? "gold" : "dim", open ? `${d.name} ${SUIT_SYM[d.suit]}` : "???"));
    t.append(el("div", "small dim", open ? d.text : "Locked."));
    row.append(t);
    box.append(row);
  }
}

function galSpoil(box) {
  galNote(box, `All ${BOSS_POOL.length} Spoilers. Five are drawn per run, so no two runs meet the same set.`);
  for (const sev of [1, 2, 3]) {
    box.append(el("p", `small sev${sev}`,
      ["", "THREAT", "SEVERE", "RUINOUS"][sev]));
    for (const b of BOSS_POOL.filter((x) => x.sev === sev)) {
      const row = el("div", "row gap galrow");
      const cre = creatureEl(b.art, "idle", 1.6);
      cre.style.filter = `hue-rotate(${(b.id.charCodeAt(0) * 37) % 360}deg) saturate(${1 + sev * 0.35})`;
      row.append(cre);
      const t = el("div", "col tight grow");
      t.append(el("div", `sev${sev}`, b.name + (b.align ? `  ${SUIT_SYM[b.align]}` : "")));
      t.append(el("div", "small dim", b.text));
      row.append(t);
      box.append(row);
    }
  }
}
