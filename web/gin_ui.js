/* Gin Rummy mode UI. Live deadwood readout + auto-grouped melds is the teaching
   device here, the same way the dimming hints are in the combat mode. */

const GinUI = {
  hand: null,
  target: 25,
  scores: { player: 0, cpu: 0 },
  enemy: "deadwood",
  sel: -1,
  busy: false,
  browsing: false,
  msg: "",
  lastResult: null,
};

const TARGETS = { deadwood: 25, shuffler: 25, jokester: 50, kingpin: 100 };

function startGin(enemyId) {
  GinUI.enemy = enemyId;
  GinUI.target = TARGETS[enemyId] || 25;
  GinUI.scores = { player: 0, cpu: 0 };
  newGinHand();
}

function newGinHand() {
  GinUI.hand = new GinHand(Math.random, 10, ginMods());
  GinUI.sel = -1;
  GinUI.busy = false;
  GinUI.browsing = false;
  GinUI.lastResult = null;
  GinUI.msg = "Draw from the stock, or take the discard.";
  renderGin();
}

/* Relics that bend the Rummy rules — this is the "break Rummy" axis. */
function ginMods() {
  const r = App.run ? App.run.relics : [];
  const has = (id) => r.some((x) => x.id === id);
  return {
    knockLimit: has("looseknock") ? 15 : 10,
    ginBonus: has("purist") ? 40 : 25,
    undercutBonus: has("counterpunch") ? 40 : 25,
  };
}

function renderGin() {
  const h = GinUI.hand;
  screen("gin");
  const c = el("div", "col tight");

  // scoreboard
  const sb = el("div", "panel col tight");
  sb.append(rowLR(`${ROSTER[GinUI.enemy].name}`, `${GinUI.scores.cpu}`, "red"));
  sb.append(bar(GinUI.scores.cpu / GinUI.target, "red"));
  sb.append(rowLR(`${ROSTER[App.run.meldling].name}`, `${GinUI.scores.player}`, "green"));
  sb.append(bar(GinUI.scores.player / GinUI.target, "green"));
  sb.append(el("p", "small gold", `First to ${GinUI.target} points`));
  c.append(sb);

  if (GinUI.lastResult) { c.append(ginSummary()); root().append(c); return; }

  // piles
  const piles = el("div", "row center gap arena");
  const stock = el("div", "pilewrap");
  const sb2 = backEl(1.6);
  sb2.classList.add("clickable");
  sb2.onclick = () => doDraw("stock");
  stock.append(sb2, el("p", "small dim", `STOCK ${h.stock.length}`));
  piles.append(stock);

  const dis = el("div", "pilewrap");
  const top = h.discard[h.discard.length - 1];
  const dn = top ? cardEl(top, 1.6) : el("div", "card empty");
  dn.classList.add("clickable");
  dn.onclick = () => doDraw("discard");
  dis.append(dn, el("p", "small dim", `DISCARD ${h.discard.length}`));
  piles.append(dis);
  c.append(piles);

  const browse = btn(`Look through discard (${h.discard.length})`, () => {
    GinUI.browsing = true; sfx("click"); renderGin();
  }, "small");
  c.append(browse);

  if (GinUI.browsing) c.append(discardViewer());

  // deadwood readout — the teaching device
  const arr = bestArrangement(h.player);
  const limit = ginMods().knockLimit;
  const dwClass = arr.deadwood === 0 ? "green" : arr.deadwood <= limit ? "gold" : "red";
  const dw = el("div", "panel col tight");
  dw.append(rowLR("DEADWOOD", String(arr.deadwood), dwClass));
  dw.append(el("p", "small dim",
    arr.deadwood === 0 ? "GIN — every card melded."
      : arr.deadwood <= limit ? `You may knock (limit ${limit}).`
      : `Knock at ${limit} or less.`));
  c.append(dw);

  c.append(el("p", "banner", GinUI.msg));

  // hand, grouped: melds first, deadwood after a gap
  const meldedIdx = new Set();
  arr.melds.forEach((m) => m.forEach((i) => meldedIdx.add(i)));
  const hand = el("div", "hand ginhand");
  const order = [];
  arr.melds.forEach((m, gi) => m.forEach((i) => order.push({ i, group: gi })));
  arr.deadwoodIdx.forEach((i) => order.push({ i, group: -1 }));

  order.forEach(({ i, group }, pos) => {
    const n = cardEl(h.player[i], 1.7);
    n.dataset.i = i;
    n.classList.add(group >= 0 ? "melded" : "dead");
    if (group >= 0 && order[pos - 1] && order[pos - 1].group !== group) n.classList.add("gapL");
    if (group === -1 && order[pos - 1] && order[pos - 1].group !== -1) n.classList.add("gapL");
    if (GinUI.sel === i) n.classList.add("sel");
    n.onclick = () => pickCard(i);
    hand.append(n);
  });
  c.append(hand);

  // actions
  const bar1 = el("div", "row gap");
  const phase = h.phase;
  const discardB = btn("DISCARD", doDiscard);
  discardB.disabled = phase !== "discard" || GinUI.sel < 0;
  const knockB = btn(arr.deadwood === 0 ? "GIN!" : "KNOCK", doKnock);
  knockB.disabled = !(phase === "discard" && GinUI.sel >= 0 && knockable());
  bar1.append(discardB, knockB);
  c.append(bar1);

  c.append(el("p", "small dim",
    phase === "draw" ? "Phase: DRAW — take the stock or the discard."
      : "Phase: DISCARD — pick a card to throw."));

  root().append(c);
}

