/* A short, friendly first run. Teaches keep-then-cut, the Crib, the count and the
   shop in six beats, using the real screens rather than a mock. */

const Tut = { step: 0, active: false, done: false };

const TUT_STEPS = [
  { title: "Six cards, keep four",
    body: "You're dealt six. Choose the four you'll count — tap them. The other two are thrown to your Crib.",
    art: "pip", anchor: "hand" },
  { title: "Then the cut decides",
    body: "Only after you commit is a fifth card cut. It joins your four for the count — so keep for what's LIKELY, not what's certain.",
    art: "facet", anchor: "cut" },
  { title: "The Crib is yours",
    body: "Your first four thrown cards form the Crib. It scores for you at the end of the round. Feeding it well is a second skill.",
    art: "muggins", anchor: "crib" },
  { title: "Counting",
    body: "Every pair of cards adding to fifteen scores 2. Pairs score 2. Runs of three or more score their length. Flushes and his-nobs score too.",
    art: "thump", anchor: "count" },
  { title: "Charms and Marks",
    body: "Charms multiply your count. Marks sit on individual cards. Buy both at the Peg House between rounds — you have five charm slots, so choose.",
    art: "clover", anchor: "shop" },
  { title: "Spoilers",
    body: "Every fifth round is a Spoiler with a rule that breaks something. You can see all five at the start of a run — build for them.",
    art: "kingpin", anchor: "boss" },
];

function showTutorial() {
  Tut.active = true;
  Tut.step = 0;
  renderTutStep();
}

function renderTutStep() {
  const st = TUT_STEPS[Tut.step];
  if (!st) {
    Tut.active = false;
    try {
      const m = Achv.load(); m.tutorial = 1; Achv.save(m);
    } catch (e) {}
    return showCribSelect();
  }
  screen("tutorial");
  const c = el("div", "col center tutwrap");

  const pips = el("div", "row gap tutpips");
  TUT_STEPS.forEach((_, i) => {
    const d = el("div", "tutpip" + (i === Tut.step ? " on" : i < Tut.step ? " past" : ""));
    pips.append(d);
  });
  c.append(pips);

  const cre = creatureEl(st.art, "idle", 4);
  cre.classList.add("tutcre");
  c.append(cre);

  const box = el("div", "panel col tight tutbox");
  box.append(el("div", "tuttitle", st.title));
  box.append(el("div", "tutbody", st.body));
  c.append(box);

  c.append(tutVisual(st.anchor));

  const row = el("div", "row gap");
  if (Tut.step > 0)
    row.append(btn("Back", () => { Tut.step--; sfx16("click"); renderTutStep(); }, "small"));
  row.append(btn(Tut.step === TUT_STEPS.length - 1 ? "PLAY" : "Next", () => {
    Tut.step++;
    sfx16(Tut.step >= TUT_STEPS.length ? "buy" : "select");
    renderTutStep();
  }, "big"));
  c.append(row);
  c.append(btn("Skip", () => { Tut.step = TUT_STEPS.length; renderTutStep(); }, "small"));
  root().append(c);
}

/* A tiny live illustration per beat — real cards, not screenshots. */
function tutVisual(anchor) {
  const wrap = el("div", "row center gap tutvis");
  const C = (r, s, enh) => { const o = { rank: r, suit: s }; if (enh) o.enh = enh; return o; };
  if (anchor === "hand") {
    [C(5, "H"), C(5, "S"), C(10, "C"), C(11, "D"), C(2, "S"), C(9, "H")]
      .forEach((cd, i) => {
        const n = cardEl(cd, 0.95);
        if (i < 4) n.classList.add("sel"); else n.classList.add("tocrib");
        wrap.append(n);
      });
  } else if (anchor === "cut") {
    [C(5, "H"), C(5, "S"), C(10, "C"), C(11, "D")].forEach((cd) => wrap.append(cardEl(cd, 0.95)));
    const back = backEl(0.95); back.classList.add("cutwait");
    wrap.append(back);
  } else if (anchor === "crib") {
    [C(2, "S"), C(9, "H")].forEach((cd) => wrap.append(cardEl(cd, 0.95)));
    wrap.append(el("div", "small gold", "→ your Crib"));
  } else if (anchor === "count") {
    const t = el("div", "col tight");
    [["Fifteen 2", "+2"], ["Fifteen 4", "+2"], ["Pair of 5s", "+2"], ["Run of 3", "+3"]]
      .forEach(([a, b]) => {
        const r = el("div", "row between casrow");
        r.append(el("span", "grow", a), el("span", "casval", b));
        t.append(r);
      });
    wrap.append(t);
  } else if (anchor === "shop") {
    [C(5, "H", "gilded"), C(7, "C", "glass"), C(12, "S", "coin")]
      .forEach((cd) => wrap.append(cardEl(cd, 0.95)));
  } else if (anchor === "boss") {
    for (const b of ["deadwood", "shuffler", "jokester"]) wrap.append(creatureEl(b, "idle", 2));
  }
  return wrap;
}
