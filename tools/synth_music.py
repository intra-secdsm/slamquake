#!/usr/bin/env python3
"""Synthesizes the game's music and crowd ambience (original, procedural, deterministic).

    tools/synth_music.sh        -> game/assets/audio/music/*.wav, game/assets/audio/sfx/crowd_*_loop.wav

Runs with Blender's bundled Python (it has numpy). Every melody, riff and drum pattern
here is written for this game; nothing is sampled. Loops are rendered to an exact bar
count so they repeat seamlessly.
"""
import struct
import wave
from pathlib import Path

import numpy as np

R = 22050
ROOT = Path(__file__).resolve().parents[1]
MUSIC = ROOT / "game/assets/audio/music"
SFX = ROOT / "game/assets/audio/sfx"


# ---------------------------------------------------------------- building blocks

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def tt(dur):
    return np.arange(int(dur * R)) / R


def adsr(n, a=0.005, d=0.1, s=0.7, r=0.05):
    t = np.arange(n) / R
    dur = n / R
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((dur - t) / max(r, 1e-4), 0, 1)
    return env * rel


def lowpass(x, cutoff, order=2):
    if len(x) < 4:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / R)
    spec *= 1 / (1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(spec, len(x))


def bandpass(x, lo, hi):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / R)
    spec *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec, len(x))


def saw(f, dur, detune=0.0):
    t = tt(dur)
    return ((t * f * (1 + detune)) % 1.0) * 2 - 1


def pulse(f, dur, width=0.5, vib=0.0):
    t = tt(dur)
    ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.5 * t))) / R
    return np.where(ph % 1.0 < width, 1.0, -1.0)


