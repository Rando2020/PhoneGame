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

/* ---- pass 20: three ways for a round to push back against the build ----
   Applied on plain rounds that would carry a twist (replacing it), from round
   PB_FROM of the run on (the build needs history). Tunables by env:
   (a) shortage: the run's best category so far scores SH_SCALE this round;
       the round's target x SH_TARGET.
   (b) contract: name the run's weakest category; score CT_N base points from
       it this round for CT_GLIM Glim. The player chases it: its keep values
       that category x (1 + CT_W) (the real count is unchanged).
   (c) bench: the charm that has added the most so far sits this round out;
       the round's target x BN_TARGET.                                       */
const E = process.env;
const PB_FROM = +(E.PB_FROM || 2);
const SH_SCALE = +(E.SH_SCALE || 0.5), SH_TARGET = +(E.SH_TARGET || 1.0);
const CT_N = +(E.CT_N || 8), CT_GLIM = +(E.CT_GLIM || 6), CT_W = +(E.CT_W || 1.0);
const BN_TARGET = +(E.BN_TARGET || 1.0);
const rules0 = CribRun.prototype.rules;
CribRun.prototype.rules = function () {
  const r = rules0.call(this);
  if (this._extra) Object.assign(r, this._extra);
  return r;
};
const target0 = CribRun.prototype.target;
CribRun.prototype.target = function () { return Math.round(target0.call(this) * (this._tmul || 1)); };
// the contract chase: the strong player's keep sees the named category weighted
const bestEV0 = CribRound.prototype.bestKeepEV;
CribRound.prototype.bestKeepEV = function () {
  if (!this.run._chase) return bestEV0.call(this);
  const m = Object.assign({}, this.mods, { catScale: Object.assign({}, this.mods.catScale || {}, { [this.run._chase]: 1 + CT_W }) });
  const C = require(path.join(WEB, "cribbage.js"));
  return C.keepOptionsEV(this.dealt, this.stock, this.keepCount(), m)[0];
};
// charm credit so far (for bench): read-only on commit results
const commit1 = CribRound.prototype.commit;
CribRound.prototype.commit = function (...a) {
  const res = commit1.apply(this, a);
  if (res && res.contrib) { const t = this.run._credit = this.run._credit || {}; for (const k in res.contrib) t[k] = (t[k] || 0) + res.contrib[k]; }
  return res;
};

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
    // pass 20 designs: on a plain twist round from PB_FROM on, replace the twist
    r._extra = null; r._tmul = 1; r._chase = null;
    let benched = null, contract = null;
    const plainTw = !boss && r.twist() && i + 1 >= PB_FROM;
    if (plainTw && (mode === "shortage" || mode === "contract" || mode === "bench")) {
      r.twistPlan[`${r.act}-${r.round}`] = null;        // no twist this round
      let hi = null, lo = null;
      for (const k of CATS) { if (hi === null || sofar[k] > sofar[hi]) hi = k; if (lo === null || sofar[k] < sofar[lo]) lo = k; }
      if (mode === "shortage") { r._extra = { catScale: { [hi]: SH_SCALE } }; r._tmul = SH_TARGET; }
      if (mode === "contract") { contract = lo; r._chase = lo; }
      if (mode === "bench" && r.charms.length) {
        let top = null;
        for (const c of r.charms) { const v = (r._credit || {})[c.name] || 0; if (top === null || v > ((r._credit || {})[top.name] || 0)) top = c; }
        benched = top; r.charms = r.charms.filter((c) => c !== top); r._tmul = BN_TARGET;
      }
    }
    if (mode === "aware" && r.twist()) {        // a plain twist round: re-aim it
      let low = null;
      for (const k of CATS) if (low === null || sofar[k] < sofar[low]) low = k;
      r.twistPlan[`${r.act}-${r.round}`] = AWARE[low];
      aware = true;
    }
    const tw = r.twist();
    const rd = S.playRound(r, SKILL);
    if (benched) r.charms.push(benched);              // back after its round
    r._extra = null; r._tmul = 1; r._chase = null;
    const cat = rd._cat || { fifteen: 0, pair: 0, run: 0, flush: 0 };
    if (contract && rd.won && cat[contract] >= CT_N) r.essence += CT_GLIM;
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
const SKILL = process.env.SKILL || "best";
const feel = {};
for (const m of MODES) feel[m] = { trans: 0, diff: 0, l1: 0, runs: 0, won: 0, reachSp: 0 };
const per = {};   // twist id -> {rounds, won}
const DECKS = ["pip", "thump", "clover", "facet"];
for (let i = 0; i < N; i++) {
  const seed = SEED0 + i, deck = DECKS[i % 4];
  for (const mode of MODES) {
    const rounds = play(deck, seed, mode);
    feel[mode].runs++; if (rounds.won) feel[mode].won++;
    if (rounds.length >= CRIB_ROUNDS) feel[mode].reachSp++;
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
                         runs_cleared_pct: +(100 * f.won / Math.max(1, f.runs)).toFixed(1),
                         reach_first_spoiler_pct: +(100 * f.reachSp / Math.max(1, f.runs)).toFixed(1) };
}
out.per_twist = {};
for (const k in per) out.per_twist[k] = { rounds: per[k].rounds, clear_pct: +(100 * per[k].won / per[k].rounds).toFixed(1) };
console.log(JSON.stringify(out, null, 1));
