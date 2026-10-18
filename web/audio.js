/* Meldlings — 16-bit audio engine.
   Everything synthesised in WebAudio: zero bytes, and the SNES-era character
   comes from detuned pulse pairs, a triangle bass, noise percussion and a
   delay send. Also runs a small tracker for looping music. */

const Audio16 = (() => {
  let ctx = null, master = null, musicGain = null, sfxGain = null, rampGain = null, delayNode = null;
  let noiseBuf = null;
  let started = false;

  function init() {
    if (ctx) return ctx;
    ctx = new (window.AudioContext || window.webkitAudioContext)();

    master = ctx.createGain();
    master.gain.value = 0.85;
    // soft limiter so stacked cascade hits never clip
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -12;
    comp.ratio.value = 6;
    comp.attack.value = 0.003;
    comp.release.value = 0.15;
    master.connect(comp);
    comp.connect(ctx.destination);

    musicGain = ctx.createGain(); musicGain.gain.value = 0.34; musicGain.connect(master);
    sfxGain = ctx.createGain();   sfxGain.gain.value = 1.0;    sfxGain.connect(master);
    /* The build-up lives on its own quiet bus and is ducked every time a number
       ticks. The count is the star; the ramp is the room it happens in. */
    rampGain = ctx.createGain();  rampGain.gain.value = 0.30;  rampGain.connect(master);

    // shared delay send — the "space" of the era
    delayNode = ctx.createDelay(1.0);
    delayNode.delayTime.value = 0.18;
    const fb = ctx.createGain(); fb.gain.value = 0.28;
    const wet = ctx.createGain(); wet.gain.value = 0.30;
    delayNode.connect(fb); fb.connect(delayNode);
    delayNode.connect(wet); wet.connect(master);

    const n = ctx.sampleRate * 0.5;
    noiseBuf = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    return ctx;
  }

  function unlock() {
    init();
    if (ctx.state === "suspended") ctx.resume();
    started = true;
  }

  const now = () => (ctx ? ctx.currentTime : 0);

  /* One synth voice. detune > 0 spawns a second oscillator for width. */
  function voice(freq, dur, o = {}) {
    if (!ctx) init();
    const t0 = (o.at || now()) + (o.delay || 0);
    const type = o.type || "square";
    const gain = o.gain ?? 0.14;
    const atk = o.attack ?? 0.004;
    const dec = o.decay ?? dur;
    const dest = o.bus || sfxGain;

    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + atk);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + atk + dec);
    g.connect(dest);
    if (o.send) { const s = ctx.createGain(); s.gain.value = o.send; g.connect(s); s.connect(delayNode); }

    const mk = (cents) => {
      const osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, t0);
      if (o.slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(20, o.slideTo), t0 + dur);
      if (cents) osc.detune.value = cents;
      if (o.vibrato) {
        const lfo = ctx.createOscillator(), la = ctx.createGain();
        lfo.frequency.value = o.vibrato.hz || 5.5;
        la.gain.value = o.vibrato.cents || 14;
        lfo.connect(la); la.connect(osc.detune);
        lfo.start(t0); lfo.stop(t0 + dur + 0.1);
      }
      osc.connect(g);
      osc.start(t0);
      osc.stop(t0 + atk + dec + 0.02);
    };
    mk(0);
    if (o.detune) mk(o.detune);
  }

  function noise(dur, o = {}) {
    if (!ctx) init();
    const t0 = (o.at || now()) + (o.delay || 0);
    const src = ctx.createBufferSource();
    src.buffer = noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = o.filter || "highpass";
    f.frequency.value = o.freq || 1800;
    if (o.sweepTo) f.frequency.exponentialRampToValueAtTime(o.sweepTo, t0 + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(o.gain ?? 0.16, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(f); f.connect(g); g.connect(o.bus || sfxGain);
    if (o.send) { const s = ctx.createGain(); s.gain.value = o.send; g.connect(s); s.connect(delayNode); }
    src.start(t0);
    src.stop(t0 + dur + 0.02);
  }

  function kick(o = {}) {
    const t0 = (o.at || now());
    voice(140, 0.16, { at: t0, type: "sine", slideTo: 46, gain: o.gain ?? 0.5, decay: 0.15, bus: o.bus });
  }
  function snare(o = {}) {
    const t0 = (o.at || now());
    noise(0.14, { at: t0, freq: 1400, gain: (o.gain ?? 0.2), bus: o.bus });
    voice(190, 0.1, { at: t0, type: "triangle", gain: 0.1, decay: 0.09, bus: o.bus });
  }
  function hat(o = {}) {
    noise(0.045, { at: o.at || now(), freq: 7000, gain: o.gain ?? 0.075, bus: o.bus });
  }

  /* ------------------------------------------------------------- note names */
  const NOTE = { c: 0, "c#": 1, d: 2, "d#": 3, e: 4, f: 5, "f#": 6, g: 7, "g#": 8, a: 9, "a#": 10, b: 11 };
  function hz(name) {
    const m = /^([a-g]#?)(-?\d)$/.exec(name.toLowerCase());
    if (!m) return 440;
    return 440 * Math.pow(2, ((+m[2] + 1) * 12 + NOTE[m[1]] - 69) / 12);
  }

  /* ------------------------------------------------------------- music */
  /* THE MELDLINGS THEME.
     One motif, written once as scale degrees, and transformed per context — key,
     mode, tempo, rhythm, instrumentation. Every Act is recognisably the same tune,
     but it deepens as the run does. Tracks are now 8 bars (an A and a B phrase)
     instead of 4, so the loop stops announcing itself. */

  const MODES = {
    ionian:     [0, 2, 4, 5, 7, 9, 11],
    dorian:     [0, 2, 3, 5, 7, 9, 10],
    phrygian:   [0, 1, 3, 5, 7, 8, 10],
    lydian:     [0, 2, 4, 6, 7, 9, 11],
    mixolydian: [0, 2, 4, 5, 7, 9, 10],
    aeolian:    [0, 2, 3, 5, 7, 8, 10],
  };
  const PITCH = ["c","c#","d","d#","e","f","f#","g","g#","a","a#","b"];

  /* The motif. A rising question (bars 1-2), then a falling answer (bars 3-4).
     null is a rest; numbers are scale degrees. */
  const MOTIF_A = [0, null, 2, 4,   null, 4, 3, 2,   1, null, 3, 5,   7, null, null, null];
  const MOTIF_B = [7, null, 5, 4,   null, 3, 2, 1,   0, null, 1, 2,   0, null, null, null];

  function degToMidi(d, root, mode) {
    const m = MODES[mode];
    const oct = Math.floor(d / 7);
    const i = ((d % 7) + 7) % 7;
    return root + oct * 12 + m[i];
  }
  const nm = (midi) => PITCH[((midi % 12) + 12) % 12] + (Math.floor(midi / 12) - 1);

  /* How the motif is phrased in each context. */
  function phraseLead(motif, P) {
    const out = [];
    for (let i = 0; i < motif.length; i++) {
      let d = motif[i];
      if (d === null) { out.push("."); continue; }
      if (P.lead === "sparse" && i % 4 !== 0) { out.push("."); continue; }
      if (P.lead === "fragment" && i >= 8) { out.push("."); continue; }
      if (P.lead === "sync" && (i % 8 === 5 || i % 8 === 6)) { out.push("."); continue; }
      out.push(nm(degToMidi(d, P.root + 12 * (P.leadOct || 0), P.mode)));
    }
    return out;
  }

  const DRUMS = {
    none:   ". . . . . . . .",
    soft:   ". . h . . . h .",
    sparse: "k . . . . . h .",
    drive:  "k . h s . h k x",
    march:  "k . s . k . s .",
    heavy:  "k h s h k h s x",
    fill:   "k . h s h h s x",
  };

  /* Build an 8-bar track from the motif and a profile. */
  function compose(P) {
    const bars = 8;
    const lead = [], bass = [], arp = [], pad = [], drums = [];
    const a = phraseLead(MOTIF_A, P), b = phraseLead(MOTIF_B, P);
    // A A' B B' — the second A is lifted a step, so the repeat feels like a turn
    const lifted = phraseLead(MOTIF_A.map((d) => (d === null ? null : d + (P.lift || 0))), P);
    const leadSteps = a.concat(lifted, b, b);
    for (let bar = 0; bar < bars; bar++) {
      const chunk = leadSteps.slice(bar * 8, bar * 8 + 8);
      // call and response: the lead drops out on alternate bars
      if (P.lead === "call" && bar % 2 === 1) lead.push(". . . . . . . .");
      else lead.push(chunk.join(" "));

      const r = P.chords[bar % P.chords.length];
      const R = degToMidi(r, P.root - 24, P.mode);
      const F = degToMidi(r + 4, P.root - 24, P.mode);
      bass.push(P.bass === "pulse"
        ? `${nm(R)} ${nm(R)} . ${nm(R)} ${nm(F)} . ${nm(R + 12)} .`
        : `${nm(R)} . . . ${nm(F)} . . .`);

      if (P.arp) {
        const t = [0, 2, 4, 7, 4, 2, 0, 2].map((k) => nm(degToMidi(r + k, P.root, P.mode)));
        arp.push(P.lead === "call" && bar % 2 === 0 ? ". . . . . . . ." : t.join(" "));
      } else arp.push(". . . . . . . .");

      pad.push(P.pad ? `${nm(degToMidi(r, P.root - 12, P.mode))} - - - - - - -` : ". . . . . . . .");

      // a fill on the last bar so the loop point lands rather than resets
      drums.push(bar === bars - 1 && P.drums !== "none" ? DRUMS.fill : DRUMS[P.drums]);
    }
    return { bpm: P.bpm, bars, lead, bass, arp, pad, drums };
  }

  /* One theme, many rooms. Roots are MIDI note numbers. */
  const PROFILES = {
    menu:    { root: 57, mode: "aeolian",    bpm: 88,  chords: [0, 5, 3, 4], drums: "soft",
               lead: "plain",    bass: "held",  arp: false, pad: true },
    shop:    { root: 53, mode: "lydian",     bpm: 76,  chords: [0, 1, 0, 4], drums: "none",
               lead: "sparse",   bass: "held",  arp: true,  pad: true },
    act1:    { root: 62, mode: "dorian",     bpm: 112, chords: [0, 3, 4, 0], drums: "sparse",
               lead: "plain",    bass: "held",  arp: true,  pad: false, lift: 1 },
    act2:    { root: 64, mode: "aeolian",    bpm: 120, chords: [0, 5, 3, 4], drums: "drive",
               lead: "plain",    bass: "pulse", arp: true,  pad: false, lift: 1 },
    act3:    { root: 66, mode: "dorian",     bpm: 126, chords: [0, 3, 5, 4], drums: "drive",
               lead: "plain",    bass: "pulse", arp: true,  pad: true,  lift: 2, leadOct: 0 },
    act4:    { root: 57, mode: "aeolian",    bpm: 132, chords: [0, 5, 6, 4], drums: "drive",
               lead: "sync",     bass: "pulse", arp: true,  pad: true,  lift: 2, leadOct: 1 },
    act5:    { root: 59, mode: "phrygian",   bpm: 138, chords: [0, 1, 5, 4], drums: "heavy",
               lead: "sync",     bass: "pulse", arp: true,  pad: true,  lift: 2, leadOct: 0 },
    boss:    { root: 64, mode: "phrygian",   bpm: 150, chords: [0, 1, 0, 6], drums: "heavy",
               lead: "plain",    bass: "pulse", arp: true,  pad: false, lift: 1 },
    play:    { root: 60, mode: "dorian",     bpm: 118, chords: [0, 4, 0, 3], drums: "march",
               lead: "call",     bass: "pulse", arp: true,  pad: false },
    endless: { root: 61, mode: "aeolian",    bpm: 144, chords: [0, 6, 5, 4], drums: "heavy",
               lead: "fragment", bass: "pulse", arp: true,  pad: true,  lift: 2, leadOct: 0 },
  };

  const TRACKS = {};
  for (const k in PROFILES) TRACKS[k] = compose(PROFILES[k]);
  TRACKS.run = TRACKS.act1;              // legacy name still resolves

  let musicTimer = null, musicName = null, step = 0, nextTime = 0;

  function playMusic(name) {
    init();
    if (musicName === name) return;
    stopMusic();
    musicName = name;
    const T = TRACKS[name];
    if (!T) return;
    step = 0;
    nextTime = now() + 0.08;
    const stepDur = (60 / T.bpm) / 2;             // eighth notes
    const total = T.bars * 8;

    const tokens = (row, i) => (row ? row[Math.floor(i / 8) % row.length].split(/\s+/)[i % 8] : ".");

    const schedule = () => {
      if (musicName !== name) return;
      while (nextTime < now() + 0.35) {
        const i = step % total;
        const at = nextTime;
        const L = tokens(T.lead, i), B = tokens(T.bass, i),
              D = tokens(T.drums, i), A = tokens(T.arp, i), P = tokens(T.pad, i);
        if (L && L !== "." && L !== "-")
          voice(hz(L), stepDur * 1.7, { at, type: "square", gain: 0.075, detune: 9,
            decay: stepDur * 1.7, send: 0.28, bus: musicGain, vibrato: { hz: 5, cents: 10 } });
        if (B && B !== "." && B !== "-")
          voice(hz(B), stepDur * 1.5, { at, type: "triangle", gain: 0.19, decay: stepDur * 1.4, bus: musicGain });
        if (A && A !== "." && A !== "-")
          voice(hz(A), stepDur * 0.8, { at, type: "square", gain: 0.035, send: 0.2, bus: musicGain });
        if (P && P !== "." && P !== "-")
          voice(hz(P), stepDur * 7, { at, type: "sawtooth", gain: 0.026, detune: 12,
            attack: 0.15, decay: stepDur * 7, bus: musicGain });
        if (D === "k") kick({ at, bus: musicGain, gain: 0.34 });
        else if (D === "s") snare({ at, bus: musicGain, gain: 0.13 });
        else if (D === "h") hat({ at, bus: musicGain, gain: 0.05 });
        else if (D === "x") { snare({ at, bus: musicGain, gain: 0.13 }); hat({ at, bus: musicGain, gain: 0.05 }); }
        nextTime += stepDur;
        step++;
      }
      musicTimer = setTimeout(schedule, 60);
    };
    schedule();
  }

  function stopMusic() {
    musicName = null;
    if (musicTimer) clearTimeout(musicTimer);
    musicTimer = null;
  }

  /* Music proximity: the closer you are to the target, the more the track opens.
     A closed filter at 10% and a bright, wide one at 99% carries the whole round's
     tension for almost nothing. */
  let musicFilter = null, musicProx = 0;
  function ensureMusicFilter() {
    if (musicFilter || !ctx) return musicFilter;
    musicFilter = ctx.createBiquadFilter();
    musicFilter.type = "lowpass";
    musicFilter.frequency.value = 1400;
    musicFilter.Q.value = 0.8;
    musicGain.disconnect();
    musicGain.connect(musicFilter);
    musicFilter.connect(master);
    return musicFilter;
  }
  function setProximity(p) {
    init();
    const f = ensureMusicFilter();
    if (!f) return;
    const L = Math.max(0, Math.min(1, p));
    musicProx = L;
    const t = now();
    // 1.2kHz when you're nowhere near, 16kHz when you're on the line
    f.frequency.linearRampToValueAtTime(1200 + 14800 * Math.pow(L, 1.4), t + 0.5);
    f.Q.linearRampToValueAtTime(0.8 + 2.4 * L, t + 0.5);
    musicGain.gain.linearRampToValueAtTime(0.30 + 0.10 * L, t + 0.5);
  }

  /* The Crib is a different kind of event, so it gets a different voice:
     lower, rounder, plucked rather than struck. */
  function cribTick(index) {
    const semi = [0, 3, 5, 7, 10, 12, 15, 17][Math.min(index, 7)];
    const f = 196 * Math.pow(2, semi / 12);
    duckRamp(0.35, 0.09);
    voice(f, 0.34, { type: "triangle", gain: 0.15, detune: 5, decay: 0.32, send: 0.4 });
    voice(f * 2, 0.16, { type: "sine", gain: 0.07, delay: 0.02 });
    noise(0.02, { freq: 900, filter: "lowpass", gain: 0.05 });
  }

  function duck(amount = 0.4, time = 0.12, hold = 0.6) {
    if (!musicGain) return;
    const t = now();
    musicGain.gain.cancelScheduledValues(t);
    musicGain.gain.setValueAtTime(musicGain.gain.value, t);
    musicGain.gain.linearRampToValueAtTime(0.34 * amount, t + time);
    musicGain.gain.linearRampToValueAtTime(0.34, t + time + hold);
  }

  /* ------------------------------------------------------------- tension ramp */
  /* v2. The first version was a filtered-noise sweep, which reads as WIND rather
     than tension. What actually builds is an accelerating roll — the drum-roll /
     roulette-wheel cue — under a fundamental that climbs in musical steps, with a
     tremolo that speeds up. Three styles, cycled from the settings. */

  const RAMP_STYLES = ["sweep", "roll", "riser", "choir"];
  let rampStyle = 0;
  const cycleRamp = () => { rampStyle = (rampStyle + 1) % RAMP_STYLES.length; return RAMP_STYLES[rampStyle]; };
  const rampStyleName = () => RAMP_STYLES[rampStyle];

  let ramp = null, rollTimer = null;

  function rampStart() {
    init();
    rampKill();
    const t = now();
    const style = RAMP_STYLES[rampStyle];

    const out = ctx.createGain();
    out.gain.value = 1;
    out.connect(rampGain);

    // --- fundamental: climbs in semitone steps, not a smooth glide
    const oscA = ctx.createOscillator(), oscB = ctx.createOscillator();
    oscA.type = style === "choir" ? "triangle" : "sawtooth";
    oscB.type = oscA.type;
    oscB.detune.value = style === "choir" ? 7 : 14;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.setValueAtTime(700, t);
    lp.Q.value = 6;
    const og = ctx.createGain();
    og.gain.setValueAtTime(0.0001, t);
    og.gain.linearRampToValueAtTime(style === "choir" ? 0.030 : 0.018, t + 0.2);

    // --- tremolo that accelerates with the level: the "building" cue
    const lfo = ctx.createOscillator(), lfoG = ctx.createGain();
    lfo.type = "sine";
    lfo.frequency.setValueAtTime(4, t);
    lfoG.gain.value = 0.5;
    lfo.connect(lfoG);
    lfoG.connect(og.gain);

    oscA.connect(lp); oscB.connect(lp); lp.connect(og); og.connect(out);
    const base = style === "riser" ? 90 : 62;
    oscA.frequency.setValueAtTime(base, t);
    oscB.frequency.setValueAtTime(base, t);
    oscA.start(t); oscB.start(t); lfo.start(t);

    ramp = { oscA, oscB, lp, og, lfo, out, base, style, level: 0, period: 200 };

    // --- the original: a bandpass noise bed sweeping upward. Restored as the
    //     default because it reads better in play than the roll did.
    if (style === "sweep") {
      const src = ctx.createBufferSource();
      src.buffer = noiseBuf; src.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = "bandpass"; bp.Q.value = 3.2;
      bp.frequency.setValueAtTime(240, t);
      const ng = ctx.createGain();
      ng.gain.setValueAtTime(0.0001, t);
      ng.gain.linearRampToValueAtTime(0.030, t + 0.18);
      src.connect(bp); bp.connect(ng); ng.connect(out);
      src.start(t);
      ramp.sweepSrc = src; ramp.sweepFilt = bp; ramp.sweepGain = ng;
    }

    // --- the accelerating roll
    if (style === "roll" || style === "riser") {
      const strike = () => {
        if (!ramp) return;
        const L = ramp.level;
        noise(0.028, { freq: 1500 + 2400 * L, gain: 0.016 + 0.022 * L, bus: out });
        if (style === "roll")
          voice(150 + 220 * L, 0.026, { type: "square", gain: 0.010 + 0.016 * L, bus: out });
        rollTimer = setTimeout(strike, ramp.period);
      };
      rollTimer = setTimeout(strike, 160);
    }
  }

  /* level 0..1 */
  function rampTo(level, glide = 0.24) {
    if (!ramp) return;
    const L = Math.max(0, Math.min(1, level));
    const t = now();
    ramp.level = L;

    // fundamental climbs two octaves, quantised to semitones so it stays musical
    const semis = Math.round(L * 24);
    const f = ramp.base * Math.pow(2, semis / 12);
    ramp.oscA.frequency.linearRampToValueAtTime(f, t + glide);
    ramp.oscB.frequency.linearRampToValueAtTime(f, t + glide);
    ramp.lp.frequency.linearRampToValueAtTime(700 + 3400 * L, t + glide);
    ramp.og.gain.linearRampToValueAtTime(
      (ramp.style === "choir" ? 0.030 : 0.018) + 0.036 * L, t + glide);
    // tremolo speeds up 4 -> 26 Hz
    ramp.lfo.frequency.linearRampToValueAtTime(4 + 22 * L, t + glide);
    // roll accelerates between strikes
    ramp.period = Math.max(62, 210 - 148 * L);
    // the sweep bed climbs with the count
    if (ramp.sweepFilt) {
      ramp.sweepFilt.frequency.linearRampToValueAtTime(240 + 5200 * L, t + glide);
      ramp.sweepGain.gain.linearRampToValueAtTime(0.030 + 0.075 * L, t + glide);
    }
  }

  /* Final surge, then cut dead — call immediately before slam(). */
  function rampBurst() {
    if (!ramp) return;
    const t = now();
    const r = ramp;
    ramp = null;
    if (rollTimer) { clearTimeout(rollTimer); rollTimer = null; }

    // a last stutter of strikes, tightening into the impact
    for (let i = 0; i < 7; i++) {
      const d = 0.1 * Math.pow(0.72, i);
      noise(0.03, { at: t + i * d * 1.4, freq: 3000 + i * 500, gain: 0.032, bus: r.out });
    }
    const top = r.base * Math.pow(2, 26 / 12);
    r.oscA.frequency.linearRampToValueAtTime(top, t + 0.16);
    r.oscB.frequency.linearRampToValueAtTime(top, t + 0.16);
    r.lp.frequency.linearRampToValueAtTime(8000, t + 0.16);
    r.og.gain.linearRampToValueAtTime(0.07, t + 0.13);
    r.og.gain.exponentialRampToValueAtTime(0.0001, t + 0.36);
    if (r.sweepFilt) {
      r.sweepFilt.frequency.linearRampToValueAtTime(9000, t + 0.14);
      r.sweepGain.gain.linearRampToValueAtTime(0.13, t + 0.11);
      r.sweepGain.gain.exponentialRampToValueAtTime(0.0001, t + 0.34);
      setTimeout(() => { try { r.sweepSrc.stop(); } catch (e) {} }, 600);
    }
    setTimeout(() => {
      try { r.oscA.stop(); r.oscB.stop(); r.lfo.stop(); } catch (e) {}
    }, 620);
  }

  function rampKill() {
    if (rollTimer) { clearTimeout(rollTimer); rollTimer = null; }
    if (!ramp) return;
    const r = ramp;
    ramp = null;
    try {
      const t = now();
      r.og.gain.cancelScheduledValues(t);
      r.og.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
      if (r.sweepGain) r.sweepGain.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
      setTimeout(() => {
        try { r.oscA.stop(); r.oscB.stop(); r.lfo.stop(); } catch (e) {}
        try { if (r.sweepSrc) r.sweepSrc.stop(); } catch (e) {}
      }, 220);
    } catch (e) {}
  }

  /* ------------------------------------------------------------- sfx */
  const S = {
    click:   () => voice(700, 0.05, { gain: 0.1, decay: 0.05 }),
    select:  () => { voice(880, 0.05, { gain: 0.1 }); voice(1320, 0.05, { gain: 0.05, delay: 0.02 }); },
    deselect:() => voice(560, 0.05, { gain: 0.08 }),
    bad:     () => { voice(300, 0.07, { gain: 0.12, type: "sawtooth" });
                     voice(283, 0.11, { gain: 0.12, type: "sawtooth", delay: 0.06 }); },
    deal:    () => { noise(0.06, { freq: 2600, gain: 0.09 });
                     voice(620, 0.05, { gain: 0.05, type: "triangle" }); },
    flip:    () => { noise(0.05, { freq: 3200, gain: 0.1 });
                     voice(900, 0.06, { gain: 0.06, slideTo: 1400, type: "square" }); },
    cut:     () => { voice(400, 0.1, { gain: 0.12, slideTo: 900, type: "square", send: 0.3 });
                     noise(0.09, { freq: 2200, gain: 0.1 }); },
    toCrib:  () => { noise(0.07, { freq: 1600, gain: 0.08 });
                     voice(330, 0.09, { gain: 0.08, slideTo: 220, type: "triangle" }); },
    buy:     () => [523, 659, 784, 1047].forEach((f, i) =>
                     voice(f, 0.16, { gain: 0.09, delay: i * 0.05, send: 0.3, detune: 8 })),
    level:   () => [392, 523, 659, 784, 1047].forEach((f, i) =>
                     voice(f, 0.2, { gain: 0.085, delay: i * 0.045, type: "square", send: 0.35, detune: 10 })),
    milestone: () => { [659, 880, 1319].forEach((f, i) =>
                     voice(f, 0.35, { gain: 0.11, delay: i * 0.06, send: 0.4, detune: 12 }));
                     kick({ gain: 0.4 }); },
    win:     () => { [523, 659, 784, 1047, 1319].forEach((f, i) =>
                     voice(f, 0.42, { gain: 0.1, delay: i * 0.1, send: 0.4, detune: 10 }));
                     kick(); snare({ delay: 0.5 }); },
    lose:    () => [440, 349, 294, 220].forEach((f, i) =>
                     voice(f, 0.5, { gain: 0.1, delay: i * 0.17, type: "triangle", send: 0.3 })),
  };

  /* Sidechain duck — the mixing trick that lets a quiet element win. */
  function duckRamp(amount = 0.35, hold = 0.07) {
    if (!rampGain) return;
    const t = now();
    rampGain.gain.cancelScheduledValues(t);
    rampGain.gain.setValueAtTime(rampGain.gain.value, t);
    rampGain.gain.linearRampToValueAtTime(0.30 * amount, t + 0.012);
    rampGain.gain.linearRampToValueAtTime(0.30, t + 0.012 + hold);
  }

  /* Cascade tick — pitch climbs with the index so the count-up builds a chord. */
  const PENTA = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31];
  /* Four layers, the way a 16-bit point pickup is built:
       transient  — 4ms noise click so it has an edge
       body       — bright square with a fast upward pitch blip
       sparkle    — octave up, very short
       weight     — triangle a fifth below, so it isn't thin       */
  function tick(index, kind) {
    const semi = PENTA[Math.min(index, PENTA.length - 1)];
    const root = { fifteen: 523.25, pair: 587.33, run: 659.25,
                   flush: 698.46, nobs: 784, charm: 880 }[kind] || 523.25;
    const f = root * Math.pow(2, semi / 12);
    duckRamp(0.30, 0.09);

    noise(0.012, { freq: 5200, gain: 0.09 });
    voice(f * 0.72, 0.14, { type: "square", gain: 0.16, detune: 6,
                            slideTo: f, decay: 0.13, send: 0.26 });
    voice(f * 2, 0.06, { type: "square", gain: 0.055, delay: 0.012 });
    voice(f / 1.5, 0.17, { type: "triangle", gain: 0.075, decay: 0.16 });
  }

  /* The multiplier landing — the biggest hit in the game. */
  function slam(magnitude = 1) {
    const m = Math.min(3, magnitude);
    duckRamp(0.0, 0.5);
    kick({ gain: 0.55 });
    noise(0.3, { freq: 300, filter: "lowpass", sweepTo: 60, gain: 0.22 });
    [261.63, 329.63, 392, 523.25].forEach((f, i) =>
      voice(f * (1 + 0.0 * i), 0.55, { gain: 0.09 * m, type: "square", detune: 11,
        delay: i * 0.02, send: 0.45, decay: 0.55 }));
    voice(1046.5, 0.4, { gain: 0.06 * m, type: "square", delay: 0.08, send: 0.5 });
    duck(0.55, 0.06, 0.35);
  }

  return { init, unlock, playMusic, stopMusic, duck, voice, noise, kick, snare, hat,
           tick, cribTick, slam, setProximity, rampStart, rampTo, rampBurst, rampKill,
           TRACKS, PROFILES,
           cycleRamp, rampStyleName, duckRamp,
           sfx: (k) => S[k] && S[k](), hz, get ctx() { return ctx; } };
})();

/* Route the existing sfx() calls into the new engine. */
const SFX16 = {
  ui_click: "click", click: "click", select: "select", deselect: "deselect",
  bad: "bad", draw: "deal", place: "toCrib", win: "win", lose: "lose",
  buy: "buy", level: "level", flip: "flip", cut: "cut", deal: "deal",
  milestone: "milestone",
};
function sfx16(name) {
  Audio16.sfx(SFX16[name] || name);
}
window.addEventListener("pointerdown", () => Audio16.unlock(), { once: true });
window.addEventListener("keydown", () => Audio16.unlock(), { once: true });
