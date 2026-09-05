/* The cascade. This is the payoff moment, so it gets the most work:
   - the cards that scored each sub-total light up as it's counted
   - the running number climbs digit by digit with a rising pentatonic tick
   - the multiplier lands with a slam, screen shake and a pip burst
   - the Meldling reacts to how big it was */

/* Score tiers — a hand at 3x pace must FEEL different from one at pace. */
const TIERS = [
  { at: 0.00, word: "",            cls: "",      pips: 0,  chord: [261.63, 329.63] },
  { at: 0.55, word: "SOLID",       cls: "t-ok",  pips: 12, chord: [261.63, 329.63, 392] },
  { at: 1.20, word: "STRONG",      cls: "t-good",pips: 18, chord: [261.63, 329.63, 392, 523.25] },
  { at: 2.00, word: "HUGE",        cls: "t-big", pips: 26, chord: [261.63, 392, 523.25, 659.25] },
  { at: 3.20, word: "MASSIVE",     cls: "t-max", pips: 36, chord: [329.63, 523.25, 659.25, 783.99, 1046.5] },
];
function tierFor(ratio) {
  let t = TIERS[0];
  for (const x of TIERS) if (ratio >= x.at) t = x;
  return t;
}

/* Animation speed — Balatro ships a global speed control because a long run is
   mostly waiting on the same animation. With ~100 counts per run, so do we. */
const Speed = {
  levels: [1, 2, 4],
  i: 0,
  get k() { return this.levels[this.i]; },
  ms(t) { return Math.max(24, Math.round(t / this.k)); },
  cycle() { this.i = (this.i + 1) % this.levels.length; return this.k; },
  label() { return `${this.k}×`; },
};

