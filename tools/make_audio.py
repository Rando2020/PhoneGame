#!/usr/bin/env python3
"""
Meldlings audio generator.

A small tracker-style chiptune synth: pulse / triangle / saw / noise oscillators,
ADSR, detune-pair widening, vibrato, and a delay send for that SNES-era space.
No samples, no external assets -- everything is synthesised.

Music  -> 44.1k stereo, exported as seamless OGG loops.
SFX    -> 44.1k mono WAV (low latency, tiny files).
"""
import numpy as np
import wave, os, subprocess

SR = 44100
MUS = "/home/claude/out/assets/audio/music"
SFX = "/home/claude/out/assets/audio/sfx"

NOTES = {"c": 0, "c#": 1, "db": 1, "d": 2, "d#": 3, "eb": 3, "e": 4, "f": 5,
         "f#": 6, "gb": 6, "g": 7, "g#": 8, "ab": 8, "a": 9, "a#": 10, "bb": 10, "b": 11}


def freq(token):
    """'a3' -> 220.0 ; 'f#4' -> 370.0"""
    t = token.strip().lower()
    i = len(t) - 1
    octave = int(t[i])
    semi = NOTES[t[:i]]
    midi = (octave + 1) * 12 + semi
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


# ------------------------------------------------------------------ synth
def osc(f, n, wave_type, duty=0.5, vib=0.0, vib_hz=5.5, seed=None):
    t = np.arange(n) / SR
    fr = np.full(n, f, dtype=np.float64)
    if vib:
        env = np.clip((t - 0.08) * 6.0, 0.0, 1.0)          # vibrato fades in
        fr = fr * (1.0 + vib * env * np.sin(2 * np.pi * vib_hz * t))
    ph = np.cumsum(fr) / SR
    frac = ph % 1.0
    if wave_type == "pulse":
        return np.where(frac < duty, 1.0, -1.0)
    if wave_type == "tri":
        return 2.0 * np.abs(2.0 * (frac - 0.5)) - 1.0
    if wave_type == "saw":
        return 2.0 * frac - 1.0
    if wave_type == "sine":
        return np.sin(2 * np.pi * ph)
    if wave_type == "noise":
        rng = np.random.default_rng(seed if seed is not None else 0)
        return rng.uniform(-1.0, 1.0, n)
    raise ValueError(wave_type)


def adsr(n, a=0.005, d=0.06, s=0.6, r=0.08):
    n = max(1, n)
    rn = max(1, int(r * SR))
    body = max(1, n)
    an = min(int(a * SR), body)
    dn = min(int(d * SR), max(0, body - an))
    env = np.zeros(body + rn)
    if an > 0:
        env[:an] = np.linspace(0, 1, an)
    if dn > 0:
        env[an:an + dn] = np.linspace(1, s, dn)
    if body > an + dn:
        env[an + dn:body] = s
    last = env[body - 1] if body > 0 else s
    env[body:body + rn] = np.linspace(last, 0, rn)
    return env


def note(f, dur, wave_type="pulse", duty=0.5, gain=0.3, detune=0.0, vib=0.0,
         env=(0.005, 0.06, 0.6, 0.09), seed=None):
    n = int(dur * SR)
    e = adsr(n, *env)
    total = len(e)
    sig = osc(f, total, wave_type, duty, vib, seed=seed)
    if detune:
        sig = 0.5 * sig + 0.5 * osc(f * (1.0 + detune), total, wave_type, duty, vib, seed=seed)
    return sig * e * gain


def kick(dur=0.16, gain=0.75):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 130.0 * np.exp(-t * 30.0) + 44.0
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR)
    return sig * np.exp(-t * 22.0) * gain


def snare(dur=0.16, gain=0.5, seed=1):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    nz = rng.uniform(-1, 1, n)
    tone = np.sin(2 * np.pi * 190 * t) * 0.4
    return (nz * 0.8 + tone) * np.exp(-t * 26.0) * gain


