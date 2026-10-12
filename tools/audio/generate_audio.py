#!/usr/bin/env python3
"""Procedural SNES-style audio generator for Puffin Platformer.

All melodies, harmonies and timbres here are original and synthesized from scratch
(no samples). Output: OGG Vorbis (via ffmpeg, 32 kHz mono) into
res://audio/music and res://audio/sfx. WAV masters go to a temp dir
(or $PUFFIN_WAV_DIR) and are not committed.

Usage: python3 tools/audio/generate_audio.py   (needs numpy, scipy, ffmpeg)
"""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import butter, lfilter
from scipy.io import wavfile

SR = 32000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
rng = np.random.default_rng(1234)

def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def t_(n): return np.arange(n) / SR
def lp(x, fc, order=2): b, a = butter(order, fc / (SR / 2)); return lfilter(b, a, x)
def hp(x, fc): b, a = butter(1, fc / (SR / 2), "high"); return lfilter(b, a, x)

def env(n, a=0.005, d=0.1, s=0.6, r=0.05):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = min(ai, n); e[:ai] = np.linspace(0, 1, ai)
    dj = min(ai + di, n); e[ai:dj] = np.linspace(1, s, dj - ai)
    ri = min(ri, n); e[n - ri:] *= np.linspace(1, 0, ri)
    return e

# ---- oscillators -------------------------------------------------------------
def pulse(f, n, duty=0.25, vib=0.0):
    ph = np.cumsum(np.full(n, f) * (1 + vib * np.sin(2 * np.pi * 5.5 * t_(n)) * np.clip(t_(n) * 4 - 0.6, 0, 1))) / SR
    return np.where((ph % 1) < duty, 1.0, -1.0)
def tri(f, n):
    ph = (f * t_(n)) % 1; return 4 * np.abs(ph - 0.5) - 1
def quant(x, bits=4): q = 2 ** (bits - 1); return np.round(x * q) / q  # stepped NES/SNES-ish tri
def noise(n): return rng.uniform(-1, 1, n)

# ---- "sample-style" instruments (BRR-like: band-limited, enveloped) -----------
def inst_lead(f, n):   # soft pulse lead, filtered like a sampled square
    return lp(pulse(f, n, 0.25, 0.006), 5000) * env(n, 0.01, 0.15, 0.7, 0.06) * 0.30
def inst_flute(f, n):
    x = np.sin(2*np.pi*f*t_(n)*(1+0.004*np.sin(2*np.pi*5*t_(n)))) + 0.25*np.sin(4*np.pi*f*t_(n)) + 0.03*lp(noise(n), 3000)
    return x * env(n, 0.04, 0.1, 0.8, 0.08) * 0.28
def inst_bass(f, n):
    return lp(quant(tri(f, n)), 3000) * env(n, 0.003, 0.08, 0.8, 0.03) * 0.45
def inst_bell(f, n):   # glockenspiel / marimba-ish
    tt = t_(n); x = np.sin(2*np.pi*f*tt) + 0.4*np.sin(2*np.pi*f*2.76*tt)*np.exp(-tt*14)
    return x * np.exp(-tt * 5) * env(n, 0.001, 0, 1, 0.02) * 0.22
def inst_pad(f, n):    # detuned saw strings
    tt = t_(n); x = sum(((f*d*tt) % 1)*2-1 for d in (0.996, 1.0, 1.004))
    return lp(x, 1800) * env(n, 0.12, 0.2, 0.85, 0.15) * 0.07
def inst_kick(n):
    tt = t_(n); f = 110*np.exp(-tt*30)+45; return np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-tt*12)*0.5
def inst_snare(n):
    tt = t_(n); return (lp(noise(n), 6000)*0.7 + np.sin(2*np.pi*190*tt)*0.4)*np.exp(-tt*22)*0.32
def inst_hat(n):
    tt = t_(n); return hp(noise(n), 6000)*np.exp(-tt*60)*0.14

INST = dict(lead=inst_lead, flute=inst_flute, bass=inst_bass, bell=inst_bell, pad=inst_pad)
DRUM = dict(k=inst_kick, s=inst_snare, h=inst_hat)

# ---- tiny tracker --------------------------------------------------------------
NOTE = {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}
def m(s):
    if s in ("-", "r"): return None
    k = NOTE[s[0]]; i = 1
    if len(s) > 1 and s[1] in "#b": k += 1 if s[1] == "#" else -1; i = 2
    return 12 * (int(s[i:]) + 1) + k

def seq(text):
    """'C5:1 E5:.5 -:.5' -> [(midi|None, beats)]"""
    out = []
    for tok in text.split():
        n, b = tok.split(":"); out.append((m(n), float(b)))
    return out