class Track:
    def __init__(self, bpm, bars, seed):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.buf = np.zeros(int(bars * 4 * self.beat * R) + R * 2)
        self.rng = np.random.default_rng(seed)

    def at(self, bar, beat):
        return int((bar * 4 + beat) * self.beat * R)

    def add(self, start, sig, gain=1.0):
        end = min(len(self.buf), start + len(sig))
        self.buf[start:end] += sig[:end - start] * gain

    # drums
    def kick(self, bar, beat, gain=1.0):
        t = tt(0.35)
        f = 42 + 95 * np.exp(-t / 0.035)
        self.add(self.at(bar, beat), np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t / 0.13), gain)

    def snare(self, bar, beat, gain=1.0):
        t = tt(0.25)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 900, 7000) * np.exp(-t / 0.07)
        tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.04)
        self.add(self.at(bar, beat), n * 1.6 + tone * 0.6, gain)

    def clap(self, bar, beat, gain=1.0):
        t = tt(0.2)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 1000, 4000)
        env = sum(np.exp(-np.maximum(t - k * 0.011, 0) / 0.01) * (t >= k * 0.011) for k in range(3))
        self.add(self.at(bar, beat), n * env * np.exp(-t / 0.06) * 1.8, gain)

    def hat(self, bar, beat, gain=1.0, open_=False):
        t = tt(0.25 if open_ else 0.06)
        n = np.diff(self.rng.uniform(-1, 1, len(t) + 1)) * np.exp(-t / (0.08 if open_ else 0.015))
        self.add(self.at(bar, beat), n * 0.35, gain)

    def crash(self, bar, beat, gain=1.0):
        t = tt(2.0)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 3000, 10000) * np.exp(-t / 0.6)
        self.add(self.at(bar, beat), n * 1.5, gain)

    def tom(self, bar, beat, note, gain=1.0):
        t = tt(0.4)
        f = midi(note) * (1 + 0.5 * np.exp(-t / 0.02))
        self.add(self.at(bar, beat), np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t / 0.18), gain)

    # pitched
    def bass(self, bar, beat, note, beats, gain=1.0, cutoff=700):
        dur = beats * self.beat
        s = saw(midi(note), dur) + 0.5 * saw(midi(note), dur, 0.004)
        s = lowpass(s, cutoff) * adsr(len(s), 0.004, 0.15, 0.6, 0.03)
        self.add(self.at(bar, beat), s, gain)

    def pad(self, bar, beat, notes, beats, gain=1.0, cutoff=1600):
        dur = beats * self.beat
        s = sum(saw(midi(n), dur, d) for n in notes for d in (-0.003, 0.003))
        s = lowpass(s, cutoff) * adsr(len(s), 0.25, 0.5, 0.8, 0.3)
        self.add(self.at(bar, beat), s / len(notes), gain)

    def lead(self, bar, beat, note, beats, gain=1.0, width=0.3, cutoff=3500):
        dur = beats * self.beat
        s = lowpass(pulse(midi(note), dur, width, vib=0.006), cutoff) * adsr(int(dur * R), 0.01, 0.2, 0.7, 0.05)
        self.add(self.at(bar, beat), s, gain)
        # slap-back echo
        self.add(self.at(bar, beat) + int(self.beat * 0.75 * R), s, gain * 0.3)

    def guitar(self, bar, beat, root, beats, gain=1.0, mute=False):
        """Distorted power chord: root, fifth, octave through a soft clipper."""
        dur = beats * self.beat * (0.45 if mute else 1.0)
        s = sum(saw(midi(n), dur, d) for n in (root, root + 7, root + 12) for d in (-0.002, 0.002))
        s = np.tanh(s * 3.5)
        s = lowpass(s, 1400 if mute else 2800) * adsr(len(s), 0.003, 0.25, 0.75, 0.04)
        self.add(self.at(bar, beat), s, gain)

    def brass(self, bar, beat, notes, beats, gain=1.0):
        dur = beats * self.beat
        s = sum(saw(midi(n), dur, d) for n in notes for d in (-0.004, 0.0, 0.004))
        cut = 600 + 2600 * (1 - np.exp(-tt(dur) / 0.08))
        # crude swept filter: blend a dark and a bright version by the sweep
        dark, bright = lowpass(s, 600), lowpass(s, 3200)
        k = (cut - 600) / 2600
        s = (dark * (1 - k) + bright * k) * adsr(len(s), 0.02, 0.3, 0.8, 0.15)
        self.add(self.at(bar, beat), s / len(notes), gain)

    def render(self):
        n = int(self.bars * 4 * self.beat * R)
        out = self.buf[:n].copy()
        out[:len(self.buf) - n] += self.buf[n:]      # wrap tails into the start for a clean loop
        return out


def write(path, x, peak=0.85, tone=None):
    if tone:
        x = lowpass(x, tone, order=1)       # warm the mix up: tame fizzy saws and hats
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.4)
    x = x / np.max(np.abs(x)) * peak
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(f"wrote {path.relative_to(ROOT)} ({len(x) / R:.1f}s)")


# ---------------------------------------------------------------- songs

def menu_theme():
    """Synthwave title theme, A minor, Am-F-C-G."""
    s = Track(108, 16, 1)
    chords = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [55, 60, 64]), (55, [55, 59, 62])]
    melody = [(76, 1.5), (74, 0.5), (72, 1), (71, 1), (72, 1.5), (74, 0.5), (76, 2),
              (77, 1.5), (76, 0.5), (74, 1), (72, 1), (71, 2), (67, 2),
              (76, 1.5), (74, 0.5), (72, 1), (76, 1), (79, 2), (77, 1), (76, 1),
              (74, 1), (72, 1), (71, 1), (72, 1), (69, 4)]
    for bar in range(16):
        root, notes = chords[bar % 4]
        s.pad(bar, 0, notes, 4, 0.5)
        for e in range(8):
            s.bass(bar, e * 0.5, root - 12 + (12 if e % 2 else 0), 0.45, 0.7)
        for k in range(16):
            s.lead(bar, k * 0.25, notes[k % 3] + 12 + (12 if k % 8 >= 6 else 0), 0.2, 0.12, width=0.5, cutoff=2500)
        s.kick(bar, 0)
        s.kick(bar, 2)
        s.snare(bar, 1, 0.8)
        s.snare(bar, 3, 0.8)
        for e in range(8):
            s.hat(bar, e * 0.5, 0.5 if e % 2 else 0.3)
    pos = 8 * 4.0
    for note, beats in melody:
        bar, beat = divmod(pos, 4)
        if bar < 16:
            s.lead(int(bar), beat, note, beats * 0.95, 0.45)
        pos += beats
    s.crash(0, 0, 0.6)
    s.crash(8, 0, 0.6)
    return s.render()


