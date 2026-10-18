/* ============================================================
   DEV PANEL — testing only.
   To remove entirely: set DEV = false below, or delete this file
   and the one `admin.js` line in tools/build_web.py.
   ============================================================ */
const DEV = true;

function showAdmin() {
  if (!DEV) return showTitle();
  screen("admin");
  const c = el("div", "col");
  c.append(el("h2", "title red", "DEV PANEL"));
  c.append(el("p", "small dim", "Testing shortcuts. Not part of the game."));

  const sect = (t) => c.append(el("p", "small gold", t));
  const act = (label, fn, note) => {
    const b = el("button", "btn small devbtn");
    b.append(el("div", "", label));
    if (note) b.append(el("div", "tiny dim", note));
    b.onclick = () => { fn(); sfx16("buy"); showAdmin(); };
    c.append(b);
  };

  // ---- currency
  sect("CURRENCY");
  c.append(el("p", "small",
    `Glim in run: ${Cb.run ? Cb.run.essence : "—"}   ·   Pegs: ${Achv.pegs()}`));
  act("+100 Glim", () => { if (Cb.run) Cb.run.essence += 100; }, "needs an active run");
  act("+1000 Glim", () => { if (Cb.run) Cb.run.essence += 1000; });
  act("+500 Pegs", () => Achv.addPegs(500));

  // ---- unlocks
  sect("UNLOCKS");
  c.append(el("p", "small",
    `Systems ${SYSTEMS.length - Achv.lockedSystems().length}/${SYSTEMS.length}   ·   ` +
    `Deeds ${Achv.count()}/${ACHIEVEMENTS.length}   ·   Street ${Achv.streetUnlocked()}/${STREETS.length}`));
  act("Unlock all systems", () => SYSTEMS.forEach((s) => Achv.grantSystem(s.id)),
      "crib cut, the play, split cards, sixth slot…");
  act("Unlock all deeds", () => ACHIEVEMENTS.forEach((a) => Achv.grant(a.id)));
  act("Unlock all Streets", () => Achv.unlockStreet(STREETS.length));
  act("Unlock all Meldlings", () => {
    ACHIEVEMENTS.forEach((a) => Achv.grant(a.id));
    Object.keys(CRIB_DECKS).forEach((d) => Achv.markCleared(d.replace("_asc", "")));
  });
  act("Own every card back + lens", () => {
    CARD_BACKS.forEach((b) => { Achv.addPegs(b.cost); Achv.buyBack(b.id); });
    LENSES.forEach((l) => { Achv.addPegs(l.cost); Achv.buyLens(l.id); });
  });
  act("Complete all trials", () => TRIALS.forEach((t) => Achv.markTrial(t.id)));

  // ---- run state
  sect("RUN");
  if (Cb.run) {
    const r = Cb.run;
    c.append(el("p", "small",
      `Act ${r.act}-${r.round} · ${r.street.name} · deck ${r.deckSize()} · charms ${r.charms.length}/${r.slots()}`));
    act("Skip ahead 5 rounds", () => { for (let i = 0; i < 5; i++) r.advance(); });
    act("Jump to Act 5", () => { r.act = 5; r.round = 1; });
    act("+5 banked skips", () => { r.skips += 5; });
    act("Give 5 random charms", () => {
      for (let i = 0; i < 5 && !r.isFull(); i++) {
        const pool = CCHARMS.filter((x) => !r.charms.some((y) => y.id === x.id));
        const pick = pool[Math.floor(Math.random() * pool.length)];
        if (pick) { r.charms.push(pick); if (pick.onAcquire) pick.onAcquire(r); }
      }
    });
    act("Give a Mythic charm", () => {
      const m = CCHARMS.filter((x) => x.rarity === "mythic");
      const pick = m[Math.floor(Math.random() * m.length)];
      if (pick && !r.isFull()) r.charms.push(pick);
    });
    act("Mark every deck card", () => {
      const keys = Object.keys(ENHANCEMENTS);
      for (const cd of r.cards)
        if (Math.random() < 0.4) cd.enh = keys[Math.floor(Math.random() * keys.length)];
    });
    act("Add 6 split cards", () => {
      for (let i = 0; i < 6; i++) {
        const o = rollCardOffer();
        o.card.rank2 = 1 + Math.floor(Math.random() * 13);
        o.card.suit2 = ["S", "H", "C", "D"][Math.floor(Math.random() * 4)];
        r.cards.push(o.card);
      }
    });
    act("Clear this round instantly", () => {
      if (Cb.round) { Cb.round.score = Cb.round.target * 2; }
    });
  } else {
    c.append(el("p", "small dim", "Start a run to see run-state tools."));
  }

  // ---- danger
  sect("DANGER");
  act("Wipe save", () => {
    try { localStorage.removeItem(Achv.KEY); localStorage.removeItem(Meta.KEY); } catch (e) {}
  }, "deletes all progress");

  c.append(btn("Back", showTitle, "small"));
  root().append(c);
}