def chords_to_notes(chs, beats_each, voicing):
    """chs: list of chord-symbol note lists; returns per-voice sequences."""
    voices = [[] for _ in voicing]
    for ch in chs:
        for vi, idx in enumerate(voicing):
            voices[vi].append((m(ch[idx]), beats_each))
    return voices

def render(tracks, bpm, total_beats, gain=1.0):
    spb = 60 / bpm; N = int(round(total_beats * spb * SR)); out = np.zeros(N + SR * 3)
    for inst, notes, vol in tracks:
        pos = 0.0
        for note, b in notes:
            st = int(round(pos * spb * SR)); n = int(b * spb * SR * 0.95)
            if note is not None or inst in DRUM:
                if inst in DRUM:
                    if note is not None: s = DRUM[inst](int(0.4 * SR))
                    else: s = None
                else: s = INST[inst](hz(note), n)
                if s is not None: out[st:st + len(s)] += s * vol
            pos += b
    return out * gain, N

def reverb(x, wet=0.18):
    y = np.zeros_like(x)
    for d, g in ((1116, .78), (1188, .76), (1277, .74), (1356, .72)):
        d = int(d * SR / 44100 * 1.6); c = np.zeros_like(x)
        b = np.zeros(d + 1); b[0] = 1; a = np.zeros(d + 1); a[0] = 1; a[d] = -g
        c = lfilter(b, a, x); y += c
    y = lp(y, 3500) / 4
    return x + wet * y

def snes_color(x):  # gaussian-interp style softening + 15-bit-ish grit
    x = lp(x, 11000, 4)
    return np.round(x * 16384) / 16384

def finish(x, peak=0.85, fade_in=0.002, fade_out=0.010, rms=None):
    """Remove DC first, then fade edges to exactly 0, then normalize.
    fade_in/fade_out=0 leaves an edge untouched (used for the seamless loop).
    rms: if set, scale to this RMS loudness (capped so the peak never exceeds `peak`)."""
    x = x - np.mean(x)
    fi, fo = int(fade_in * SR), int(fade_out * SR)
    if fi: x[:fi] *= np.linspace(0, 1, fi)
    if fo: x[-fo:] *= np.linspace(1, 0, fo); x[-1] = 0.0
    if fi: x[0] = 0.0
    pk = np.max(np.abs(x)) + 1e-9
    g = peak / pk
    if rms is not None: g = min(rms / (np.sqrt(np.mean(x ** 2)) + 1e-9), g)
    return x * g

WAV_DIR = os.environ.get("PUFFIN_WAV_DIR") or tempfile.mkdtemp(prefix="puffin_wav_")

def save(x, rel, loop=False):
    """Masters go to WAV_DIR (outside the repo); only the OGG lands in res://."""
    path = os.path.join(ROOT, rel); os.makedirs(os.path.dirname(path), exist_ok=True)
    wav = os.path.join(WAV_DIR, rel + ".wav"); os.makedirs(os.path.dirname(wav), exist_ok=True)
    wavfile.write(wav, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                    "-q:a", "5", path + ".ogg"], check=True)
    print(f"{rel}: {len(x)/SR:.2f}s  rms={np.sqrt(np.mean(x**2)):.3f} peak={np.max(np.abs(x)):.3f}")

# ---- MUSIC -------------------------------------------------------------------
def drum_pattern(bars, fill_last=True):
    k, s, h = [], [], []
    for bar in range(bars):
        k += seq("C1:1 -:1 C1:.5 C1:.5 -:1"); s += seq("-:1 C1:1 -:1 C1:1")
        h += seq(" ".join(["C1:.5"] * 8))
    return [("k", k, 1.0), ("s", s, 1.0), ("h", h, 1.0)]

