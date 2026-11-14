#!/usr/bin/env python3
"""Generates the placeholder soundtrack: three original EDM loops, synthesised from scratch.

They're placeholders so the game has music now. Replace any of them with a licensed track
by saving it over the same file name in assets/music/ (see README, "Music").

Each loop is exactly 32 bars and wraps seamlessly (decay tails are folded back to the start).
Needs numpy and ffmpeg with libvorbis.   Run:  python3 tools/music/make_tracks.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "music")
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


class Track:
    def __init__(self, bpm, bars=32):
        self.bpm, self.bars = bpm, bars
        # a whole number of samples per beat, so the sidechain pump lines up exactly at the loop point
        self.beat_n = int(round(SR * 60.0 / bpm))
        self.beat = self.beat_n / SR
        self.n = self.beat_n * 4 * bars
        self.bus = {k: np.zeros(self.n) for k in ("kick", "drums", "bass", "pad", "lead")}

    def at(self, bar, beat):
        return int(round((bar * 4 + beat) * self.beat_n))

    def add(self, bus, start, sig):
        idx = (start + np.arange(len(sig))) % self.n  # wrap tails -> seamless loop
        np.add.at(self.bus[bus], idx, sig)


def env(n, attack=0.005, decay=0.2):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def kick(punch=1.0):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * punch + 0.3 * np.sin(ph * 2) * np.exp(-t * 40)


def noise_hit(dur, decay, hp=True):
    n = int(dur * SR)
    x = rng.standard_normal(n)
    if hp:
        x = np.diff(x, prepend=0)
    return x * env(n, 0.001, decay)


def clap():
    s = noise_hit(0.25, 0.08) * 0.5
    for d in (0.008, 0.017):
        k = int(d * SR)
        s[k:] += noise_hit(0.25, 0.06)[: len(s) - k] * 0.35
    return s


def saw(freq, n, detune=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune, 0, detune) if detune else (0,):
        f = freq * (1 + d)
        out += 2 * ((t * f) % 1.0) - 1
    return out / (3 if detune else 1)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):  # one-pole; fine for short notes
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def square(freq, n, duty=0.5):
    t = np.arange(n) / SR
    return np.where((t * freq) % 1.0 < duty, 1.0, -1.0)


def build(name, bpm, root, prog, arp_rate, grit, lead_line):
    tr = Track(bpm)
    beat_n = tr.beat_n
    k = kick()
    for bar in range(tr.bars):
        intro = bar < 8
        chord = prog[(bar // 2) % len(prog)]                 # 2 bars per chord
        for b in range(4):
            tr.add("kick", tr.at(bar, b), k)
            # off-beat hats, 16ths once the drop starts
            tr.add("drums", tr.at(bar, b + 0.5), noise_hit(0.05, 0.02) * 0.22)
            if not intro:
                for s in (0.25, 0.75):
                    tr.add("drums", tr.at(bar, b + s), noise_hit(0.03, 0.012) * 0.10)
            if not intro and b in (1, 3):
                tr.add("drums", tr.at(bar, b), clap() * 0.55)
            # off-beat bass on the chord root
            if not intro:
                n = int(beat_n * 0.45)
                f = midi(root + chord[0] - 12)
                bass = lowpass(saw(f, n, 0.004), 900 + 600 * grit) * env(n, 0.003, 0.18)
                if grit:
                    bass = np.tanh(bass * (1 + 3 * grit))
                tr.add("bass", tr.at(bar, b + 0.5), bass * 0.5)
        # pad: whole bar, detuned saws, soft
        if bar % 2 == 0:
            n = int(beat_n * 8)
            pad = sum(saw(midi(root + 12 + iv), n, 0.006) for iv in chord) / len(chord)
            pad = lowpass(pad, 1400) * env(n, 0.25, 3.5) * 0.18
            tr.add("pad", tr.at(bar, 0), pad)
        # arpeggio after bar 8, lead melody in the last 8 bars
        if not intro:
            steps = 4 * arp_rate
            for s in range(steps):
                iv = chord[s % len(chord)] + (12 if (s // len(chord)) % 2 else 0)
                n = int(beat_n / arp_rate * 0.9)
                note = square(midi(root + 24 + iv), n, 0.3) * env(n, 0.002, 0.07) * 0.07
                tr.add("lead", tr.at(bar, s / arp_rate), note)
        if bar >= 24:
            for step, iv in enumerate(lead_line[(bar % 2) * 8:(bar % 2) * 8 + 8]):
                if iv is None:
                    continue
                n = int(beat_n * 0.5)
                f = midi(root + 24 + iv)
                note = (saw(f, n, 0.01) * 0.6 + square(f * 2, n, 0.5) * 0.2) * env(n, 0.004, 0.25) * 0.12
                tr.add("lead", tr.at(bar, step * 0.5), note)

    # sidechain: everything but the kick ducks on each beat (the EDM "pump")
    t = (np.arange(tr.n) % beat_n) / SR
    duck = 1 - 0.75 * np.exp(-t / 0.09)
    mix = tr.bus["kick"] * 0.9 + tr.bus["drums"] + (tr.bus["bass"] + tr.bus["pad"] + tr.bus["lead"]) * duck
    mix = np.tanh(mix * 1.3)
    mix *= 0.55 / np.max(np.abs(mix))  # ~-5 dB peak: Vorbis overshoots bright sounds by up to ~3 dB

    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((mix * 32767).astype(np.int16).tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
        os.unlink(tmp.name)
    print(f"{name}.ogg  {bpm} BPM  {tr.n / SR:.1f}s  {os.path.getsize(dst) // 1024} KB")


if __name__ == "__main__":
    # name, bpm, root note, chord progression (semitones from root), arp notes per beat, bass grit, lead (8th notes, 2 bars)
    build("neon_drive", 124, 57, [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]], 4, 0.0,
          [12, None, 10, 7, None, 7, 5, 3, 7, None, 5, 3, None, 0, None, None])
    build("overclock", 128, 54, [[0, 3, 7], [-4, 0, 3], [-9, -5, -2], [-2, 2, 5]], 4, 0.6,
          [7, 7, None, 10, None, 12, 10, 7, 5, None, 3, 5, 7, None, 0, None])
    build("final_exam", 136, 50, [[0, 3, 7], [-4, 0, 3], [-9, -5, -2], [-2, 2, 5]], 6, 0.9,
          [12, 15, 12, 10, 12, None, 7, None, 10, 12, 10, 7, 5, 7, None, None])
