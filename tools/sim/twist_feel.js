/* Twist feel and balance, on the real JS engine with cribsim's strong player.
   Seeded runs; each is played twice, twists on and twists off (same seed).
   Per round it records the twist (if any), whether the round was cleared,
   and the points the kept hands scored by category (fifteen, pair, run,
   flush), summed over the round's counts (wrapping CribRound.commit; the
   wrap only reads the result).
   1. Autopilot number: over consecutive plain rounds (not Spoiler rounds) of
      a run, the share of transitions where the round's leading category
      changes. Higher = rounds ask for different hands. Also the mean L1
      distance between the two rounds' category shares (0 to 2).
   2. Per twist: the round-clear rate on rounds with that twist (twists on).
     node tools/sim/twist_feel.js [runs, default 40] [first seed]          */
const path = require("path");
const WEB = path.join(__dirname, "..", "..", "web");
process.chdir(WEB);
const S = require(path.join(WEB, "cribsim.js"));
const R = require(path.join(WEB, "cribrogue.js"));
const { CribRun, CribRound, CRIB_ROUNDS, CRIB_ACTS } = R;
const M = require(path.join(WEB, "meta.js"));
if (!global.makeRng && M.makeRng) global.makeRng = M.makeRng;   // seeded runs
const N = +(process.argv[2] || 40);
const SEED0 = +(process.argv[3] || 31000);
const CATS = ["fifteen", "pair", "run", "flush"];

// read-only wrap: remember each committed hand's events on the round
const commit0 = CribRound.prototype.commit;
CribRound.prototype.commit = function (...a) {
  const res = commit0.apply(this, a);
  if (res && res.events) {
    this._cat = this._cat || { fifteen: 0, pair: 0, run: 0, flush: 0 };
    for (const e of res.events) if (e.kind in this._cat) this._cat[e.kind] += e.points;
  }
  return res;
};

/* Build-aware twists (pass 19 spike, sim only): before each plain round, the
   twist favours the category the run's rounds so far scored least in (runs
   have no twist of their own, so Seventh Card, the most cards); clearing it
   pays +3 Glim. Nothing in the game changes unless this passes its bar. */
const AWARE = { fifteen: "fifteen3", pair: "pairs4", flush: "flush3", run: "deal7" };
const AWARE_GLIM = 3;

function play(deck, seed, mode) {
  const twists = mode !== "off";
  const r = new CribRun(deck, undefined, undefined, seed);
  if (!twists) r.twistPlan = {};
  const rounds = [];
  const sofar = { fifteen: 0, pair: 0, run: 0, flush: 0 };
  let won = false;
  for (let i = 0; i < CRIB_ACTS * CRIB_ROUNDS; i++) {
    const boss = r.isBoss();
    let aware = false;
    if (mode === "aware" && r.twist()) {        // a plain twist round: re-aim it
      let low = null;
      for (const k of CATS) if (low === null || sofar[k] < sofar[low]) low = k;
      r.twistPlan[`${r.act}-${r.round}`] = AWARE[low];
      aware = true;
    }
    const tw = r.twist();
    const rd = S.playRound(r, "best");
    const cat = rd._cat || { fifteen: 0, pair: 0, run: 0, flush: 0 };
    for (const k of CATS) sofar[k] += cat[k];
    rounds.push({ boss, twist: tw ? tw.id : null, won: !!rd.won, cat });
    if (!rd.won) break;
    if (aware) r.essence += AWARE_GLIM;
    r.essence += rd.essenceEarned;
    S.shop(r); r.shopState = null;
    if (i === CRIB_ACTS * CRIB_ROUNDS - 1) won = true;
    if (r.advance()) { won = true; break; }
  }
  rounds.won = won;
  return rounds;
}

const lead = (c) => { let b = null; for (const k of CATS) if (b === null || c[k] > c[b]) b = k; return c[b] > 0 ? b : "none"; };
const shares = (c) => { const t = CATS.reduce((a, k) => a + c[k], 0) || 1; return CATS.map((k) => c[k] / t); };

const MODES = (process.env.MODES || "on,off").split(",");
const feel = {};
for (const m of MODES) feel[m] = { trans: 0, diff: 0, l1: 0, runs: 0, won: 0 };
const per = {};   // twist id -> {rounds, won}
const DECKS = ["pip", "thump", "clover", "facet"];
for (let i = 0; i < N; i++) {
  const seed = SEED0 + i, deck = DECKS[i % 4];
  for (const mode of MODES) {
    const rounds = play(deck, seed, mode);
    feel[mode].runs++; if (rounds.won) feel[mode].won++;
    const plain = rounds.filter((x) => !x.boss);
    for (let j = 1; j < plain.length; j++) {
      const a = plain[j - 1].cat, b = plain[j].cat;
      feel[mode].trans++;
      if (lead(a) !== lead(b)) feel[mode].diff++;
      const sa = shares(a), sb = shares(b);
      feel[mode].l1 += sa.reduce((t, v, k) => t + Math.abs(v - sb[k]), 0);
    }
    if (mode === "on") for (const x of rounds) if (x.twist) {
      per[x.twist] = per[x.twist] || { rounds: 0, won: 0 };
      per[x.twist].rounds++; if (x.won) per[x.twist].won++;
    }
  }
}
const out = { runs: N, seeds: `${SEED0}..${SEED0 + N - 1}` };
for (const m of MODES) {
  const f = feel[m];
  out[`twists_${m}`] = { transitions: f.trans, lead_changes_pct: +(100 * f.diff / Math.max(1, f.trans)).toFixed(1),
                         mean_l1: +(f.l1 / Math.max(1, f.trans)).toFixed(3),
                         runs_cleared_pct: +(100 * f.won / Math.max(1, f.runs)).toFixed(1) };
}
out.per_twist = {};
for (const k in per) out.per_twist[k] = { rounds: per[k].rounds, clear_pct: +(100 * per[k].won / per[k].rounds).toFixed(1) };
console.log(JSON.stringify(out, null, 1));
