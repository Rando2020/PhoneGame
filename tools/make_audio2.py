#!/usr/bin/env python3
"""
Meldlings audio, rendered offline from the WEB synth's own parameters
(web/audio.js and its call sites), so the phone plays samples, not live
synthesis. Every voice() / noise() / kick() / snare() / hat() call is
transcribed with the same oscillator type, frequency, slide, detune, vibrato,
attack, exponential decay, gain, filter and delay send; the mix runs through a
shared 0.18 s delay (feedback 0.28, wet 0.30) and a soft limiter, as the web's.

  SFX:   44.1 kHz mono 16-bit WAV   ->  OUT/sfx/<id>.wav
  Music: 44.1 kHz mono, one seamless 8-bar loop per profile -> OUT/music/<id>.ogg
         (the loop's tail is wrapped onto its head so the seam is inaudible)

What the web plays, and the id each became:
  sfx16 / Audio16.sfx: click select deselect bad deal flip cut toCrib buy level
                       milestone win lose                      -> same ids
  tick(i, kind)        the count's ticks, per kind (pitch climbs by PENTA in
                       the player)                               -> tick_<kind>
  cribTick(i)          the Crib's ticks                          -> crib_tick
  slam(m)              the multiplier landing, m = 1, 2, 3       -> slam_1..3
  cascade lines        gild 1245 Hz, cut 660 Hz, level 1046 Hz,
                       charm fire 880 Hz                         -> line_gild,
                                                   line_cut, line_level, charm_fire
  tier chord           after the slam, per tier                  -> chord_<cls>
  rampStart/To/Burst   the tension bed under a count             -> ramp_bed (loop),
                                                                    ramp_burst
  cutSound(tier)       the cut ceremony's landing, five tiers    -> cut_<tier>
  cut roll strikes     during the ceremony's roll                -> cut_roll
  the Spoiler pegs     voice(196, saw)                           -> spoiler_peg
  a deed unlocked      three rising squares                      -> deed
  a boss intro         bad + two low saws + kick                 -> boss_intro
  guide beat           voice(660)                                -> guide
  playMusic(name)      menu shop act1..act5 boss play endless    -> music/<name>

  python3 tools/make_audio2.py OUTDIR
"""
import math, os, subprocess, sys, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/audio2"
os.makedirs(f"{OUT}/sfx", exist_ok=True)
os.makedirs(f"{OUT}/music", exist_ok=True)
RNG = np.random.default_rng(16)
NOISE = RNG.uniform(-1, 1, SR // 2)          # the web's 0.5 s noise buffer


class Mix:
    """A buffer with a dry bus and a delay send (the web's shared delayNode)."""

    def __init__(self, seconds):
        n = int(seconds * SR) + SR
        self.dry = np.zeros(n)
        self.send = np.zeros(n)

    def add(self, sig, t0, send=0.0):
        i = int(t0 * SR)
        j = min(len(self.dry), i + len(sig))
        if j <= i:
            return
        self.dry[i:j] += sig[: j - i]
        if send:
            self.send[i:j] += sig[: j - i] * send

    def render(self, limit=True, seconds=None):
        # delay 0.18 s, feedback 0.28, wet 0.30
        d = int(0.18 * SR)
        wet = np.zeros_like(self.send)
        buf = self.send.copy()
        for k in range(1, 12):
            g = 0.28 ** (k - 1)
            if g < 1e-3:
                break
            sh = np.zeros_like(buf)
            sh[d * k:] = buf[: len(buf) - d * k] if d * k < len(buf) else 0
            wet += sh * g
        out = (self.dry + wet * 0.30) * 0.85
        if limit:                      # the web's compressor: threshold -12 dB, ratio 6
            thr = 10 ** (-12 / 20)
            a = np.abs(out)
            over = a > thr
            out[over] = np.sign(out[over]) * (thr + (a[over] - thr) / 6)
        if seconds is None:
            nz = np.nonzero(np.abs(out) > 1e-4)[0]
            end = (nz[-1] + 1) if len(nz) else 1
            out = out[: end + int(0.02 * SR)]
        else:
            out = out[: int(seconds * SR)]
        return out


def env(n, atk, dec, gain):
    t = np.arange(n) / SR
    e = np.empty(n)
    a = t < atk
    e[a] = 0.0001 + (gain - 0.0001) * (t[a] / max(atk, 1e-6))
    # exponentialRampToValueAtTime(0.0001, atk + dec)
    k = np.log(0.0001 / gain) / max(dec, 1e-6)
    e[~a] = gain * np.exp(k * (t[~a] - atk))
    return e


def osc(kind, freq, n):
    """freq: array of instantaneous Hz. Band-limited enough at these pitches."""
    ph = np.cumsum(freq) / SR
    x = ph % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "square":
        return np.where(x < 0.5, 1.0, -1.0) * 0.8
    if kind == "sawtooth":
        return (2 * x - 1) * 0.8
    if kind == "triangle":
        return 1 - 4 * np.abs(x - 0.5)
    raise ValueError(kind)


def voice(m, freq, dur, at=0.0, type="square", gain=0.14, attack=0.004, decay=None,
          slideTo=None, detune=0, vibrato=None, send=0.0, delay=0.0):
    """web voice(): one oscillator, a second detuned by `detune` cents for width."""
    t0 = at + delay
    dec = dur if decay is None else decay
    n = int((attack + dec + 0.02) * SR)
    t = np.arange(n) / SR
    f = np.full(n, float(freq))
    if slideTo:
        # exponentialRampToValueAtTime(slideTo, t0 + dur)
        k = np.clip(t / dur, 0, 1)
        f = freq * (max(20, slideTo) / freq) ** k
    if vibrato:
        f = f * 2 ** ((vibrato.get("cents", 14) * np.sin(2 * np.pi * vibrato.get("hz", 5.5) * t)) / 1200)
    e = env(n, attack, dec, gain)
    sig = osc(type, f, n)
    if detune:
        sig = sig + osc(type, f * 2 ** (detune / 1200), n)
    m.add(sig * e, t0, send)


def noise(m, dur, at=0.0, freq=1800, filter="highpass", sweepTo=None, gain=0.16, send=0.0, delay=0.0):
    t0 = at + delay
    n = int((dur + 0.02) * SR)
    src = np.resize(NOISE, n)
    if sweepTo:     # a swept filter: process in short blocks
        out = np.zeros(n)
        blk = 256
        zi = None
        for s in range(0, n, blk):
            k = min(1.0, s / SR / dur)
            fc = freq * (sweepTo / freq) ** k
            b, a = butter(2, min(0.99, fc / (SR / 2)), btype="low" if filter == "lowpass" else "high")
            if zi is None or len(zi) != max(len(a), len(b)) - 1:
                zi = np.zeros(max(len(a), len(b)) - 1)
            out[s:s + blk], zi = lfilter(b, a, src[s:s + blk], zi=zi)
        y = out
    else:
        b, a = butter(2, min(0.99, freq / (SR / 2)), btype="low" if filter == "lowpass" else ("band" if False else ("high" if filter == "highpass" else "low")))
        y = lfilter(b, a, src)
    t = np.arange(n) / SR
    e = gain * (0.0001 / gain) ** np.clip(t / dur, 0, 1)
    m.add(y * e, t0, send)


def kick(m, at=0.0, gain=0.5, delay=0.0):
    voice(m, 140, 0.16, at=at + delay, type="sine", slideTo=46, gain=gain, decay=0.15)


def snare(m, at=0.0, gain=0.2, delay=0.0):
    noise(m, 0.14, at=at + delay, freq=1400, gain=gain)
    voice(m, 190, 0.1, at=at + delay, type="triangle", gain=0.1, decay=0.09)


def hat(m, at=0.0, gain=0.075):
    noise(m, 0.045, at=at, freq=7000, gain=gain)


# ------------------------------------------------------------------ sfx
def S_click(m): voice(m, 700, 0.05, gain=0.1, decay=0.05)
def S_select(m): voice(m, 880, 0.05, gain=0.1); voice(m, 1320, 0.05, gain=0.05, delay=0.02)
def S_deselect(m): voice(m, 560, 0.05, gain=0.08)
def S_bad(m): voice(m, 300, 0.07, gain=0.12, type="sawtooth"); voice(m, 283, 0.11, gain=0.12, type="sawtooth", delay=0.06)
def S_deal(m): noise(m, 0.06, freq=2600, gain=0.09); voice(m, 620, 0.05, gain=0.05, type="triangle")
def S_flip(m): noise(m, 0.05, freq=3200, gain=0.1); voice(m, 900, 0.06, gain=0.06, slideTo=1400, type="square")
def S_cut(m): voice(m, 400, 0.1, gain=0.12, slideTo=900, type="square", send=0.3); noise(m, 0.09, freq=2200, gain=0.1)
def S_toCrib(m): noise(m, 0.07, freq=1600, gain=0.08); voice(m, 330, 0.09, gain=0.08, slideTo=220, type="triangle")
def S_buy(m):
    for i, f in enumerate([523, 659, 784, 1047]):
        voice(m, f, 0.16, gain=0.09, delay=i * 0.05, send=0.3, detune=8)
def S_level(m):
    for i, f in enumerate([392, 523, 659, 784, 1047]):
        voice(m, f, 0.2, gain=0.085, delay=i * 0.045, type="square", send=0.35, detune=10)
def S_milestone(m):
    for i, f in enumerate([659, 880, 1319]):
        voice(m, f, 0.35, gain=0.11, delay=i * 0.06, send=0.4, detune=12)
    kick(m, gain=0.4)
def S_win(m):
    for i, f in enumerate([523, 659, 784, 1047, 1319]):
        voice(m, f, 0.42, gain=0.1, delay=i * 0.1, send=0.4, detune=10)
    kick(m); snare(m, delay=0.5)
def S_lose(m):
    for i, f in enumerate([440, 349, 294, 220]):
        voice(m, f, 0.5, gain=0.1, delay=i * 0.17, type="triangle", send=0.3)


def tick(m, kind):          # index 0; the player raises pitch by PENTA semitones
    f = {"fifteen": 523.25, "pair": 587.33, "run": 659.25, "flush": 698.46, "nobs": 784, "charm": 880}[kind]
    noise(m, 0.012, freq=5200, gain=0.09)
    voice(m, f * 0.72, 0.14, type="square", gain=0.16, detune=6, slideTo=f, decay=0.13, send=0.26)
    voice(m, f * 2, 0.06, type="square", gain=0.055, delay=0.012)
    voice(m, f / 1.5, 0.17, type="triangle", gain=0.075, decay=0.16)


def crib_tick(m):
    f = 196.0
    voice(m, f, 0.34, type="triangle", gain=0.15, detune=5, decay=0.32, send=0.4)
    voice(m, f * 2, 0.16, type="sine", gain=0.07, delay=0.02)
    noise(m, 0.02, freq=900, filter="lowpass", gain=0.05)


def slam(m, mag):
    mm = min(3, mag)
    kick(m, gain=0.55)
    noise(m, 0.3, freq=300, filter="lowpass", sweepTo=60, gain=0.22)
    for i, f in enumerate([261.63, 329.63, 392, 523.25]):
        voice(m, f, 0.55, gain=0.09 * mm, type="square", detune=11, delay=i * 0.02, send=0.45, decay=0.55)
    voice(m, 1046.5, 0.4, gain=0.06 * mm, type="square", delay=0.08, send=0.5)


CHORDS = {"t-none": [261.63, 329.63], "t-ok": [261.63, 329.63, 392], "t-good": [261.63, 329.63, 392, 523.25],
          "t-big": [261.63, 392, 523.25, 659.25], "t-max": [329.63, 523.25, 659.25, 783.99, 1046.5]}


def chord(m, cls):
    for i, f in enumerate(CHORDS[cls]):
        voice(m, f, 0.7, gain=0.075, type="square", detune=11, delay=0.06 + i * 0.045, send=0.45)


def cut_tier(m, tier):
    V = lambda f, d, **o: voice(m, f, d, **o)
    if tier == "cold":
        V(160, 0.34, type="triangle", gain=0.10); V(190, 0.30, type="sawtooth", gain=0.05, delay=0.03)
    elif tier == "okay":
        for i, f in enumerate([392, 587]): V(f, 0.28, type="square", gain=0.09, delay=i * 0.05, send=0.3)
    elif tier == "good":
        for i, f in enumerate([392, 494, 587]): V(f, 0.40, type="square", gain=0.095, delay=i * 0.055, send=0.38, detune=8)
        kick(m, gain=0.3)
    elif tier == "great":
        for i, f in enumerate([523, 659, 784, 1047]): V(f, 0.55, type="square", gain=0.10, delay=i * 0.055, send=0.45, detune=10)
        for i, f in enumerate([1319, 1568]): V(f, 0.3, type="square", gain=0.05, delay=0.26 + i * 0.06)
        kick(m, gain=0.42)
    else:
        for i, f in enumerate([523, 659, 784, 1047, 1319, 1568, 2093]): V(f, 0.7, type="square", gain=0.10, delay=i * 0.07, send=0.5, detune=12)
        for i, f in enumerate([261, 392]): V(f, 1.1, type="triangle", gain=0.09, delay=i * 0.05)
        kick(m, gain=0.55); snare(m, delay=0.5, gain=0.3)


def cut_roll(m):            # one roll strike at n = 0 (the player raises pitch per strike)
    noise(m, 0.045, freq=1900, gain=0.05)
    voice(m, 280, 0.045, gain=0.04, type="square")


def ramp_bed(seconds=2.0):
    """The 'sweep' ramp at a middle level: detuned saws through a lowpass with a
    4 Hz tremolo, over bandpassed noise. A seamless loop; the player raises its
    pitch and volume with the count's level (rampTo), and cuts it on the burst."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    base = 62 * 2 ** (12 / 12)
    s = osc("sawtooth", np.full(n, base), n) + osc("sawtooth", np.full(n, base * 2 ** (14 / 1200)), n)
    b, a = butter(2, 2400 / (SR / 2), "low")
    s = lfilter(b, a, s)
    trem = 1 + 0.5 * np.sin(2 * np.pi * 8 * t)            # 4 Hz -> faster as it builds; mid level
    s = s * 0.036 * trem
    b2, a2 = butter(2, [1800 / (SR / 2), 3400 / (SR / 2)], "band")
    nz = lfilter(b2, a2, np.resize(NOISE, n)) * 0.07
    out = (s + nz) * 0.30
    fade = int(0.05 * SR)                                   # crossfade the seam
    out[:fade] = out[:fade] * np.linspace(0, 1, fade) + out[-fade:] * np.linspace(1, 0, fade)
    return out[: n - fade]


def ramp_burst(m):
    for i in range(7):
        d = 0.1 * 0.72 ** i
        noise(m, 0.03, at=i * d * 1.4, freq=3000 + i * 500, gain=0.032)
    top = 62 * 2 ** (26 / 12)
    voice(m, top / 2, 0.36, type="sawtooth", gain=0.07, slideTo=top, detune=14, decay=0.36)


def spoiler_peg(m): voice(m, 196, 0.22, type="sawtooth", gain=0.1, detune=10)
def deed(m):
    voice(m, 880, 0.09, type="square", gain=0.09, send=0.3)
    voice(m, 1318, 0.16, type="square", gain=0.08, delay=0.09, send=0.35)
    voice(m, 1760, 0.3, type="square", gain=0.06, delay=0.19, send=0.4, detune=8)
def boss_intro(m):
    S_bad(m)
    voice(m, 110, 1.2, gain=0.14, type="sawtooth", detune=14, send=0.4)
    voice(m, 164.81, 1.2, gain=0.09, type="sawtooth", detune=12, delay=0.1)
    kick(m, gain=0.5)
def guide(m): voice(m, 660, 0.1, type="square", gain=0.06, send=0.3)
def line_gild(m): voice(m, 1245, 0.16, gain=0.09, type="square", detune=12, send=0.4)
def line_cut(m): voice(m, 660, 0.14, gain=0.09, type="square", detune=9, send=0.35)
def line_level(m): voice(m, 1046, 0.18, gain=0.1, type="square", detune=10, send=0.35)
def charm_fire(m): voice(m, 880, 0.1, gain=0.07, type="square", send=0.3)


SFX = {
    "click": S_click, "select": S_select, "deselect": S_deselect, "bad": S_bad, "deal": S_deal,
    "flip": S_flip, "cut": S_cut, "toCrib": S_toCrib, "buy": S_buy, "level": S_level,
    "milestone": S_milestone, "win": S_win, "lose": S_lose,
    "crib_tick": crib_tick, "slam_1": lambda m: slam(m, 1), "slam_2": lambda m: slam(m, 2),
    "slam_3": lambda m: slam(m, 3), "ramp_burst": ramp_burst, "cut_roll": cut_roll,
    "spoiler_peg": spoiler_peg, "deed": deed, "boss_intro": boss_intro, "guide": guide,
    "line_gild": line_gild, "line_cut": line_cut, "line_level": line_level, "charm_fire": charm_fire,
}
for k in ["fifteen", "pair", "run", "flush", "nobs", "charm"]:
    SFX["tick_" + k] = (lambda kk: lambda m: tick(m, kk))(k)
for c in CHORDS:
    SFX["chord_" + c] = (lambda cc: lambda m: chord(m, cc))(c)
for t in ["cold", "okay", "good", "great", "perfect"]:
    SFX["cut_" + t] = (lambda tt: lambda m: cut_tier(m, tt))(t)


# ------------------------------------------------------------------ music
MODES = {"ionian": [0, 2, 4, 5, 7, 9, 11], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
         "lydian": [0, 2, 4, 6, 7, 9, 11], "mixolydian": [0, 2, 4, 5, 7, 9, 10], "aeolian": [0, 2, 3, 5, 7, 8, 10]}
MOTIF_A = [0, None, 2, 4, None, 4, 3, 2, 1, None, 3, 5, 7, None, None, None]
MOTIF_B = [7, None, 5, 4, None, 3, 2, 1, 0, None, 1, 2, 0, None, None, None]
DRUMS = {"none": ". . . . . . . .", "soft": ". . h . . . h .", "sparse": "k . . . . . h .",
         "drive": "k . h s . h k x", "march": "k . s . k . s .", "heavy": "k h s h k h s x", "fill": "k . h s h h s x"}
PROFILES = {
    "menu": dict(root=57, mode="aeolian", bpm=88, chords=[0, 5, 3, 4], drums="soft", lead="plain", bass="held", arp=False, pad=True),
    "shop": dict(root=53, mode="lydian", bpm=76, chords=[0, 1, 0, 4], drums="none", lead="sparse", bass="held", arp=True, pad=True),
    "act1": dict(root=62, mode="dorian", bpm=112, chords=[0, 3, 4, 0], drums="sparse", lead="plain", bass="held", arp=True, pad=False, lift=1),
    "act2": dict(root=64, mode="aeolian", bpm=120, chords=[0, 5, 3, 4], drums="drive", lead="plain", bass="pulse", arp=True, pad=False, lift=1),
    "act3": dict(root=66, mode="dorian", bpm=126, chords=[0, 3, 5, 4], drums="drive", lead="plain", bass="pulse", arp=True, pad=True, lift=2, leadOct=0),
    "act4": dict(root=57, mode="aeolian", bpm=132, chords=[0, 5, 6, 4], drums="drive", lead="sync", bass="pulse", arp=True, pad=True, lift=2, leadOct=1),
    "act5": dict(root=59, mode="phrygian", bpm=138, chords=[0, 1, 5, 4], drums="heavy", lead="sync", bass="pulse", arp=True, pad=True, lift=2, leadOct=0),
    "boss": dict(root=64, mode="phrygian", bpm=150, chords=[0, 1, 0, 6], drums="heavy", lead="plain", bass="pulse", arp=True, pad=False, lift=1),
    "play": dict(root=60, mode="dorian", bpm=118, chords=[0, 4, 0, 3], drums="march", lead="call", bass="pulse", arp=True, pad=False),
    "endless": dict(root=61, mode="aeolian", bpm=144, chords=[0, 6, 5, 4], drums="heavy", lead="fragment", bass="pulse", arp=True, pad=True, lift=2, leadOct=0),
}


def deg_to_midi(d, root, mode):
    m = MODES[mode]
    return root + (d // 7) * 12 + m[d % 7]


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def phrase_lead(motif, P):
    out = []
    for i, d in enumerate(motif):
        if d is None:
            out.append(None); continue
        if P["lead"] == "sparse" and i % 4 != 0:
            out.append(None); continue
        if P["lead"] == "fragment" and i >= 8:
            out.append(None); continue
        if P["lead"] == "sync" and (i % 8 == 5 or i % 8 == 6):
            out.append(None); continue
        out.append(deg_to_midi(d, P["root"] + 12 * P.get("leadOct", 0), P["mode"]))
    return out


def compose(P):
    a = phrase_lead(MOTIF_A, P)
    b = phrase_lead(MOTIF_B, P)
    lifted = phrase_lead([None if d is None else d + P.get("lift", 0) for d in MOTIF_A], P)
    lead_steps = a + lifted + b + b
    lead, bass, arp, pad, drums = [], [], [], [], []
    for bar in range(8):
        chunk = lead_steps[bar * 8: bar * 8 + 8]
        lead += [None] * 8 if (P["lead"] == "call" and bar % 2 == 1) else chunk
        r = P["chords"][bar % len(P["chords"])]
        R = deg_to_midi(r, P["root"] - 24, P["mode"])
        F = deg_to_midi(r + 4, P["root"] - 24, P["mode"])
        bass += [R, R, None, R, F, None, R + 12, None] if P["bass"] == "pulse" else [R, None, None, None, F, None, None, None]
        if P["arp"] and not (P["lead"] == "call" and bar % 2 == 0):
            arp += [deg_to_midi(r + k, P["root"], P["mode"]) for k in [0, 2, 4, 7, 4, 2, 0, 2]]
        else:
            arp += [None] * 8
        pad += ([deg_to_midi(r, P["root"] - 12, P["mode"])] + [None] * 7) if P["pad"] else [None] * 8
        row = DRUMS["fill"] if (bar == 7 and P["drums"] != "none") else DRUMS[P["drums"]]
        drums += row.split()
    return lead, bass, arp, pad, drums


def music(name):
    P = PROFILES[name]
    lead, bass, arp, pad, drums = compose(P)
    step = (60 / P["bpm"]) / 2
    total = 64
    length = total * step
    m = Mix(length + 3)
    MG = 0.34                                   # musicGain
    for i in range(total):
        at = i * step
        if lead[i] is not None:
            voice(m, hz(lead[i]), step * 1.7, at=at, type="square", gain=0.075 * MG, detune=9,
                  decay=step * 1.7, send=0.28, vibrato={"hz": 5, "cents": 10})
        if bass[i] is not None:
            voice(m, hz(bass[i]), step * 1.5, at=at, type="triangle", gain=0.19 * MG, decay=step * 1.4)
        if arp[i] is not None:
            voice(m, hz(arp[i]), step * 0.8, at=at, type="square", gain=0.035 * MG, send=0.2)
        if pad[i] is not None:
            voice(m, hz(pad[i]), step * 7, at=at, type="sawtooth", gain=0.026 * MG, detune=12, attack=0.15, decay=step * 7)
        dd = drums[i]
        if dd == "k": kick(m, at=at, gain=0.34 * MG)
        elif dd == "s": snare(m, at=at, gain=0.13 * MG)
        elif dd == "h": hat(m, at=at, gain=0.05 * MG)
        elif dd == "x": snare(m, at=at, gain=0.13 * MG); hat(m, at=at, gain=0.05 * MG)
    full = m.render(limit=True, seconds=length + 3)
    n = int(length * SR)
    loop = full[:n].copy()
    tail = full[n:]
    loop[: len(tail)] += tail[: n]           # wrap the tail (reverb, decays) onto the head: a seamless loop
    return loop


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    peaks = {}
    for k, fn in SFX.items():
        m = Mix(4)
        fn(m)
        x = m.render()
        peaks[k] = float(np.max(np.abs(x)))
        write_wav(f"{OUT}/sfx/{k}.wav", x)
    write_wav(f"{OUT}/sfx/ramp_bed.wav", ramp_bed())
    for k in PROFILES:
        x = music(k)
        tmp = f"{OUT}/music/{k}.wav"
        write_wav(tmp, x * 2.2)          # the web's music bus sits at 0.34; bring loops up to a sensible level
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                        f"{OUT}/music/{k}.ogg"], check=True)
        os.remove(tmp)
    print(f"{len(SFX) + 1} sfx, {len(PROFILES)} music loops in {OUT}")
    print("loudest sfx peaks:", sorted(peaks.items(), key=lambda kv: -kv[1])[:4])


if __name__ == "__main__":
    main()
