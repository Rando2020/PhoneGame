/* Roguelite mode UI — the Balatro-shaped loop. */

const Rg = { run: null, round: null, sel: [], busy: false, pop: null };

/* ---------------------------------------------------------------- entry */
function showRogueSelect() {
  screen("rogueSelect");
  const c = el("div", "col");
  c.append(el("h2", "title", "CHOOSE YOUR MELDLING"));
  c.append(el("p", "dim small", "Each one starts you on a different build."));

  for (const id of Object.keys(MELDLING_DECKS)) {
    const d = MELDLING_DECKS[id];
    const b = el("button", "deckcard");
    const left = el("div", "");
    left.append(creatureEl(id, "idle", 2));
    const right = el("div", "col tight grow");
    right.append(el("div", "gold", `${d.name}  ${SUIT_SYM[d.suit]}`));
    right.append(el("div", "small dim", d.text));
    b.append(left, right);
    b.onclick = () => { sfx("RALLY"); Rg.run = new RogueRun(id); startRound(); };
    c.append(b);
  }
  c.append(btn("Back", showTitle, "small"));
  root().append(c);
}

/* ---------------------------------------------------------------- round intro */
function startRound() {
  const run = Rg.run;
  const boss = run.boss();
  screen("roundIntro");
  const c = el("div", "col center");
  c.append(el("p", "dim", `ACT ${run.act}  ·  ROUND ${run.round} / ${ROUNDS_PER_ACT}`));

  if (boss) {
    c.append(el("h2", "title red", boss.name));
    c.append(creatureEl(boss.art, "idle", 4));
    const warn = el("div", "panel bossbox");
    warn.append(el("div", "red", "BOSS RULE"));
    warn.append(el("div", "", boss.text));
    c.append(warn);
  } else {
    c.append(el("h2", "title", `TARGET ${run.target()}`));
    c.append(creatureEl(run.meldling, "idle", 4));
  }

  c.append(el("p", "gold", `Score ${run.target()} points`));
  c.append(el("p", "small dim",
    `${BASE_TURNS + run.rules().turnBonus} turns · ` +
    `${BASE_HAND + run.rules().handBonus} cards · ` +
    `${run.rules().noDig ? "no" : Math.max(0, BASE_DIGS + run.rules().digBonus)} digs`));
  if (run.charms.length) c.append(charmRow(run));
  c.append(btn("BEGIN", () => { Rg.round = new Round(run); Rg.sel = []; renderRound(); }, "big"));
  root().append(c);
}

function charmRow(run) {
  const row = el("div", "charmrow");
  for (const ch of run.charms) {
    const chip = el("div", `charm t${ch.tier}`);
    chip.append(el("div", "small", ch.name));
    chip.title = ch.text;
    row.append(chip);
  }
  if (!run.charms.length) row.append(el("div", "small dim", "no charms yet"));
  return row;
}