def thunder_theme():
    """Thunder Mack: driving hard rock in E."""
    s = Track(132, 16, 2)
    riff = [40, 40, 43, 40, 45, 40, 43, 42]      # E5 E5 G5 E5 A5 E5 G5 F#5 (eighths)
    lead = [(64, 1), (67, 1), (69, 1.5), (67, 0.5), (64, 2), (62, 1), (64, 1),
            (67, 1), (69, 1), (71, 1.5), (69, 0.5), (67, 1), (69, 1), (64, 2),
            (64, 1), (67, 1), (69, 1.5), (71, 0.5), (72, 2), (71, 1), (69, 1),
            (67, 1), (69, 1), (67, 1), (64, 1), (64, 4)]
    for bar in range(16):
        turn = bar % 4 == 3
        for e, n in enumerate(riff):
            if turn and e >= 4:
                n = [45, 45, 47, 47][e - 4]
            s.guitar(bar, e * 0.5, n, 0.5, 0.55, mute=e % 2 == 1)
            s.bass(bar, e * 0.5, n - 12, 0.45, 0.6, cutoff=500)
        for b in (0, 1.5, 2, 3.5) if bar % 2 else (0, 2, 2.5):
            s.kick(bar, b)
        s.snare(bar, 1)
        s.snare(bar, 3)
        for e in range(8):
            s.hat(bar, e * 0.5, 0.4, open_=(e == 7))
        if bar in (7, 15):
            for k, tn in enumerate((50, 47, 45, 43)):
                s.tom(bar, 3 + k * 0.25, tn, 0.8)
    pos = 8 * 4.0
    for note, beats in lead:
        bar, beat = divmod(pos, 4)
        if bar < 16:
            s.guitar(int(bar), beat, note - 12, beats * 0.95, 0.35)
        pos += beats
    s.crash(0, 0)
    s.crash(8, 0)
    return s.render()


def zip_theme():
    """Zip Volta: fast electro in D minor with a buzzing arpeggio."""
    s = Track(148, 16, 3)
    prog = [(50, [62, 65, 69]), (46, [58, 62, 65]), (48, [60, 64, 67]), (45, [57, 61, 64])]
    hook = [74, 77, 81, 77, 74, 72, 74, 69]
    for bar in range(16):
        root, notes = prog[bar % 4]
        for b in range(4):
            s.kick(bar, b)
            s.hat(bar, b + 0.5, 0.6, open_=True)
        s.clap(bar, 1)
        s.clap(bar, 3)
        for k in range(16):
            s.bass(bar, k * 0.25, root - 12 + (12 if k % 2 else 0), 0.22, 0.55, cutoff=900)
            s.hat(bar, k * 0.25, 0.2)
            s.lead(bar, k * 0.25, notes[(k * 2) % 3] + 12, 0.2, 0.18, width=0.25, cutoff=4000)
        if bar >= 8:
            for k, n in enumerate(hook):
                s.lead(bar, k * 0.5, n + (2 if bar % 4 == 3 and k > 5 else 0), 0.45, 0.4, width=0.4)
        s.pad(bar, 0, notes, 4, 0.25, cutoff=1200)
    s.crash(0, 0)
    s.crash(8, 0)
    return s.render()