def hat(dur=0.05, gain=0.26, seed=2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    nz = rng.uniform(-1, 1, n)
    hp = nz - np.convolve(nz, np.ones(6) / 6, mode="same")   # cheap high-pass
    return hp * np.exp(-t * 90.0) * gain


def delay(sig, time=0.24, fb=0.32, mix=0.30):
    d = int(time * SR)
    if d <= 0 or d >= len(sig):
        return sig
    wet = sig.copy()
    for start in range(d, len(wet), d):
        end = min(start + d, len(wet))
        wet[start:end] += fb * wet[start - d:end - d]
    return sig * (1 - mix) + wet * mix


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[:j - i]


def normalize(sig, peak=0.89):
    m = np.max(np.abs(sig))
    return sig * (peak / m) if m > 0 else sig


def write_wav(path, left, right=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if right is None:
        data = (np.clip(left, -1, 1) * 32767).astype("<i2")
        ch = 1
    else:
        inter = np.empty(len(left) * 2)
        inter[0::2] = np.clip(left, -1, 1)
        inter[1::2] = np.clip(right, -1, 1)
        data = (inter * 32767).astype("<i2")
        ch = 2
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def to_ogg(wav_path, ogg_path, quality="5"):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", quality, ogg_path], check=True)
    os.remove(wav_path)


# ------------------------------------------------------------------ sequencer
def play_pattern(buf, bars, bpm, inst, steps_per_bar=8, start=0.0, transpose=0):
    """bars: list of strings, e.g. 'd3 - a3 . f3 - a3 .'  ('-' sustain, '.' rest)"""
    spb = 60.0 / bpm
    step = spb * 4.0 / steps_per_bar
    t = start
    for bar in bars:
        toks = bar.split()
        i = 0
        while i < len(toks):
            tok = toks[i]
            if tok in (".", "-"):
                i += 1
                t += step
                continue
            length = 1
            while i + length < len(toks) and toks[i + length] == "-":
                length += 1
            f = freq(tok) * (2.0 ** (transpose / 12.0))
            place(buf, note(f, step * length * 0.98, **inst), t)
            t += step * length
            i += length
    return t


def play_drums(buf, bars, bpm, steps_per_bar=8, start=0.0):
    spb = 60.0 / bpm
    step = spb * 4.0 / steps_per_bar
    t = start
    for bar in bars:
        for tok in bar.split():
            if tok == "K":
                place(buf, kick(), t)
            elif tok == "S":
                place(buf, snare(), t)
            elif tok == "H":
                place(buf, hat(), t)
            elif tok == "B":
                place(buf, kick(), t); place(buf, hat(), t)
            elif tok == "X":
                place(buf, snare(), t); place(buf, hat(), t)
            t += step
    return t


# ------------------------------------------------------------------ tracks
LEAD = dict(wave_type="pulse", duty=0.5, gain=0.20, detune=0.006, vib=0.010,
            env=(0.008, 0.10, 0.55, 0.12))
LEAD2 = dict(wave_type="pulse", duty=0.25, gain=0.13, detune=0.004,
             env=(0.006, 0.08, 0.45, 0.10))
BASS = dict(wave_type="tri", gain=0.34, env=(0.004, 0.05, 0.80, 0.06))
ARP = dict(wave_type="pulse", duty=0.125, gain=0.095, env=(0.002, 0.04, 0.30, 0.05))
PAD = dict(wave_type="saw", gain=0.075, detune=0.010, env=(0.12, 0.30, 0.55, 0.35))


def bgm_battle():
    bpm = 132
    bars_total = 16
    length = (60.0 / bpm) * 4 * bars_total + 1.2
    n = int(length * SR)
    lead = np.zeros(n); bass = np.zeros(n); arp = np.zeros(n); drm = np.zeros(n)

    bass_bars = [
        "d2 d2 . d2 a2 . d3 .",
        "a#1 a#1 . a#1 f2 . a#2 .",
        "f2 f2 . f2 c3 . f3 .",
        "c2 c2 . c2 g2 . c3 .",
    ] * 4

    lead_a = [
        "a3 - c4 - d4 - a3 -",
        "f3 - a3 - a#3 - f3 -",
        "c4 - a3 - f3 - a3 -",
        "g3 - a3 - c4 - g3 -",
    ]
    lead_b = [
        "d4 - f4 - e4 - d4 -",
        "a#3 - d4 - c4 - a#3 -",
        "c4 - f4 - e4 - c4 -",
        "g3 - c4 - d4 - . .",
    ]
    lead_bars = ["." * 1] * 4 + lead_a + lead_b + lead_a

    arp_bars = [
        "d3 f3 a3 d4 a3 f3 d3 f3",
        "a#2 d3 f3 a#3 f3 d3 a#2 d3",
        "c3 f3 a3 c4 a3 f3 c3 f3",
        "c3 e3 g3 c4 g3 e3 c3 e3",
    ] * 4

    drum_bars = (["B . H S . H K X"] * 3 + ["B . H S H H S X"]) * 4

    play_pattern(bass, bass_bars, bpm, BASS)
    play_pattern(lead, lead_bars, bpm, LEAD)
    play_pattern(arp, arp_bars, bpm, ARP)
    play_drums(drm, drum_bars, bpm)

    lead = delay(lead, 60.0 / bpm / 2, 0.30, 0.28)
    arp = delay(arp, 60.0 / bpm / 4, 0.22, 0.22)

    mid = bass + drm
    left = normalize(mid + lead * 1.0 + arp * 1.15, 0.86)
    right = normalize(mid + lead * 1.0 + arp * 0.75, 0.86)
    loop = int((60.0 / bpm) * 4 * bars_total * SR)
    return left[:loop], right[:loop]


def bgm_menu():
    bpm = 84
    bars_total = 8
    length = (60.0 / bpm) * 4 * bars_total + 2.0
    n = int(length * SR)
    lead = np.zeros(n); bass = np.zeros(n); pad = np.zeros(n)

    bass_bars = ["a2 - - . e2 - - .", "f2 - - . c3 - - .",
                 "g2 - - . d3 - - .", "a2 - - . e3 - - ."] * 2
    lead_bars = ["e4 - - c4 - - a3 -", "f4 - - e4 - - c4 -",
                 "g4 - - e4 - - d4 -", "a4 - - - e4 - - -",
                 "c5 - - a4 - - e4 -", "f4 - - c4 - - a3 -",
                 "d4 - - g4 - - e4 -", "a3 - - - - - - -"]
    pad_bars = ["a3 - - - - - - -", "f3 - - - - - - -",
                "g3 - - - - - - -", "a3 - - - - - - -"] * 2

    play_pattern(bass, bass_bars, bpm, BASS)
    play_pattern(lead, lead_bars, bpm, dict(LEAD, gain=0.16, wave_type="tri", vib=0.014))
    play_pattern(pad, pad_bars, bpm, PAD)

    lead = delay(lead, 0.34, 0.34, 0.34)
    left = normalize(bass + lead + pad * 1.1, 0.72)
    right = normalize(bass + lead + pad * 0.9, 0.72)
    loop = int((60.0 / bpm) * 4 * bars_total * SR)
    return left[:loop], right[:loop]


def bgm_boss():
    bpm = 148
    bars_total = 8
    length = (60.0 / bpm) * 4 * bars_total + 1.2
    n = int(length * SR)
    lead = np.zeros(n); bass = np.zeros(n); arp = np.zeros(n); drm = np.zeros(n)

    bass_bars = ["e2 e2 e2 . f2 . e2 .", "e2 e2 e2 . a#2 . e2 .",
                 "d2 d2 d2 . d#2 . d2 .", "c2 c2 c2 . b1 . c2 ."] * 2
    lead_bars = ["e4 f4 e4 - b3 - e4 -", "a#3 b3 a#3 - f3 - a#3 -",
                 "d4 d#4 d4 - a3 - d4 -", "c4 b3 c4 - g3 - b3 -"] * 2
    arp_bars = ["e3 g3 b3 e4 b3 g3 e3 g3", "f3 a3 c4 f4 c4 a3 f3 a3",
                "d3 f3 a3 d4 a3 f3 d3 f3", "c3 d#3 g3 c4 g3 d#3 c3 d#3"] * 2
    drum_bars = (["B H S H B H S X"] * 3 + ["B H S H S S X X"]) * 2

    play_pattern(bass, bass_bars, bpm, dict(BASS, wave_type="saw", gain=0.30))
    play_pattern(lead, lead_bars, bpm, dict(LEAD, duty=0.35, gain=0.19))
    play_pattern(arp, arp_bars, bpm, ARP)
    play_drums(drm, drum_bars, bpm)

    lead = delay(lead, 60.0 / bpm / 2, 0.26, 0.24)
    left = normalize(bass + drm + lead + arp * 1.1, 0.90)
    right = normalize(bass + drm + lead + arp * 0.8, 0.90)
    loop = int((60.0 / bpm) * 4 * bars_total * SR)
    return left[:loop], right[:loop]


# ------------------------------------------------------------------ sfx
def buf(dur):
    return np.zeros(int(dur * SR))


def sfx_blip(f=880, dur=0.07, duty=0.5, gain=0.5):
    b = buf(dur + 0.05)
    place(b, note(f, dur, "pulse", duty, gain, env=(0.001, 0.02, 0.5, 0.04)), 0)
    return b


def sfx_sweep(f0, f1, dur, wave_type="pulse", duty=0.5, gain=0.45, decay=8.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    fr = f0 * (f1 / f0) ** (t / dur)
    ph = np.cumsum(fr) / SR
    frac = ph % 1.0
    if wave_type == "pulse":
        sig = np.where(frac < duty, 1.0, -1.0)
    elif wave_type == "tri":
        sig = 2 * np.abs(2 * (frac - 0.5)) - 1
    else:
        sig = np.sin(2 * np.pi * ph)
    return sig * np.exp(-t * decay) * gain


def sfx_noise(dur, decay=18.0, gain=0.4, hp=False, seed=7):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    nz = rng.uniform(-1, 1, n)
    if hp:
        nz = nz - np.convolve(nz, np.ones(8) / 8, mode="same")
    return nz * np.exp(-t * decay) * gain


def layer(dur, parts):
    """Mix (signal, offset_seconds) pairs into a fixed-length buffer."""
    b = buf(dur)
    for sig, at in parts:
        place(b, sig, at)
    return b


def arpeggio(notes, step=0.055, dur=0.09, duty=0.5, gain=0.4, tail=0.25):
    b = buf(step * len(notes) + dur + tail)
    for i, nm in enumerate(notes):
        place(b, note(freq(nm), dur, "pulse", duty, gain, detune=0.005,
                      env=(0.002, 0.03, 0.5, 0.10)), i * step)
    return b


def chord(notes, dur=0.6, duty=0.5, gain=0.22, wave_type="pulse"):
    b = buf(dur + 0.4)
    for nm in notes:
        place(b, note(freq(nm), dur, wave_type, duty, gain, detune=0.006,
                      env=(0.01, 0.12, 0.6, 0.32)), 0)
    return b


def build_sfx():
    s = {}

    # --- ui / cards
    s["ui_click"] = sfx_blip(720, 0.04, 0.5, 0.40)
    s["card_select"] = arpeggio(["c5", "g5"], 0.035, 0.06, 0.25, 0.34, 0.10)
    s["card_deselect"] = arpeggio(["g5", "c5"], 0.035, 0.06, 0.25, 0.28, 0.10)
    s["card_draw"] = layer(0.26, [(sfx_noise(0.16, 14.0, 0.20, hp=True), 0.0),
                                  (sfx_sweep(500, 1400, 0.10, "pulse", 0.3, 0.22, 12), 0.02)])
    s["card_place"] = layer(0.18, [(sfx_noise(0.09, 40.0, 0.26, hp=True), 0.0),
                                   (sfx_sweep(320, 150, 0.08, "tri", 0.5, 0.34, 22), 0.005)])
    s["card_invalid"] = np.concatenate([
        sfx_blip(300, 0.06, 0.5, 0.40), sfx_blip(282, 0.10, 0.5, 0.40)])
    s["shuffle"] = layer(0.60, [(sfx_noise(0.06, 45.0, 0.16, hp=True, seed=i), i * 0.045)
                                for i in range(9)])

    # --- melds (each action gets its own signature)
    s["meld_brace"] = chord(["d3", "a3", "d4"], 0.45, 0.5, 0.20, "tri")
    s["meld_prep"] = arpeggio(["g3", "b3", "d4"], 0.05, 0.10, 0.25, 0.34)
    s["meld_strike"] = layer(0.30, [(sfx_sweep(1200, 240, 0.14, "pulse", 0.25, 0.50, 14), 0.0),
                                    (sfx_noise(0.10, 26.0, 0.32, hp=True), 0.09)])
    s["meld_rally"] = arpeggio(["c4", "e4", "g4", "c5"], 0.055, 0.11, 0.5, 0.36)
    s["meld_grand"] = np.concatenate([
        arpeggio(["c4", "e4", "g4", "c5", "e5", "g5"], 0.05, 0.10, 0.5, 0.34, 0.05),
        chord(["c4", "e4", "g4", "c5"], 0.9, 0.5, 0.20)])

    # --- combat
    s["hit_light"] = layer(0.20, [(sfx_noise(0.10, 34.0, 0.34, hp=True), 0.0),
                                  (sfx_sweep(420, 120, 0.09, "pulse", 0.5, 0.30, 26), 0.0)])
    s["hit_heavy"] = layer(0.34, [(sfx_noise(0.20, 16.0, 0.44), 0.0),
                                  (sfx_sweep(260, 55, 0.18, "tri", 0.5, 0.46, 13), 0.01)])
    s["block"] = arpeggio(["a4", "e5"], 0.02, 0.14, 0.5, 0.30, 0.18)
    s["burn"] = layer(0.48, [(sfx_noise(0.05, 60.0, 0.13, hp=True, seed=20 + i), i * 0.05)
                             for i in range(7)])
    s["hex"] = layer(0.46, [(sfx_sweep(680, 300, 0.42, "pulse", 0.18, 0.30, 4.0), 0.0),
                            (sfx_sweep(700, 296, 0.42, "pulse", 0.22, 0.24, 4.0), 0.0)])
    s["thorns"] = layer(0.16, [(sfx_blip(1500, 0.03, 0.2, 0.36), 0.0),
                               (sfx_noise(0.08, 40.0, 0.26, hp=True), 0.03)])

    # --- meta
    s["relic"] = arpeggio(["e5", "a5", "c6", "e6"], 0.07, 0.22, 0.5, 0.26, 0.5)
    s["victory"] = np.concatenate([
        arpeggio(["c4", "e4", "g4"], 0.09, 0.12, 0.5, 0.34, 0.02),
        chord(["c4", "e4", "g4", "c5"], 1.0, 0.5, 0.20)])
    s["defeat"] = np.concatenate([
        arpeggio(["a3", "f3", "d3"], 0.16, 0.24, 0.5, 0.30, 0.05),
        chord(["d3", "f3", "a3"], 1.1, 0.5, 0.18, "tri")])
    s["level_up"] = arpeggio(["c4", "d4", "e4", "g4", "c5"], 0.06, 0.12, 0.4, 0.32)

    return {k: normalize(v, 0.82) for k, v in s.items()}


# ------------------------------------------------------------------ run
def main():
    os.makedirs(MUS, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)

    for name, fn in (("bgm_battle", bgm_battle), ("bgm_menu", bgm_menu), ("bgm_boss", bgm_boss)):
        l, r = fn()
        tmp = f"{MUS}/{name}.wav"
        write_wav(tmp, l, r)
        to_ogg(tmp, f"{MUS}/{name}.ogg")
        print("music", name, "%.1fs" % (len(l) / SR))

    sfx = build_sfx()
    for name, sig in sfx.items():
        write_wav(f"{SFX}/{name}.wav", sig)
    print("sfx", len(sfx))


if __name__ == "__main__":
    main()