def world1():
    """'Puffin Cove' - breezy F major seaside tune, 132 bpm, 4/4, 16 bars."""
    bpm = 132
    prog = [["F3","A3","C4","F2"],["C3","E3","G3","C2"],["D3","F3","A3","D2"],["Bb2","D3","F3","Bb1"],
            ["F3","A3","C4","F2"],["G3","Bb3","D4","G2"],["Bb2","D3","F3","Bb1"],["C3","E3","G3","C2"],
            ["D3","F3","A3","D2"],["A2","C3","E3","A1"],["Bb2","D3","F3","Bb1"],["F3","A3","C4","F2"],
            ["G3","Bb3","D4","G2"],["C3","E3","G3","C2"],["Bb2","D3","F3","Bb1"],["C3","E3","G3","C2"]]
    mel = seq(
        "C5:1 F5:.5 G5:.5 A5:1 G5:.5 F5:.5 "  "E5:1.5 D5:.5 C5:2 "
        "D5:.5 E5:.5 F5:1 A5:1 F5:1 "         "D5:1 Bb4:1 C5:2 "
        "A4:.5 C5:.5 F5:1 E5:.5 F5:.5 A5:1 "  "G5:1.5 F5:.5 D5:2 "
        "Bb4:.5 D5:.5 F5:1 G5:1 F5:1 "         "E5:3 -:1 "
        "A5:1 G5:.5 F5:.5 D5:1 F5:1 "          "E5:1 C#5:1 A4:2 "
        "Bb4:1 D5:1 F5:1.5 Bb5:.5 "            "A5:2 F5:2 "
        "G5:.5 A5:.5 Bb5:1 A5:.5 G5:.5 D5:1 "  "E5:1 G5:1 C6:2 "
        "Bb5:.5 A5:.5 G5:.5 F5:.5 D5:1 F5:1 "  "G5:2 E5:1 C5:1")
    bass = []
    for ch in prog:
        r, f5 = m(ch[3]), m(ch[3]) + 7
        bass += [(r, 1), (f5, .5), (r + 12, .5), (r, 1), (f5, 1)]
    arp = []
    for ch in prog:
        ns = [m(x) + 12 for x in ch[:3]]; arp += [(ns[i % 3] if i % 4 != 3 else ns[1], .5) for i in range(8)]
    pads = chords_to_notes(prog, 4, [0, 1, 2])
    tracks = [("flute", mel, 1.0), ("bass", bass, 1.0), ("bell", arp, 0.55)] + \
             [("pad", p, 1.0) for p in pads] + drum_pattern(16)
    x, N = render(tracks, bpm, 64)
    x = reverb(x)
    loop = x[:N].copy(); tail = x[N:]; loop[:len(tail)] += tail[:N]  # wrap tail -> seamless loop
    return finish(snes_color(loop), fade_in=0, fade_out=0)  # seamless: no edge fades

def title():
    """'Northern Wings' - stately C major fanfare into a gentle theme, ends on a held chord."""
    bpm = 108
    prog = [["C3","E3","G3","C2"],["A2","C3","E3","A1"],["F3","A3","C4","F2"],["G3","B3","D4","G2"],
            ["C3","E3","G3","C2"],["E3","G3","B3","E2"],["F3","A3","C4","F2"],["D3","F3","A3","D2"],
            ["F3","A3","C4","F2"],["G3","B3","D4","G2"],["E3","G3","C4","A1"],["F3","A3","D4","D2"],
            ["F3","A3","C4","F2"],["G3","B3","D4","G2"],["C3","E3","G3","C2"],["C3","E3","G3","C2"]]
    mel = seq(
        "G4:.75 G4:.25 C5:1 E5:1 G5:1 "   "A5:2 G5:1 E5:1 "
        "F5:1 A5:1 C6:1.5 A5:.5 "         "G5:3 D5:1 "
        "E5:1.5 F5:.5 G5:1 C5:1 "         "B4:1 D5:1 G5:2 "
        "A5:1 G5:.5 F5:.5 E5:1 C5:1 "     "D5:3 -:1 "
        "C5:.5 D5:.5 F5:1 A5:1 C6:1 "     "B5:1.5 A5:.5 G5:2 "
        "E5:1 G5:1 C6:1 B5:.5 A5:.5 "     "A5:1 F5:1 D5:2 "
        "F5:.5 G5:.5 A5:1 C6:1 A5:1 "     "G5:1 B4:1 D5:1 F5:1 "
        "E5:4 "                           "C5:4")
    lead2 = [(n - 12 if n else None, b) for n, b in mel]
    bass = []
    for ch in prog: r = m(ch[3]); bass += [(r, 1.5), (r + 7, .5), (r + 12, 1), (r + 7, 1)]
    bass[-4:] = [(m("C2"), 4)]
    pads = chords_to_notes(prog, 4, [0, 1, 2])
    k, s, h = [], [], []
    for bar in range(15):
        k += seq("C1:1.5 C1:.5 C1:1 -:1"); s += seq("-:1 C1:1 -:1 C1:.75 C1:.25"); h += seq(" ".join(["C1:.5"]*8))
    k += seq("C1:4"); s += seq("C1:4"); h += seq("-:4")
    tracks = [("lead", mel, 1.0), ("bell", lead2, 0.5), ("bass", bass, 1.0)] + \
             [("pad", p, 1.3) for p in pads] + [("k", k, 1), ("s", s, 1), ("h", h, 1)]
    x, N = render(tracks, bpm, 64)
    x = reverb(x, 0.25)[:N + int(2.0 * SR)]
    return finish(snes_color(x), fade_in=0.005, fade_out=1.5)

# ---- SFX ---------------------------------------------------------------------
def sweep_pulse(f0, f1, dur, duty=0.5, curve="exp"):
    n = int(dur * SR); tt = np.linspace(0, 1, n)
    f = f0 * (f1 / f0) ** tt if curve == "exp" else f0 + (f1 - f0) * tt
    ph = np.cumsum(f) / SR; return np.where(ph % 1 < duty, 1.0, -1.0)

