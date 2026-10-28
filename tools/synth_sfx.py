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


def bell(length, seed):
    """Ring bell: inharmonic partials with long decays."""
    partials = [(820, 1.0, 1.2), (1640 * 1.01, 0.5, 0.8), (2290, 0.35, 0.5), (3170, 0.2, 0.3), (410, 0.3, 1.0)]

    def fn(t, rnd):
        strike = rnd.uniform(-1, 1) * env(t, 0.0005, 0.006) * 0.5
        return strike + sum(a * math.sin(2 * math.pi * f * t) * env(t, 0.001, d) for f, a, d in partials)
    return render(length, fn, seed)


def clang(length, seed):
    """Steel chair shot: bright inharmonic ring over a hard thump."""
    partials = [(523, 1.0, 0.18), (1187, 0.7, 0.12), (1871, 0.5, 0.09), (2711, 0.35, 0.06), (3990, 0.2, 0.04)]
    lp = Lowpass(1200)

    def fn(t, rnd):
        hit = lp(rnd.uniform(-1, 1)) * env(t, 0.0005, 0.03) * 3
        return hit + sum(a * math.sin(2 * math.pi * f * t) * env(t, 0.0005, d) for f, a, d in partials)
    return render(length, fn, seed)


def crash(length, seed):
    """Table breaking: splintering cracks plus a heavy body thud."""
    rnd0 = random.Random(seed)
    cracks = sorted(rnd0.uniform(0.0, 0.18) for _ in range(9))
    lp, lp2 = Lowpass(2500), Lowpass(500)
    phase = [0.0]

    def fn(t, rnd):
        x = 0.0
        for c in cracks:
            if t >= c:
                x += rnd.uniform(-1, 1) * math.exp(-(t - c) / 0.012)
        phase[0] += 2 * math.pi * (70 + 40 * math.exp(-t / 0.04)) / RATE
        thud = math.sin(phase[0]) * env(t, 0.002, 0.12) * 1.5
        rumble = lp2(rnd.uniform(-1, 1)) * env(t, 0.01, 0.25) * 2
        return lp(x) * 2 + thud + rumble
    return render(length, fn, seed)


class Resonator:
    """Two-pole band-pass: gives filtered noise a vowel-like formant."""
    def __init__(self, freq, r):
        self.c1 = 2 * r * math.cos(2 * math.pi * freq / RATE)
        self.c2 = -r * r
        self.y1 = self.y2 = 0.0

    def __call__(self, x):
        y = x * 0.05 + self.c1 * self.y1 + self.c2 * self.y2
        self.y2, self.y1 = self.y1, y
        return y


def crowd(length, seed, rise, hold, formants, claps=0):
    """A crowd reaction: many voices as formant-filtered noise, swelling and fading."""
    res = [Resonator(f, 0.985) for f in formants]
    lp = Lowpass(3000)
    rnd0 = random.Random(seed)
    clap_t = sorted(rnd0.uniform(0.1, length * 0.8) for _ in range(claps))
    wob = [rnd0.uniform(0, 6.28) for _ in range(4)]

    def fn(t, rnd):
        a = min(1.0, t / rise) if t < rise + hold else math.exp(-(t - rise - hold) / (length * 0.25))
        flutter = 1 + 0.15 * sum(math.sin(2 * math.pi * (3 + k * 1.7) * t + wob[k]) for k in range(4)) / 4
        n = rnd.uniform(-1, 1)
        voice = sum(r(n) for r in res) + lp(n) * 0.25
        c = 0.0
        for ct in clap_t:
            if 0 <= t - ct < 0.02:
                c += rnd.uniform(-1, 1) * math.exp(-(t - ct) / 0.004) * 0.5
        return (voice * flutter + c) * a
    return render(length, fn, seed)


def zap(length, seed):
    """Special ready: a bright rising arpeggio with a shimmer."""
    notes = [440, 554, 659, 880, 1109]

    def fn(t, rnd):
        i = min(len(notes) - 1, int(t / (length * 0.12)))
        f = notes[i] * (1 + 0.004 * math.sin(2 * math.pi * 7 * t))
        sq = 1.0 if (t * f) % 1.0 < 0.5 else -1.0
        shimmer = math.sin(2 * math.pi * f * 2.01 * t) * 0.4
        return (sq * 0.35 + shimmer) * env(t, 0.005, length * 0.45)
    return render(length, fn, seed)


def parry(length, seed):
    """Reversal/parry: a sharp slap with a short metallic ping."""
    slap = thump(420, 260, length, 5000, 0.6, seed, click=1.0)
    return [x + 0.6 * math.sin(2 * math.pi * 1760 * i / RATE) * env(i / RATE, 0.001, 0.05)
            for i, x in enumerate(slap)]


def boom(length, seed):
    """Finisher impact: a big body slam over a deep sub boom."""
    body = thump(85, 38, length, 800, 1.0, seed, click=0.4)
    out = []
    for i, x in enumerate(body):
        t = i / RATE
        out.append(x + 1.2 * math.sin(2 * math.pi * (32 + 30 * math.exp(-t / 0.08)) * t) * env(t, 0.003, 0.35))
    return out


def pyro(length, seed):
    """Entrance pyro: a deep whoomp followed by crackling sparks."""
    rnd0 = random.Random(seed)
    pops = sorted(rnd0.uniform(0.15, length * 0.9) for _ in range(70))
    lp, lp2 = Lowpass(300), Lowpass(4000)
    phase = [0.0]

    def fn(t, rnd):
        phase[0] += 2 * math.pi * (40 + 60 * math.exp(-t / 0.08)) / RATE
        boom = math.sin(phase[0]) * env(t, 0.004, 0.35) * 1.4 + lp(rnd.uniform(-1, 1)) * env(t, 0.01, 0.4) * 4
        crackle = 0.0
        for p in pops:
            if 0 <= t - p < 0.01:
                crackle += rnd.uniform(-1, 1) * math.exp(-(t - p) / 0.002)
        return boom + lp2(crackle) * 1.2
    return render(length, fn, seed)


def triple(samples, gap):
    out = [0.0] * (len(samples) + 2 * int(gap * RATE))
    for k in range(3):
        o = k * int(gap * RATE)
        for i, x in enumerate(samples):
            out[o + i] += x
    return out


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
    "mat_slap": lambda: thump(240, 120, 0.12, 3500, 0.7, 7, click=0.9),
    "bell": lambda: bell(1.6, 8),
    "chair_hit": lambda: clang(0.5, 10),
    "table_crash": lambda: crash(0.9, 11),
    "bell_triple": lambda: triple(bell(1.4, 9), 0.32),
    "special_ready": lambda: zap(0.7, 12),
    "parry": lambda: parry(0.18, 13),
    "finisher_impact": lambda: boom(1.1, 14),
    "crowd_pop": lambda: crowd(3.2, 15, 0.25, 0.9, (480, 820, 1350), claps=40),
    "crowd_ooh": lambda: crowd(1.6, 16, 0.2, 0.3, (420, 760)),
    "pyro": lambda: pyro(2.2, 17),
}

if __name__ == "__main__":
    for name, make in SOUNDS.items():
        write(name, make())
