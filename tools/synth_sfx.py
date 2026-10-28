#!/usr/bin/env python3
"""Synthesizes placeholder impact sounds (pure stdlib, deterministic).

    python3 tools/synth_sfx.py      -> game/assets/audio/sfx/*.wav

These are original procedural sounds (no third-party audio). Recorded CC0 audio
replaces or layers on top of them in the presentation milestone.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "game/assets/audio/sfx"


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


class Lowpass:
    def __init__(self, cutoff):
        self.a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
        self.y = 0.0

    def __call__(self, x):
        self.y += self.a * (x - self.y)
        return self.y


def render(length, fn, seed):
    rnd = random.Random(seed)
    return [fn(i / RATE, rnd) for i in range(int(length * RATE))]


def thump(freq_start, freq_end, length, noise_cut, noise_amt, seed, click=0.3):
    lp = Lowpass(noise_cut)
    phase = [0.0]

    def fn(t, rnd):
        f = freq_end + (freq_start - freq_end) * math.exp(-t / 0.03)
        phase[0] += 2 * math.pi * f / RATE
        body = math.sin(phase[0]) * env(t, 0.002, length * 0.35)
        n = lp(rnd.uniform(-1, 1)) * noise_amt * env(t, 0.001, length * 0.18)
        c = rnd.uniform(-1, 1) * click * env(t, 0.0005, 0.004)
        return body + n * 3 + c
    return render(length, fn, seed)


def whoosh(length, seed):
    lp1, lp2 = Lowpass(300), Lowpass(300)

    def fn(t, rnd):
        cut = 400 + 2600 * math.sin(math.pi * t / length)
        lp1.a = 1 - math.exp(-2 * math.pi * cut / RATE)
        lp2.a = lp1.a
        x = rnd.uniform(-1, 1)
        band = lp1(x) - lp2(lp1.y) * 0.6
        return band * math.sin(math.pi * t / length) ** 2 * 1.6
    return render(length, fn, seed)


def rope(length, seed):
    lp = Lowpass(900)

    def fn(t, rnd):
        f = 72 * (1 + 0.02 * math.sin(2 * math.pi * 6 * t))
        saw = ((t * f) % 1.0) * 2 - 1
        creak = lp(rnd.uniform(-1, 1)) * env(t, 0.003, 0.05) * 2.5
        return lp(saw) * env(t, 0.004, 0.18) * 0.9 + creak
    return render(length, fn, seed)


def normalize(samples, peak=0.9):
    m = max(abs(s) for s in samples) or 1.0
    return [s * peak / m for s in samples]


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in normalize(samples))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"wrote {name}.wav")


SOUNDS = {
    "hit_light": lambda: thump(180, 95, 0.16, 2500, 0.35, 1, click=0.6),
    "hit_heavy": lambda: thump(140, 62, 0.26, 1600, 0.5, 2, click=0.8),
    "block": lambda: thump(320, 220, 0.09, 4000, 0.4, 3, click=0.4),
    "body_fall": lambda: thump(90, 42, 0.55, 700, 0.9, 4, click=0.2),
    "whoosh": lambda: whoosh(0.22, 5),
    "rope": lambda: rope(0.45, 6),
}

if __name__ == "__main__":
    for name, make in SOUNDS.items():
        write(name, make())