def bruno_theme():
    """Bruno Kessler: slow, heavy, ominous; low power chords and toms."""
    s = Track(84, 8, 4)
    roots = [36, 36, 37, 36, 36, 36, 39, 37]
    for bar in range(8):
        r = roots[bar]
        s.guitar(bar, 0, r, 1.5, 0.7)
        s.guitar(bar, 1.5, r, 0.5, 0.5, mute=True)
        s.guitar(bar, 2, r + (1 if bar % 2 else 3), 2, 0.6)
        s.bass(bar, 0, r - 12, 4, 0.7, cutoff=300)
        s.kick(bar, 0, 1.2)
        s.kick(bar, 1.5, 0.9)
        s.snare(bar, 2, 1.1)
        s.tom(bar, 3, 45, 0.7)
        s.tom(bar, 3.5, 41, 0.8)
        for b in range(4):
            s.hat(bar, b, 0.35)
        if bar >= 4:
            s.lead(bar, 0, 60, 1.8, 0.25, width=0.15, cutoff=1800)
            s.lead(bar, 2, 61, 1.8, 0.25, width=0.15, cutoff=1800)
    s.crash(0, 0, 1.2)
    s.crash(4, 0, 1.0)
    return s.render()


def victory_sting():
    """Short fanfare for the winner."""
    s = Track(120, 2, 5)
    s.brass(0, 0, [60, 64, 67], 0.5, 0.9)
    s.brass(0, 0.5, [60, 64, 67], 0.5, 0.9)
    s.brass(0, 1, [65, 69, 72], 1, 0.9)
    s.brass(0, 2, [67, 71, 74], 1, 0.9)
    s.brass(0, 3, [72, 76, 79], 4.5, 1.0)
    for k in range(8):
        s.snare(0, 2 + k * 0.125, 0.4 + k * 0.06)
    s.kick(0, 3, 1.2)
    s.crash(0, 3, 1.0)
    out = s.buf[:int(4 * s.beat * R * 2)]
    return out * np.clip((len(out) / R - tt(len(out) / R)) / 0.4, 0, 1)


# ---------------------------------------------------------------- crowd ambience loops

def crowd_loop(seconds, formants, width, swell, claps, seed, rumble=0.3):
    rng = np.random.default_rng(seed)
    n = int((seconds + 1.0) * R)
    t = np.arange(n) / R
    noise = rng.uniform(-1, 1, n)
    spec = np.fft.rfft(noise)
    f = np.fft.rfftfreq(n, 1 / R)
    shape = sum(np.exp(-((f - fc) / (fc * width)) ** 2) for fc in formants) + rumble * np.exp(-(f / 250) ** 2)
    x = np.fft.irfft(spec * shape, n)
    # many voices swelling at different rates
    mod = 1 + swell * sum(np.sin(2 * np.pi * rng.uniform(0.2, 1.4) * t + rng.uniform(0, 6.3)) for _ in range(6)) / 6
    x *= mod
    for _ in range(claps):
        c = int(rng.uniform(0, n - R * 0.05))
        k = tt(0.03)
        x[c:c + len(k)] += bandpass(rng.uniform(-1, 1, len(k)), 1200, 5000) * np.exp(-k / 0.006) * 0.25
    # crossfade the extra second into the start so it loops
    m = int(seconds * R)
    fade = np.linspace(0, 1, n - m)
    out = x[:m].copy()
    out[:n - m] = out[:n - m] * fade + x[m:] * (1 - fade)
    return out


def main():
    write(MUSIC / "theme_menu.wav", tone=4500, x=menu_theme())
    write(MUSIC / "theme_thunder.wav", tone=4500, x=thunder_theme())
    write(MUSIC / "theme_zip.wav", tone=4500, x=zip_theme())
    write(MUSIC / "theme_bruno.wav", tone=4500, x=bruno_theme())
    write(MUSIC / "victory.wav", tone=4500, x=victory_sting())
    write(SFX / "crowd_murmur_loop.wav", crowd_loop(8.0, (420, 700, 1100), 0.35, 0.25, 0, 11), peak=0.6)
    write(SFX / "crowd_cheer_loop.wav", crowd_loop(8.0, (520, 900, 1500, 2600), 0.45, 0.4, 260, 12, 0.5), peak=0.8)


if __name__ == "__main__":
    main()