/* ---------------------------------------------------------------- round play */
function renderRound() {
  const rd = Rg.round, run = Rg.run;
  screen("round");
  const c = el("div", "col tight");

  // --- header
  const head = el("div", "panel col tight");
  const boss = run.boss();
  head.append(rowLR(`ACT ${run.act}-${run.round}${boss ? "  ·  " + boss.name : ""}`,
    `${rd.score} / ${rd.target}`, rd.score >= rd.target ? "green" : "gold"));
  head.append(bar(rd.score / rd.target, rd.score >= rd.target ? "green" : "red"));
  head.append(el("p", "small dim",
    `TURNS ${rd.turnsLeft}   DIGS ${rd.mods.noDig ? "—" : (rd.mods.freeDig ? "∞" : rd.digsLeft)}   ` +
    `DEADWOOD ${rd.deadwood()}`));
  if (boss) head.append(el("p", "small red", boss.text));
  c.append(head);

  c.append(charmRow(run));

  // --- tableau
  const tab = el("div", "tableau");
  if (!rd.table.length) tab.append(el("div", "small dim", "no melds laid yet"));
  rd.table.forEach((m) => {
    const chip = el("div", `meldchip ${m.kind}`);
    const sorted = m.cards.slice().sort((a, b) => a.rank - b.rank);
    chip.textContent = m.kind === "set"
      ? `${RANK_LABEL[sorted[0].rank]} ×${m.cards.length}`
      : `${SUIT_SYM[sorted[0].suit]} ${sorted.map((x) => RANK_LABEL[x.rank]).join("-")}`;
    if (m.kind === "prep") chip.textContent += "  (prep)";
    tab.append(chip);
  });
  c.append(tab);

  // --- piles
  const piles = el("div", "row center gap");
  const st = el("div", "pilewrap");
  const stc = backEl(1.3);
  if (rd.phase === "draw") { stc.classList.add("clickable"); stc.onclick = () => doRDraw("stock"); }
  st.append(stc, el("p", "small dim", `STOCK ${rd.stock.length}`));
  piles.append(st);

  const dp = el("div", "pilewrap");
  const top = rd.discard[rd.discard.length - 1];
  const dpc = (top && !rd.mods.noDig) ? cardEl(top, 1.3) : backEl(1.3);
  if (rd.phase === "draw" && rd.canDig()) { dpc.classList.add("clickable"); dpc.onclick = () => doRDraw("dig"); }
  dp.append(dpc, el("p", "small dim", rd.mods.noDig ? "FACE DOWN" : `DIG ${rd.discard.length}`));
  piles.append(dp);
  c.append(piles);

  c.append(el("p", "banner", rd.phase === "draw"
    ? "DRAW — take the stock, or dig the discard."
    : "LAY melds, then discard to end your turn."));

  // --- hand
  const hand = el("div", "hand roguehand");
  rd.hand.forEach((card, i) => {
    const n = cardEl(card, 1.5);
    n.dataset.i = i;
    if (Rg.sel.includes(i)) n.classList.add("sel");
    n.onclick = () => toggleRg(i);
    hand.append(n);
  });
  c.append(hand);

  // --- actions
  const selCards = Rg.sel.map((i) => rd.hand[i]);
  const kind = layKind(selCards, rd.mods);
  const offTarget = selCards.length === 1 ? extendTarget(selCards[0], rd.table) : null;

  const bar1 = el("div", "row gap");
  const layB = btn(kind ? `LAY ${kind.toUpperCase()}` : (offTarget ? "LAY OFF" : "LAY"), doRLay);
  layB.disabled = rd.phase !== "act" || (!kind && !offTarget) ||
    (rd.mods.oneLayPerTurn && rd.laysThisTurn >= 1);
  const disB = btn("DISCARD", doRDiscard, "small");
  disB.disabled = rd.phase !== "act" || Rg.sel.length !== 1;
  bar1.append(layB, disB);
  c.append(bar1);

  if (rd.score >= rd.target)
    c.append(btn("CASH OUT — target met", doCashOut, "big"));

  // --- preview of the lay
  if (kind || offTarget) {
    const probe = rd.scoreLay(kind ? selCards : selCards, kind || (offTarget.kind === "prep" ? "prep" : offTarget.kind));
    c.append(el("p", "small blue",
      `${probe.base} base × ${probe.mult.toFixed(2)} = ${probe.total}` +
      (probe.fired.length ? `   [${probe.fired.join(", ")}]` : "")));
  }

  root().append(c);
  if (Rg.pop) { showPop(Rg.pop); Rg.pop = null; }
}

function toggleRg(i) {
  const rd = Rg.round;
  if (rd.phase !== "act") { sfx("bad"); return; }
  const at = Rg.sel.indexOf(i);
  if (at >= 0) Rg.sel.splice(at, 1); else Rg.sel.push(i);
  sfx("select");
  renderRound();
}

function doRDraw(src) {
  const rd = Rg.round;
  const c = rd.draw(src);
  if (!c) { sfx("bad"); return; }
  sfx(src === "dig" ? "place" : "draw");
  Rg.sel = [];
  if (rd.over) return endRound();
  renderRound();
}

function doRLay() {
  const rd = Rg.round;
  const selCards = Rg.sel.map((i) => rd.hand[i]);
  const kind = layKind(selCards, rd.mods);
  let res = null;
  if (kind) res = rd.layMeld(Rg.sel.slice());
  else if (selCards.length === 1) res = rd.layOff(Rg.sel[0]);
  if (!res) { sfx("bad"); return; }
  sfx(kind === "run" ? "STRIKE" : kind === "set" ? "RALLY" : "PREP");
  Rg.sel = [];
  Rg.pop = res;
  renderRound();
}