def sfx_jump():
    x = sweep_pulse(330, 880, 0.16, 0.25); return x * env(len(x), 0.002, 0.05, 0.6, 0.06)
def sfx_land():
    n = int(0.09 * SR); tt = t_(n)
    x = lp(noise(n), 900) * 2 + np.sin(2*np.pi*np.cumsum(140*np.exp(-tt*25)+50)/SR)
    return x * np.exp(-tt * 45)
def sfx_skid():
    n = int(0.28 * SR); tt = t_(n)
    x = lp(hp(noise(n), 1500), 5000) * (0.7 + 0.3 * np.sign(np.sin(2*np.pi*38*tt)))
    return x * env(n, 0.01, 0.05, 0.8, 0.12)
def sfx_death():
    parts = []
    for i, (a, b) in enumerate([(784, 740), (659, 622), (523, 494), (392, 330)]):
        s = sweep_pulse(a, b, 0.14 if i < 3 else 0.5, 0.5); parts.append(s * env(len(s), 0.002, 0.03, 0.7, 0.04))
    return np.concatenate(parts)
def sfx_fish():
    out = []
    for f in (hz(84), hz(91)):
        n = int(0.09 * SR) if f == hz(84) else int(0.28 * SR); tt = t_(n)
        out.append((np.sin(2*np.pi*f*tt) + 0.5*pulse(f, n, 0.125)) * np.exp(-tt * (25 if n < 4000 else 9)))
    return np.concatenate(out)
def sfx_powerup():
    notes = [60, 64, 67, 72, 65, 69, 72, 77, 67, 71, 74, 79, 84]
    out = []
    for i, nn in enumerate(notes):
        n = int((0.05 if i < len(notes) - 1 else 0.35) * SR)
        s = pulse(hz(nn), n, 0.25 if i % 2 else 0.5) * 0.6 + tri(hz(nn - 12), n) * 0.4
        out.append(s * env(n, 0.002, 0.02, 0.8, 0.01 if i < len(notes) - 1 else 0.25))
    return np.concatenate(out)
def sfx_stomp():
    n = int(0.18 * SR); tt = t_(n)
    body = np.sin(2*np.pi*np.cumsum(260*np.exp(-tt*18)+60)/SR) * np.exp(-tt * 18)
    click = lp(noise(n), 4000) * np.exp(-tt * 90)
    pop = sweep_pulse(600, 1200, 0.18, 0.5) * np.exp(-tt * 25) * 0.4
    return body + click * 0.6 + pop

def sfx_hurt():
    """Hurt / power-down: a wobbling pulse that tumbles down in uneven steps,
    with a short noise 'ouch' transient at the hit."""
    steps = [(79, 74), (75, 70), (72, 66), (68, 61), (63, 56)]
    out = []
    for i, (a, b) in enumerate(steps):
        dur = 0.075 if i < len(steps) - 1 else 0.22
        n = int(dur * SR)
        hi, lo = hz(a), hz(b)
        half = n // 2
        seg = np.concatenate([sweep_pulse(hi, hi * 0.97, half / SR, 0.5),
                              sweep_pulse(lo, lo * 0.94, (n - half) / SR, 0.25)])[:n]
        seg = seg * 0.7 + tri(lo / 2, len(seg)) * 0.3
        out.append(seg * env(len(seg), 0.002, 0.02, 0.85, 0.015 if i < len(steps) - 1 else 0.15))
    x = np.concatenate(out)
    hit = int(0.04 * SR)
    x[:hit] += lp(noise(hit), 3500) * np.exp(-t_(hit) * 80) * 0.8
    return x

SFX = dict(jump=sfx_jump, land=sfx_land, skid=sfx_skid, death=sfx_death,
           collect_fish=sfx_fish, powerup=sfx_powerup, stomp=sfx_stomp, hurt=sfx_hurt)

SFX_TAIL_FADE = 0.025  # 25 ms tail fade on every SFX: avoids Vorbis ringing at the cut
TRANSIENT_SFX = {"land", "skid", "stomp"}

if __name__ == "__main__":
    save(title(), "audio/music/title_theme")
    save(world1(), "audio/music/world1_theme", loop=True)
    for name, fn in SFX.items():
        x = fn(); x = reverb(np.concatenate([x, np.zeros(int(0.25 * SR))]), 0.08)
        if name in TRANSIENT_SFX:  # soft-limit punchy hits so they can match the others' loudness
            x = np.tanh(4 * x / np.max(np.abs(x)))
        nz = np.nonzero(np.abs(x) > 1e-3)[0]; x = x[: nz[-1] + 1]
        save(finish(snes_color(x), 0.9, fade_out=SFX_TAIL_FADE, rms=0.16), f"audio/sfx/{name}")  # loudness-matched
