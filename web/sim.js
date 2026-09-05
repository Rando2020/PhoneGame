/* Balance harness. Plays thousands of battles with different player policies
   to answer the question that decides the design: is patience ever correct? */

const R = require("./rules.js");
const { Combat, Run, classify, findMelds, Kind } = R;

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------- policies
const meldsOf = (c) => findMelds(c.hand).map((idx) => ({
  idx, cards: idx.map((i) => c.hand[i]), v: classify(idx.map((i) => c.hand[i])),
})).filter((m) => m.v.valid);

/* GREEDY: always play the biggest damage meld available, right now. */
function greedy(c) {
  while (c.focus > 0 && !c.over) {
    const ms = meldsOf(c);
    if (!ms.length) break;
    const score = (m) => {
      if (m.v.kind === Kind.GRAND) return 1000;
      if (m.v.kind === Kind.RUN) return 500 + m.idx.length * 10;
      if (m.v.kind === Kind.SET) return 400 + m.idx.length * 10;
      if (m.v.kind === Kind.PAIR) return 100;
      return 50;
    };
    ms.sort((a, b) => score(b) - score(a));
    const best = ms[0];
    c.playMeld(c.takeFromHand(best.idx));
  }
  c.endTurn();
}

/* PATIENT: brace when the incoming hit is big, and hold 2-runs hoping to
   extend them into 3+ runs instead of cashing them as PREP. */
function patient(c) {
  while (c.focus > 0 && !c.over) {
    const ms = meldsOf(c);
    if (!ms.length) break;
    const incoming = c.intent.kind === "STRIKE" || c.intent.kind === "RALLY" ? c.intent.amount : 0;
    const threat = incoming - c.player.block;

    const big = ms.filter((m) => m.v.kind === Kind.GRAND ||
      (m.v.kind === Kind.RUN && m.idx.length >= 4) ||
      (m.v.kind === Kind.SET && m.idx.length >= 3));
    const pairs = ms.filter((m) => m.v.kind === Kind.PAIR);
    const runs3 = ms.filter((m) => m.v.kind === Kind.RUN && m.idx.length === 3);

    let pick = null;
    if (big.length) pick = big.sort((a, b) => b.idx.length - a.idx.length)[0];
    else if (threat > c.player.hp * 0.25 && pairs.length) pick = pairs[0];
    else if (runs3.length) pick = runs3[0];
    else if (pairs.length) pick = pairs[0];
    else break;                       // hold 2-runs rather than spend them

    c.playMeld(c.takeFromHand(pick.idx));
  }
  c.endTurn();
}

/* TURTLE: brace at every opportunity, only attack with 4+ melds. */
function turtle(c) {
  while (c.focus > 0 && !c.over) {
    const ms = meldsOf(c);
    if (!ms.length) break;
    const pairs = ms.filter((m) => m.v.kind === Kind.PAIR);
    const big = ms.filter((m) => m.idx.length >= 4);
    const pick = big.length ? big[0] : (pairs.length ? pairs[0] :
      ms.filter((m) => m.v.kind === Kind.RUN || m.v.kind === Kind.SET)[0]);
    if (!pick) break;
    c.playMeld(c.takeFromHand(pick.idx));
  }
  c.endTurn();
}

// ---------------------------------------------------------------- sim
function battle(policy, enemyId, seed, meldling = "pip", relics = []) {
  const rng = mulberry32(seed);
  const run = new Run(meldling);
  run.relics = relics;
  const c = new Combat(run, enemyId, rng);
  let guard = 0;
  while (!c.over && guard++ < 200) policy(c);
  return { victory: c.victory, turns: c.turn, hpLeft: c.player.hp, timeout: guard >= 200 };
}

function sweep(policy, name, enemyId, n = 2000) {
  let wins = 0, turns = 0, hp = 0, timeouts = 0;
  for (let i = 0; i < n; i++) {
    const r = battle(policy, enemyId, i * 7919 + 13);
    if (r.victory) { wins++; turns += r.turns; hp += r.hpLeft; }
    if (r.timeout) timeouts++;
  }
  return {
    policy: name, enemy: enemyId,
    winRate: (100 * wins / n).toFixed(1) + "%",
    avgTurns: wins ? (turns / wins).toFixed(1) : "-",
    avgHpLeft: wins ? (hp / wins).toFixed(1) : "-",
    timeouts,
  };
}

const policies = [[greedy, "greedy"], [patient, "patient"], [turtle, "turtle"]];
const enemies = ["deadwood", "shuffler", "jokester", "kingpin"];

console.log("=== win rate by policy (2000 battles each, Pip, no relics) ===\n");
const rows = [];
for (const e of enemies) for (const [p, n] of policies) rows.push(sweep(p, n, e));
console.table(rows);

console.log("\n=== meld damage curve ===");
for (let n = 2; n <= 6; n++) {
  const strike = n >= 3 ? 5 * n + 3 * (n - 3) : "-";
  const rally = n >= 3 && n <= 4 ? 4 * n : "-";
  const brace = n === 2 ? 6 + n : "-";
  console.log(`  ${n} cards:  STRIKE ${strike}   RALLY ${rally}(+burn)   BRACE ${brace}`);
}

console.log("\n=== enemy damage ramp (STRIKE intent) ===");
for (const e of enemies) {
  const t = R.ROSTER[e].tier || 1;
  const at = (turn) => 6 + t * 3 + turn;
  console.log(`  ${R.ROSTER[e].name.padEnd(14)} t1:${at(1)}  t5:${at(5)}  t10:${at(10)}  t15:${at(15)}  (hp ${R.ROSTER[e].hp})`);
}