function doRDiscard() {
  const rd = Rg.round;
  if (Rg.sel.length !== 1) return;
  rd.discardCard(Rg.sel[0]);
  sfx("place");
  Rg.sel = [];
  if (rd.over) return endRound();
  renderRound();
}

function doCashOut() {
  Rg.round.cashOut();
  endRound();
}

function showPop(res) {
  const p = el("div", "scorepop");
  p.innerHTML = `<span class="gold">${res.base}</span> × ` +
    `<span class="blue">${res.mult.toFixed(2)}</span> = ` +
    `<span class="big">${res.total}</span>`;
  if (res.fired.length) {
    const f = el("div", "small gold", res.fired.join(" · "));
    p.append(f);
  }
  root().append(p);
  setTimeout(() => p.remove(), 1100);
}

/* ---------------------------------------------------------------- results */
function endRound() {
  const rd = Rg.round, run = Rg.run;
  if (!rd.over) rd.settle();
  else if (rd.essenceEarned === undefined) rd.settle();
  sfx(rd.won ? "win" : "lose");

  screen("roundEnd");
  const c = el("div", "col center");
  c.append(el("h2", rd.won ? "title" : "title red", rd.won ? "ROUND CLEARED" : "RUN OVER"));
  const box = el("div", "panel col tight");
  box.append(rowLR("Score", `${rd.score} / ${rd.target}`, rd.won ? "green" : "red"));
  box.append(rowLR("Melds laid", String(rd.laid.length)));
  box.append(rowLR("Deadwood", `-${rd.deadwoodPenalty}`, "red"));
  if (rd.goneOut) box.append(rowLR("Went out", "+6 essence", "gold"));
  if (rd.won) box.append(rowLR("Essence earned", `+${rd.essenceEarned}`, "gold"));
  c.append(box);

  if (!rd.won) {
    c.append(el("p", "dim", `Reached Act ${run.act}, Round ${run.round} of ${ROUNDS_PER_ACT}.`));
    c.append(btn("New Run", showRogueSelect, "big"));
    c.append(btn("Title", showTitle, "small"));
  } else {
    run.essence += rd.essenceEarned;
    c.append(btn("SHOP", showShop, "big"));
  }
  root().append(c);
}

/* ---------------------------------------------------------------- shop */
function showShop() {
  const run = Rg.run;
  screen("shop");
  const c = el("div", "col");
  c.append(el("h2", "title", "THE SANCTUM"));
  c.append(el("p", "gold", `${run.essence} Essence`));
  c.append(charmRow(run));

  const offer = run.shopOffer(3);
  if (!offer.length) c.append(el("p", "dim", "Nothing left to buy."));
  for (const ch of offer) {
    const b = el("button", `shopitem t${ch.tier}`);
    const l = el("div", "col tight grow");
    l.append(el("div", "gold", `${ch.name}   ${["", "·", "··", "···"][ch.tier]}`));
    l.append(el("div", "small dim", ch.text));
    b.append(l, el("div", "cost", String(ch.cost)));
    b.disabled = ch.cost > run.essence;
    b.onclick = () => {
      if (ch.cost > run.essence) return;
      run.essence -= ch.cost;
      run.charms.push(ch);
      sfx("GRAND MELD");
      showShop();
    };
    c.append(b);
  }

  c.append(btn("NEXT ROUND", () => {
    const done = run.advance();
    if (done) { screen("won"); return showRunWon(); }
    startRound();
  }, "big"));
  root().append(c);
}

function showRunWon() {
  const run = Rg.run;
  const c = el("div", "col center");
  c.append(el("h2", "title", "GAUNTLET BROKEN"));
  c.append(creatureEl(run.meldling, "idle", 5));
  c.append(el("p", "gold", `All ${ACTS * ROUNDS_PER_ACT} rounds cleared.`));
  c.append(charmRow(run));
  c.append(btn("New Run", showRogueSelect, "big"));
  root().append(c);
}