const Juice = {
  /* ---------------------------------------------------------- particles */
  burst(x, y, count = 14, colors = ["gold", "white", "blue"]) {
    for (let i = 0; i < count; i++) {
      const p = document.createElement("div");
      p.className = "pip";
      p.style.backgroundImage = `url(${ART.pips[colors[i % colors.length]]})`;
      p.style.left = x + "px";
      p.style.top = y + "px";
      document.body.appendChild(p);
      const ang = (Math.PI * 2 * i) / count + Math.random() * 0.5;
      const dist = 60 + Math.random() * 130;
      const dur = 480 + Math.random() * 420;
      p.animate([
        { transform: "translate(-50%,-50%) scale(1.4)", opacity: 1 },
        { transform: `translate(${Math.cos(ang) * dist - 50}%, ${Math.sin(ang) * dist + 120}%) scale(0.4)`, opacity: 0 },
      ], { duration: dur, easing: "cubic-bezier(.2,.7,.3,1)" });
      setTimeout(() => p.remove(), dur);
    }
  },

  shake(strength = 6, dur = 260) {
    const a = document.getElementById("app");
    if (!a) return;
    const frames = [];
    for (let i = 0; i < 7; i++) {
      const s = strength * (1 - i / 7);
      frames.push({ transform: `translate(${(Math.random() * 2 - 1) * s}px, ${(Math.random() * 2 - 1) * s}px)` });
    }
    frames.push({ transform: "translate(0,0)" });
    a.animate(frames, { duration: dur, easing: "ease-out" });
  },

  /* Count a number up rather than snapping to it. */
  countTo(node, from, to, ms, onTick) {
    const t0 = performance.now();
    const tick = (t) => {
      const k = Math.min(1, (t - t0) / ms);
      const eased = 1 - Math.pow(1 - k, 3);
      const v = Math.round(from + (to - from) * eased);
      node.textContent = String(v);
      if (onTick) onTick(v);
      if (k < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  },

  flashNumber(node) {
    node.classList.remove("pulse");
    void node.offsetWidth;
    node.classList.add("pulse");
  },
};

/* ---------------------------------------------------------------- cascade */
function cribCascade(res, keepRank, hand, starter, scoreBefore, done) {
  const rd = Cb.round, run = Cb.run;
  screen("cascade");
  const c = el("div", "col center cascadewrap");

  // goal and items stay on screen while the count happens
  c.append(cribHUD(rd, run, { shownScore: scoreBefore }));
  const charms = cribCharmRow(run);
  charms.classList.add("cascadecharms");
  c.append(charms);

  // the Meldling watches the count and reacts to the slam
  const critter = creatureEl(run.meldling, "idle", 3);
  critter.id = "cascadeCritter";
  c.append(critter);

  // the counted hand stays on screen so highlights mean something
  const row = el("div", "row center cascadecards");
  const all = hand.concat([starter]);
  // scale to fit however many cards were counted (Facet keeps 5, so 6 total)
  const cs = all.length >= 6 ? 1.0 : all.length === 5 ? 1.15 : 1.3;
  all.forEach((card, i) => {
    const n = cardEl(card, cs);
    n.classList.add("ccard");
    if (i === all.length - 1) n.classList.add("starter");
    n.dataset.k = card.rank + card.suit;
    row.append(n);
  });
  c.append(row);

  const total = el("h1", "bignum", "0");
  c.append(total);

  const list = el("div", "col tight cascadelist");
  c.append(list);

  const multLine = el("div", "multline", "");
  c.append(multLine);
  const spd = el("button", "speedbtn", `▸ ${Speed.label()}`);
  spd.onclick = (e) => { e.stopPropagation(); Speed.cycle(); spd.textContent = `▸ ${Speed.label()}`; };
  c.append(spd);
  root().append(c);

  const cardNodes = {};
  row.querySelectorAll(".ccard").forEach((n) => { (cardNodes[n.dataset.k] ||= []).push(n); });

  const lightUp = (cards, kind) => {
    row.querySelectorAll(".ccard").forEach((n) => n.classList.remove("lit", "k-fifteen", "k-pair", "k-run", "k-flush", "k-nobs"));
    for (const card of cards) {
      const key = card.rank + card.suit;
      (cardNodes[key] || []).forEach((n) => { n.classList.add("lit", "k-" + kind); });
    }
  };

  let running = 0;
  const evs = res.events.slice();
  let idx = 0;

  /* Ramp level blends how much you've banked against how far through the count we
     are — so a monster hand audibly climbs higher than a weak one. */
  const pace = Math.max(1, rd.target / (CRIB_DEALS + rd.mods.dealBonus));
  const evCount = Math.max(3, res.events.length + (res.levelBonus ? 1 : 0));
  const rampLevel = () =>
    Math.min(1, (running / (pace * 2.6)) * 0.7 + (idx / evCount) * 0.3);
  Audio16.rampStart();
  Audio16.rampTo(0.05, 0.2);

  const step = () => {
    if (!evs.length) {
      if (!res.events.length) {
        // nothing scored — say so rather than silently sliding to the slam
        const rowEl = el("div", "casrow k-zero");
        rowEl.append(el("div", "casicon lvicon"), el("span", "grow", "No score"),
          el("span", "casval", "0"));
        list.append(rowEl);
        Audio16.sfx("bad");
      }
      return levelStep();
    }
    const e = evs.shift();
    lightUp(e.cards, e.kind);

    const rowEl = el("div", "casrow k-" + e.kind);
    const icon = el("div", "casicon");
    icon.style.backgroundImage = `url(${ART.icons[e.kind] || ART.icons.fifteen})`;
    rowEl.append(icon, el("span", "grow", e.label), el("span", "casval", `+${e.points}`));
    list.append(rowEl);
    if (list.children.length > 6) list.firstChild.remove();

    const from = running;
    running += e.points;
    Juice.countTo(total, from, running, Speed.ms(220));
    Juice.flashNumber(total);
    if (res.isCrib) Audio16.cribTick(idx++); else Audio16.tick(idx++, e.kind);
    Audio16.rampTo(rampLevel());
    setTimeout(step, Speed.ms(380));
  };

  const gildStep = () => {
    if (!res.gildBonus) return cutStep();
    const rowEl = el("div", "casrow k-gild");
    rowEl.append(el("div", "casicon gildicon"), el("span", "grow", "Gilded cards"),
      el("span", "casval", `+${res.gildBonus}`));
    list.append(rowEl);
    Audio16.voice(1245, 0.16, { gain: 0.09, type: "square", detune: 12, send: 0.4 });
    setTimeout(cutStep, Speed.ms(400));
  };

  const cutStep = () => {
    if (!res.cutGain) return suppressStep();
    const rowEl = el("div", "casrow k-cut");
    const ic = el("div", "casicon cuticon");
    rowEl.append(ic, el("span", "grow", "From the cut"),
      el("span", "casval", `+${res.cutGain}`));
    list.append(rowEl);
    Audio16.voice(660, 0.14, { gain: 0.09, type: "square", detune: 9, send: 0.35 });
    setTimeout(suppressStep, Speed.ms(420));
  };

  const suppressStep = () => {
    if (!res.suppressed) return chainStep();
    const rowEl = el("div", "casrow k-block");
    rowEl.append(el("div", "casicon blockicon"),
      el("span", "grow", `${res.suppressedBy} blocked`),
      el("span", "casval", `−${res.suppressed}`));
    list.append(rowEl);
    Audio16.sfx("bad");
    Juice.shake(4, 200);
    setTimeout(chainStep, Speed.ms(520));
  };

  const levelStep = () => {
    if (!res.levelBonus) return gildStep();
    const rowEl = el("div", "casrow k-level");
    rowEl.append(el("div", "casicon lvicon"), el("span", "grow", "Category levels"),
      el("span", "casval", `+${res.levelBonus}`));
    list.append(rowEl);
    const from = running;
    running += res.levelBonus;
    Juice.countTo(total, from, running, 260);
    Juice.flashNumber(total);
    Audio16.voice(1046, 0.18, { gain: 0.1, type: "square", detune: 10, send: 0.35 });
    setTimeout(multStep, 460);
  };

  /* Each charm triggers in sequence, chip bouncing, running total climbing —
     this is what teaches players which combinations matter. */
  const chainStep = () => {
    const steps = (res.steps || []).slice();
    if (!steps.length) return multStep();
    multLine.innerHTML = `<span class="mbase">${res.baseOnly}</span>`;
    multLine.classList.add("in");
    let cur = res.baseOnly;
    Juice.countTo(total, running, cur, Speed.ms(240));

    const fire = () => {
      if (!steps.length) return setTimeout(multStep, Speed.ms(360));
      const st = steps.shift();
      charms.querySelectorAll(".charm").forEach((ch) => {
        const label = ch.querySelector(".charmname");
        if (label && label.textContent === st.name) {
          ch.classList.add("firing");
          setTimeout(() => ch.classList.remove("firing"), Speed.ms(420));
        }
      });
      const rowEl = el("div", "casrow k-charm");
      rowEl.append(el("div", "casicon charmicon"), el("span", "grow", st.name),
        el("span", "casval", `+${st.gain}`));
      list.append(rowEl);
      if (list.children.length > 7) list.firstChild.remove();
      Juice.countTo(total, cur, st.total, Speed.ms(260));
      Juice.flashNumber(total);
      cur = st.total;
      multLine.innerHTML =
        `<span class="mbase">${st.base}</span><span class="mx">×</span>` +
        `<span class="mmult">${st.mult.toFixed(2)}</span>`;
      Audio16.tick(idx++, "pair");
      Audio16.rampTo(Math.min(1, cur / (pace * 2.2)));
      setTimeout(fire, Speed.ms(300));
    };
    setTimeout(fire, Speed.ms(300));
  };

  const multStep = () => {
    row.querySelectorAll(".ccard").forEach((n) => n.classList.add("lit", "k-all"));
    // each contributing charm lights up in turn, so you SEE what earned it
    res.fired.forEach((name, i) => {
      setTimeout(() => {
        charms.querySelectorAll(".charm").forEach((ch) => {
          const label = ch.querySelector(".charmname");
          if (label && label.textContent === name) {
            ch.classList.add("firing");
            setTimeout(() => ch.classList.remove("firing"), 420);
          }
        });
        Audio16.voice(880 + i * 110, 0.1, { gain: 0.07, type: "square", send: 0.3 });
      }, i * 130);
    });

    multLine.innerHTML =
      `<span class="mbase">${res.base}</span><span class="mx">×</span>` +
      `<span class="mmult">${res.mult.toFixed(2)}</span>`;
    multLine.classList.add("in");
    Audio16.rampTo(Math.min(1, Math.max(rampLevel(), res.total / (pace * 1.6))), 0.5);

    setTimeout(() => {
      const pace = rd.target / (CRIB_DEALS + rd.mods.dealBonus);
      const ratio = res.total / Math.max(1, pace);
      const tier = tierFor(ratio);
      const perfect = res.base >= 29 && !res.levelBonus;

      Audio16.rampBurst();
      Audio16.slam(1 + Math.min(2, ratio));
      tier.chord.forEach((f, i) =>
        Audio16.voice(f, 0.7, { gain: 0.075, type: "square", detune: 11,
          delay: 0.06 + i * 0.045, send: 0.45 }));
      Juice.shake(5 + Math.min(16, ratio * 5), 320);
      const r = total.getBoundingClientRect();
      Juice.burst(r.left + r.width / 2, r.top + r.height / 2,
        16 + tier.pips, tier.cls === "t-max" ? ["gold", "green", "white"] : ["gold", "white", "blue"]);
      Juice.countTo(total, running, res.total, 620);
      // the goal bar fills as the points land — the payoff and the goal, together
      const hudScore = document.getElementById("hudScore");
      const hudBar = document.getElementById("hudBar");
      if (hudScore) Juice.countTo(hudScore, scoreBefore, rd.score, 640);
      Audio16.setProximity(Math.min(1, rd.score / rd.target));
      if (hudBar) {
        const fill = hudBar.querySelector(".fill");
        if (fill) {
          fill.style.transition = "width .64s cubic-bezier(.2,.8,.3,1)";
          fill.style.width = Math.min(100, 100 * rd.score / rd.target) + "%";
          if (rd.score >= rd.target) fill.classList.add("green");
        }
      }
      total.classList.add("huge");
      if (tier.cls) total.classList.add(tier.cls);
      Juice.flashNumber(total);

      // the creature reacts
      const cr = document.getElementById("cascadeCritter");
      if (cr) playAnim(cr, run.meldling, ratio >= 0.55 ? "attack" : "hurt", 3);

      if (tier.word) {
        const w = el("h2", "tierword " + tier.cls, tier.word);
        c.append(w);
      }
      if (perfect) {
        c.append(el("h2", "tierword t-max", "TWENTY-NINE"));
        Audio16.sfx("milestone");
        Juice.burst(window.innerWidth / 2, window.innerHeight * 0.35, 44, ["gold", "white", "green"]);
      }



      setTimeout(() => {
        // coaching: what the best keep would have scored
        // coach on the DECISION, not on hindsight: how did your keep rank by EV?
        if (keepRank && keepRank.rank) {
          const good = keepRank.rank === 1;
          const near = keepRank.rank <= 3;
          c.append(el("p", "small " + (good ? "green" : near ? "gold" : "dim"),
            good ? "Best possible keep."
              : `Keep ranked ${keepRank.rank} of ${keepRank.of} by expected value` +
                (keepRank.best ? `  (best expected ${keepRank.best.ev.toFixed(1)})` : "")));
        }

        // "I'd have lost without that" — say it out loud
        if (res.crossedTarget) {
          const cutSaved = res.scoreBefore + res.handOnly < rd.target;
          let line = null, cls = "t-good";
          if (cutSaved) { line = "THE CUT SAVED IT"; cls = "t-big"; }
          else {
            let bestCharm = null;
            for (const k in (res.contrib || {}))
              if (res.scoreBefore + res.total - res.contrib[k] < rd.target &&
                  (!bestCharm || res.contrib[k] > res.contrib[bestCharm])) bestCharm = k;
            if (bestCharm) { line = `${bestCharm.toUpperCase()} SAVED IT`; cls = "t-big"; }
          }
          if (res.wasFinalDeal && !line) { line = "ON THE LAST DEAL"; cls = "t-good"; }
          if (line) {
            const w = el("h2", "clutch " + cls, line);
            c.append(w);
            Audio16.sfx("milestone");
            Juice.burst(window.innerWidth / 2, window.innerHeight * 0.42, 30,
              ["gold", "white", "green"]);
            Juice.shake(8, 320);
          }
        }

        // did we just cross the target?
        if (rd.score >= rd.target && !rd.milestoneShown) {
          rd.milestoneShown = true;
          const m = el("h2", "title green", "TARGET MET");
          c.append(m);
          Audio16.sfx("milestone");
          Juice.burst(window.innerWidth / 2, window.innerHeight * 0.4, 26, ["gold", "green", "white"]);
        }
        c.append(btn("CONTINUE", done, "big"));
      }, 720);
    }, 620);
  };

  setTimeout(step, Speed.ms(420));
}