function knockable() {
  const h = GinUI.hand;
  if (GinUI.sel < 0) return false;
  const kept = h.player.slice();
  kept.splice(kept.findIndex((_, i) => i === GinUI.sel), 1);
  return bestArrangement(kept).deadwood <= ginMods().knockLimit;
}

function discardViewer() {
  const h = GinUI.hand;
  const p = el("div", "panel col tight");
  p.append(el("p", "gold small", "DISCARD PILE — newest first"));
  const strip = el("div", "row wrap gap");
  h.discard.slice().reverse().forEach((card) => strip.append(cardEl(card, 1.1)));
  p.append(strip);
  p.append(btn("Close", () => { GinUI.browsing = false; renderGin(); }, "small"));
  return p;
}

function pickCard(i) {
  const h = GinUI.hand;
  if (h.phase !== "discard" || GinUI.busy) { sfx("bad"); return; }
  GinUI.sel = GinUI.sel === i ? -1 : i;
  sfx("select");
  renderGin();
}

function doDraw(src) {
  const h = GinUI.hand;
  if (h.phase !== "draw" || h.turn !== "player" || GinUI.busy) return;
  const c = src === "stock" ? h.drawStock("player") : h.drawDiscard("player");
  if (!c) { sfx("bad"); return; }
  sfx("draw");
  GinUI.msg = src === "stock"
    ? `Drew ${cardLabel(c)} from the stock.`
    : `Took ${cardLabel(c)} from the discard — the CPU saw that.`;
  GinUI.sel = -1;
  if (h.over) return finishHand();
  renderGin();
}

function doDiscard() {
  const h = GinUI.hand;
  if (h.phase !== "discard" || GinUI.sel < 0) return;
  const c = h.discardCard("player", GinUI.sel);
  if (!c) return;
  sfx("place");
  GinUI.sel = -1;
  GinUI.busy = true;
  renderGin();
  if (h.over) return finishHand();
  setTimeout(cpuTurn, 620);
}

function doKnock() {
  const h = GinUI.hand;
  if (GinUI.sel < 0) return;
  const r = h.knock("player", GinUI.sel);
  if (!r) { sfx("bad"); GinUI.msg = "Deadwood too high to knock."; renderGin(); return; }
  sfx(r.gin ? "GRAND MELD" : "RALLY");
  finishHand();
}

function cpuTurn() {
  const h = GinUI.hand;
  const before = h.discard.length;
  CpuGin.takeTurn(h);
  GinUI.busy = false;
  if (h.over) return finishHand();
  const took = h.discard.length < before;
  GinUI.msg = took
    ? `${ROSTER[GinUI.enemy].name} took your discard.`
    : `${ROSTER[GinUI.enemy].name} drew from the stock.`;
  renderGin();
}

function finishHand() {
  const h = GinUI.hand;
  const r = h.result || { wash: true, winner: null, points: 0 };
  if (r.winner === "player") GinUI.scores.player += r.points;
  else if (r.winner === "cpu") GinUI.scores.cpu += r.points;
  GinUI.lastResult = r;
  sfx(r.winner === "player" ? "win" : r.winner === "cpu" ? "lose" : "click");
  renderGin();
}

function ginSummary() {
  const r = GinUI.lastResult;
  const p = el("div", "panel col");
  let head = "HAND WASHED";
  if (r.gin) head = r.knocker === "player" ? "GIN!" : "CPU GOES GIN";
  else if (r.undercut) head = r.winner === "player" ? "UNDERCUT!" : "YOU WERE UNDERCUT";
  else if (r.winner) head = r.winner === "player" ? "YOU KNOCK" : "CPU KNOCKS";
  p.append(el("h3", r.winner === "player" ? "gold" : "red", head));

  if (!r.wash) {
    p.append(el("p", "small dim",
      `knocker deadwood ${r.knockerDw} · opponent ${r.oppDw}` +
      (r.laidOff ? ` · laid off ${r.laidOff}` : "")));
    p.append(el("p", "", `${r.points} points to ${r.winner === "player" ? "you" : ROSTER[GinUI.enemy].name}`));
  } else p.append(el("p", "small dim", "Stock ran out — no score."));

  const done = GinUI.scores.player >= GinUI.target || GinUI.scores.cpu >= GinUI.target;
  if (done) {
    const won = GinUI.scores.player >= GinUI.target;
    p.append(el("h3", won ? "gold" : "red", won ? "MATCH WON" : "MATCH LOST"));
    p.append(btn(won ? "Continue" : "End Run", () => {
      if (!won) { App.run.lastResult = "defeat"; return showEnd(); }
      App.run.essence += GinUI.target;
      App.node++;
      if (App.node >= GAUNTLET.length) { App.run.lastResult = "victory"; return showEnd(); }
      showReward(false);
    }, "big"));
  } else {
    p.append(btn("Next Hand", newGinHand, "big"));
  }
  return p;
}
