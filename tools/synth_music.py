#!/usr/bin/env python3
"""Synthesizes the game's music and crowd ambience (original, procedural, deterministic).

    tools/synth_music.sh        -> game/assets/audio/music/*.wav, game/assets/audio/sfx/crowd_*_loop.wav

Runs with Blender's bundled Python (it has numpy). Every melody, riff and drum pattern
here is written for this game; nothing is sampled. Loops are rendered to an exact bar
count so they repeat seamlessly.
"""
import functools
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


PITCH = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def notes(text):
    """Melody shorthand -> [(midi, beats)]: 'Bb4/.5 D5 r/2' (1 beat unless given; r rests)."""
    out = []
    for tok in text.split():
        name, _, beats = tok.partition("/")
        note = None
        if name != "r":
            acc = name[1:-1]
            note = 12 * (int(name[-1]) + 1) + PITCH[name[0]] + acc.count("#") - acc.count("b")
        out.append((note, float(beats or 1)))
    return out


def hits(pattern, step=0.25):
    """Drum-machine row -> [(beat, accent)]: one character per step, x hits and X accents."""
    return [(i * step, c == "X") for i, c in enumerate(pattern) if c in "xX"]


def harmony(melody, steps, key):
    """A melody moved by scale steps within a key (pitch classes): -2 is a third below."""
    scale = [n for n in range(128) if n % 12 in key]
    return [(None if n is None else scale[scale.index(n) + steps], b) for n, b in melody]


def osc(freq, n, width=None, phase=0.0):
    """Band-limited (polyBLEP) saw, or a pulse of that width; freq in Hz, fixed or per sample.
    Cleaner than saw()/pulse() for bright, high or stacked voices."""
    dt = np.broadcast_to(np.asarray(freq, float) / R, (n,))
    ph = (phase + np.cumsum(dt) - dt) % 1.0
    s = 2 * ph - 1 - _blep(ph, dt)
    if width is not None:
        ph2 = (ph + 1 - width) % 1.0
        s -= 2 * ph2 - 1 - _blep(ph2, dt)
    return s


def _blep(ph, dt):
    out = np.zeros(len(ph))
    m = ph < dt
    x = ph[m] / dt[m]
    out[m] = x + x - x * x - 1
    m = ph > 1 - dt
    x = (ph[m] - 1) / dt[m]
    out[m] = x * x + x + x + 1
    return out


@functools.lru_cache(maxsize=None)
def string(f, dur, pos=0.2, bright=3000.0, sustain=1.0, pickup=0.0):
    """Plucked string as decaying partials, peak 1: the pluck (and pickup) position shape the
    tone and the upper partials die first. Cached, so callers must not modify the result."""
    t = tt(dur)
    out = np.zeros(len(t))
    for h in range(1, 80):
        fh = f * h * np.sqrt(1 + 0.0001 * h * h)        # a little stiffness stretches the partials
        if fh > 8000:
            break
        a = np.sin(np.pi * h * pos) / h / (1 + (fh / bright) ** 2)
        if pickup:
            a *= np.sin(np.pi * h * pickup)
        out += a * np.sin(2 * np.pi * fh * t) * np.exp(-t * (1 + fh / 700) / sustain)
    out /= np.max(np.abs(out))
    out.flags.writeable = False
    return out


def chorus(x, depth=0.002, rate=0.6, mix=0.5):
    """Mixes in a copy read through a slowly wobbling delay: shimmer, or a detuned double."""
    i = np.arange(len(x))
    d = (0.007 + depth * (1 + np.sin(2 * np.pi * rate * i / R))) * R
    return x * (1 - mix) + np.interp(i - d, i, x) * mix


def crush(x, bits=4, hold=4):
    """Bit crusher: sample-and-hold down to a lower rate, then quantize to a few bits."""
    q = 2 ** (bits - 1)
    return np.round(np.repeat(x[::hold], hold)[:len(x)] * q) / q


def reso(x, cutoff, q=3.0):
    """Two-pole resonant low-pass (zero phase, applied by FFT)."""
    r = np.fft.rfftfreq(len(x), 1 / R) / cutoff
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt((1 - r * r) ** 2 + (r / q) ** 2), len(x))


def formant(x, peaks):
    """Resonances (centre Hz, gain, width Hz) that shape a buzz into a vowel."""
    f = np.fft.rfftfreq(len(x), 1 / R)
    shape = sum(g / (1 + ((f - fc) / bw) ** 2) for fc, g, bw in peaks)
    return np.fft.irfft(np.fft.rfft(x) * shape, len(x))


def reverb_ir(seconds, tone, spring, rng):
    """Reverb impulse (unit energy): decaying noise whose highs die first. spring blends in a
    spring tank, whose every trip along the coil smears the highs a little later (the drip)."""
    n = int(seconds * R)
    t = np.arange(n) / R
    noise = rng.standard_normal(n)
    low = lowpass(noise, 500)
    tau = seconds / 6.9                                  # -60 dB after `seconds`
    ir = low * np.exp(-t / tau) + lowpass(noise - low, tone) * np.exp(-t / (tau * 0.5))
    ir *= np.minimum(t / 0.015, 1)                       # echoes build up before they diffuse
    ir /= np.sqrt(np.sum(ir ** 2))
    if spring:
        f = np.fft.rfftfreq(2 * n, 1 / R)
        h = 0
        for trip, g in ((0.0331, 0.86), (0.0419, 0.84)):
            d = g * np.exp(-2j * np.pi * (f * trip + 1.8e-6 * f * f))
            h = h + d / (1 - d)
        tank = bandpass(np.fft.irfft(h, 2 * n)[:n], 250, 4000)
        ir = ir * (1 - spring) + tank / np.sqrt(np.sum(tank ** 2)) * spring
    return ir


class Track:
    def __init__(self, bpm, bars, seed):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.buf = np.zeros(int(bars * 4 * self.beat * R) + R * 2)
        self.rng = np.random.default_rng(seed)
        self.wet = None         # reverb bus, see room()
        self.sends = {}

    def at(self, bar, beat):
        return int((bar * 4 + beat) * self.beat * R)

    def add(self, start, sig, gain=1.0, ch=""):
        """Mixes a sound in; ch names the instrument for its reverb send."""
        end = min(len(self.buf), start + len(sig))
        self.buf[start:end] += sig[:end - start] * gain
        send = self.sends.get(ch, 0.0)
        if send:
            self.wet[start:end] += sig[:end - start] * (gain * send)

    def room(self, seconds, tone=3500, spring=0.0, **sends):
        """Gives the track a reverb fed by per-instrument sends, e.g. room(1.6, snare=0.3)."""
        self.ir = reverb_ir(seconds, tone, spring, self.rng)
        self.wet = np.zeros(len(self.buf))
        self.sends = sends

    def line(self, bar, melody, play, **kw):
        """Plays a melody (see notes()) from a bar: play(bar, beat, note, beats, **kw) per note."""
        pos = bar * 4.0
        for note, beats in melody:
            if note is not None:
                b, beat = divmod(pos, 4)
                play(int(b), beat, note, beats, **kw)
            pos += beats

    # drums
    def kick(self, bar, beat, gain=1.0):
        t = tt(0.35)
        f = 42 + 95 * np.exp(-t / 0.035)
        self.add(self.at(bar, beat), np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t / 0.13), gain, "kick")

    def snare(self, bar, beat, gain=1.0):
        t = tt(0.25)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 900, 7000) * np.exp(-t / 0.07)
        tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.04)
        self.add(self.at(bar, beat), n * 1.6 + tone * 0.6, gain, "snare")

    def clap(self, bar, beat, gain=1.0):
        t = tt(0.2)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 1000, 4000)
        env = sum(np.exp(-np.maximum(t - k * 0.011, 0) / 0.01) * (t >= k * 0.011) for k in range(3))
        self.add(self.at(bar, beat), n * env * np.exp(-t / 0.06) * 1.8, gain, "clap")

    def hat(self, bar, beat, gain=1.0, open_=False):
        t = tt(0.25 if open_ else 0.06)
        n = np.diff(self.rng.uniform(-1, 1, len(t) + 1)) * np.exp(-t / (0.08 if open_ else 0.015))
        self.add(self.at(bar, beat), n * 0.35, gain, "hat")

    def crash(self, bar, beat, gain=1.0):
        t = tt(2.0)
        n = bandpass(self.rng.uniform(-1, 1, len(t)), 3000, 10000) * np.exp(-t / 0.6)
        self.add(self.at(bar, beat), n * 1.5, gain, "crash")

    def tom(self, bar, beat, note, gain=1.0):
        t = tt(0.4)
        f = midi(note) * (1 + 0.5 * np.exp(-t / 0.02))
        self.add(self.at(bar, beat), np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t / 0.18), gain, "tom")

    # pitched
    def bass(self, bar, beat, note, beats, gain=1.0, cutoff=700):
        dur = beats * self.beat
        s = saw(midi(note), dur) + 0.5 * saw(midi(note), dur, 0.004)
        s = lowpass(s, cutoff) * adsr(len(s), 0.004, 0.15, 0.6, 0.03)
        self.add(self.at(bar, beat), s, gain, "bass")

    def pad(self, bar, beat, notes, beats, gain=1.0, cutoff=1600):
        dur = beats * self.beat
        s = sum(saw(midi(n), dur, d) for n in notes for d in (-0.003, 0.003))
        s = lowpass(s, cutoff) * adsr(len(s), 0.25, 0.5, 0.8, 0.3)
        self.add(self.at(bar, beat), s / len(notes), gain, "pad")

    def lead(self, bar, beat, note, beats, gain=1.0, width=0.3, cutoff=3500):
        dur = beats * self.beat
        s = lowpass(pulse(midi(note), dur, width, vib=0.006), cutoff) * adsr(int(dur * R), 0.01, 0.2, 0.7, 0.05)
        self.add(self.at(bar, beat), s, gain, "lead")
        # slap-back echo
        self.add(self.at(bar, beat) + int(self.beat * 0.75 * R), s, gain * 0.3, "lead")

    def guitar(self, bar, beat, root, beats, gain=1.0, mute=False):
        """Distorted power chord: root, fifth, octave through a soft clipper."""
        dur = beats * self.beat * (0.45 if mute else 1.0)
        s = sum(saw(midi(n), dur, d) for n in (root, root + 7, root + 12) for d in (-0.002, 0.002))
        s = np.tanh(s * 3.5)
        s = lowpass(s, 1400 if mute else 2800) * adsr(len(s), 0.003, 0.25, 0.75, 0.04)
        self.add(self.at(bar, beat), s, gain, "guitar")

    def brass(self, bar, beat, notes, beats, gain=1.0):
        dur = beats * self.beat
        s = sum(saw(midi(n), dur, d) for n in notes for d in (-0.004, 0.0, 0.004))
        cut = 600 + 2600 * (1 - np.exp(-tt(dur) / 0.08))
        # crude swept filter: blend a dark and a bright version by the sweep
        dark, bright = lowpass(s, 600), lowpass(s, 3200)
        k = (cut - 600) / 2600
        s = (dark * (1 - k) + bright * k) * adsr(len(s), 0.02, 0.3, 0.8, 0.15)
        self.add(self.at(bar, beat), s / len(notes), gain, "brass")

    # more drums (roster themes)
    def thump(self, bar, beat, gain=1.0, low=48, punch=120, decay=0.2, click=0.0, drive=0.0):
        """Kick with a tunable body, beater click and drive (rock, 909 or boom-bap)."""
        t = tt(decay * 6)
        s = np.sin(2 * np.pi * np.cumsum(low + punch * np.exp(-t / 0.03)) / R) * np.exp(-t / decay)
        if click:
            s += bandpass(self.rng.uniform(-1, 1, len(t)), 1500, 6000) * np.exp(-t / 0.003) * click
        if drive:
            s = np.tanh(s * (1 + drive)) / np.tanh(1 + drive)
        self.add(self.at(bar, beat), s, gain, "kick")

    def crack(self, bar, beat, gain=1.0, body=190, decay=0.11, snap=1.4, drive=0.0):
        """Snare with a tunable shell tone, wire decay and crunch."""
        t = tt(decay * 6)
        wires = bandpass(self.rng.uniform(-1, 1, len(t)), 1200, 5500) * np.exp(-t / decay)
        shell = (np.sin(2 * np.pi * body * t) + 0.5 * np.sin(2 * np.pi * body * 1.6 * t)) * np.exp(-t / 0.05)
        s = wires * snap + shell * 0.7
        if drive:
            s = np.tanh(s * (1 + drive)) / np.tanh(1 + drive)
        self.add(self.at(bar, beat), s, gain, "snare")

    def rim(self, bar, beat, gain=1.0):
        """Cross-stick click."""
        t = tt(0.08)
        s = np.sin(2 * np.pi * 1650 * t) * np.exp(-t / 0.01) + 0.6 * np.sin(2 * np.pi * 480 * t) * np.exp(-t / 0.02)
        s += bandpass(self.rng.uniform(-1, 1, len(t)), 1000, 4000) * np.exp(-t / 0.004)
        self.add(self.at(bar, beat), s * 0.6, gain, "snare")

    def tick(self, bar, beat, gain=1.0, decay=0.025):
        """Hi-hat, darker than hat(): closed with a short decay, open with a long one."""
        t = tt(decay * 6)
        s = bandpass(self.rng.uniform(-1, 1, len(t)), 5000, 9000) * np.exp(-t / decay)
        self.add(self.at(bar, beat), s * 0.5, gain, "hat")

    def cymbal(self, bar, beat, gain=1.0, decay=0.8, ping=0.0):
        """Crash wash, darker than crash(); ping adds a ride's bell-like stick tone."""
        t = tt(min(decay * 4, 2.0))
        s = bandpass(self.rng.uniform(-1, 1, len(t)), 2500, 8000) * np.exp(-t / decay)
        if ping:
            s += sum(np.sin(2 * np.pi * f * t) for f in (2960, 4370, 5210)) * np.exp(-t / 0.3) * ping / 3
        self.add(self.at(bar, beat), s, gain, "cymbal")

    def cowbell(self, bar, beat, gain=1.0):
        """Mambo bell: two clanky square tones, a bright hit and a short ring."""
        t = tt(0.3)
        s = osc(587, len(t), 0.5) + osc(845, len(t), 0.5)
        s = bandpass(s, 600, 3000) * (0.6 * np.exp(-t / 0.012) + 0.4 * np.exp(-t / 0.08))
        self.add(self.at(bar, beat), s * 0.4, gain, "perc")

    def timbale(self, bar, beat, gain=1.0, high=True, rim=False):
        """Timbal: a high, ringing metal-shelled drum (two sizes); rim adds the stick crack."""
        t = tt(0.6)
        f0 = 540 if high else 400
        head = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.08 * np.exp(-t / 0.015))) / R) * np.exp(-t / 0.16)
        shell = sum(a * np.sin(2 * np.pi * f0 * k * t) for k, a in ((2.13, 0.3), (3.37, 0.2), (4.61, 0.12)))
        stick = bandpass(self.rng.uniform(-1, 1, len(t)), 1500, 6000) * np.exp(-t / (0.006 if rim else 0.002))
        s = head + shell * np.exp(-t / 0.2) + stick * (1.2 if rim else 0.5)
        self.add(self.at(bar, beat), s * 0.5, gain, "perc")

    def cascara(self, bar, beat, gain=1.0):
        """Stick on the timbal's shell: a dry metallic click."""
        t = tt(0.08)
        s = bandpass(self.rng.uniform(-1, 1, len(t)), 1800, 5000) * np.exp(-t / 0.005)
        s += sum(np.sin(2 * np.pi * f * t) for f in (1210, 2650, 3480)) * np.exp(-t / 0.02) * 0.2
        self.add(self.at(bar, beat), s * 0.6, gain, "perc")

    def conga(self, bar, beat, gain=1.0, high=True, slap=False):
        """Conga: an open tone that bends down as it rings, or a sharp slap."""
        t = tt(0.4)
        f0 = 330 if high else 235
        tone = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.06 * np.exp(-t / 0.03))) / R) * np.exp(-t / (0.05 if slap else 0.16))
        hand = bandpass(self.rng.uniform(-1, 1, len(t)), 700, 3500) * np.exp(-t / (0.012 if slap else 0.004))
        self.add(self.at(bar, beat), (tone * (0.5 if slap else 1.0) + hand * (1.2 if slap else 0.3)) * 0.6, gain, "perc")

    def clave(self, bar, beat, gain=1.0):
        t = tt(0.1)
        s = np.sin(2 * np.pi * 2350 * t) * np.exp(-t / 0.018) + 0.3 * np.sin(2 * np.pi * 1160 * t) * np.exp(-t / 0.012)
        self.add(self.at(bar, beat), s * 0.4, gain, "perc")

    def shaker(self, bar, beat, gain=1.0):
        t = tt(0.12)
        env = (1 - np.exp(-t / 0.006)) * np.exp(-t / 0.03)
        self.add(self.at(bar, beat), bandpass(self.rng.uniform(-1, 1, len(t)), 3500, 8000) * env * 0.5, gain, "perc")

    def anvil(self, bar, beat, gain=1.0, f0=620):
        """Industrial clang: a struck bar's inharmonic partials with uneven decays."""
        t = tt(0.9)
        s = sum(a * np.sin(2 * np.pi * f0 * k * t) * np.exp(-t / d)
                for k, a, d in ((1, 1.0, 0.45), (2.76, 0.7, 0.28), (5.4, 0.4, 0.14), (8.93, 0.25, 0.07)))
        s += bandpass(self.rng.uniform(-1, 1, len(t)), 1000, 5000) * np.exp(-t / 0.004)
        self.add(self.at(bar, beat), s * 0.35, gain, "perc")

    # more pitched voices (roster themes)
    def pick(self, bar, beat, note, beats, gain=1.0, tone=2800.0, ring=0.7, ch="guitar"):
        """Clean electric guitar note with a bridge-pickup twang, damped after its beats."""
        s = string(midi(note), beats * self.beat + 0.04, 0.2, tone, ring, 0.11)
        self.add(self.at(bar, beat), s * adsr(len(s), 0.001, 0.1, 1.0, 0.04), gain, ch)

    def harpsichord(self, bar, beat, note, beats, gain=1.0):
        """A quill-plucked 8' string plus the 4' an octave up, damped when the key lifts."""
        f = midi(note)
        dur = beats * self.beat + 0.05
        s = string(f, dur, 0.08, 4500.0, 2.4 * (262 / f) ** 0.5) + 0.3 * string(2 * f, dur, 0.1, 4500.0, 1.4 * (262 / f) ** 0.5)
        s[:int(0.01 * R)] += bandpass(self.rng.uniform(-1, 1, int(0.01 * R)), 1500, 5000) * np.exp(-tt(0.01) / 0.002) * 0.3
        self.add(self.at(bar, beat), s * adsr(len(s), 0.001, 0.1, 1.0, 0.05), gain, "harpsichord")

    def pbass(self, bar, beat, note, beats, gain=1.0, slap=0.0):
        """Electric bass: a round fingered tone; slap brightens it and adds the thumb's thud."""
        s = string(midi(note), beats * self.beat + 0.03, 0.22, 700.0 + 2600 * slap, 1.3, 0.0)
        s = s * adsr(len(s), 0.002, 0.1, 1.0, 0.03)
        if slap:
            n = int(0.03 * R)
            s[:n] += bandpass(self.rng.uniform(-1, 1, n), 800, 4000) * np.exp(-tt(0.03) / 0.004) * slap
        self.add(self.at(bar, beat), s, gain, "bass")

    def growl(self, bar, beat, note, beats, gain=1.0, drive=4.0, cutoff=900):
        """Distorted saw bass: two saws an octave apart, overdriven, filter snapping shut."""
        n = int(beats * self.beat * R)
        s = np.tanh((osc(midi(note), n) + 0.5 * osc(midi(note) * 2.004, n)) * drive)
        k = np.exp(-np.arange(n) / R / 0.06)
        s = lowpass(s, cutoff * 0.5) * (1 - k) + lowpass(s, cutoff * 2) * k
        self.add(self.at(bar, beat), s * adsr(n, 0.003, 0.1, 0.7, 0.02), gain, "bass")

    def fuzz(self, bar, beat, root, beats, gain=1.0, mute=False, cents=0.0):
        """Sludgy fuzz power chord: plucked strings (root, fifth, octave) clipped hard and darkened."""
        dur = beats * self.beat * (0.45 if mute else 1.0) + 0.03
        s = sum(string(midi(n) * 2 ** (cents / 1200), dur, 0.18, 2500.0, 2.0) for n in (root, root + 7, root + 12))
        s = lowpass(np.tanh(s * 6), 1200 if mute else 2000)
        self.add(self.at(bar, beat), s * adsr(len(s), 0.002, 0.2, 0.85, 0.04), gain, "guitar")

    def trumpet(self, bar, beat, note, beats, gain=1.0, shake=False):
        """Brassy lead: lips up into the note, brightest when first blown, vibrato blooming late;
        shake trills up to the next harmonic like a showy lip shake."""
        n = int(beats * self.beat * R)
        t = np.arange(n) / R
        cents = -50 * np.exp(-t / 0.02) + 20 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
        if shake:
            cents += 250 * (0.5 + 0.5 * np.tanh(4 * np.sin(2 * np.pi * 7 * t))) * np.clip((t - 0.3) / 0.1, 0, 1)
        x = osc(midi(note) * 2 ** (cents / 1200), n)
        env = adsr(n, 0.02, 0.15, 0.75, 0.05)
        x = lowpass(x, 900) * (1 - env) + lowpass(x, 3400) * env
        x = (x + 0.5 * bandpass(x, 1100, 2400)) * env
        x += bandpass(self.rng.uniform(-1, 1, n), 800, 3000) * np.exp(-t / 0.03) * 0.15
        self.add(self.at(bar, beat), x, gain, "lead")

    def supersaw(self, bar, beat, notes, beats, gain=1.0, cutoff=3000):
        """Big trance-style chord: seven saws per note spread over about +-20 cents."""
        n = int(beats * self.beat * R)
        s = np.zeros(n)
        for note in notes:
            for k, d in enumerate((-1.0, -0.64, -0.3, 0.0, 0.31, 0.62, 1.0)):
                s += osc(midi(note) * 2 ** (d * 0.2 / 12), n, phase=k * 0.382 % 1)
        s = lowpass(s, cutoff) * adsr(n, 0.01, 0.4, 0.85, 0.12)
        self.add(self.at(bar, beat), s / (3 * len(notes)), gain, "pad")

    def organ(self, bar, beat, notes, beats, gain=1.0, stops=(0.8, 0, 1, 0.6, 0, 0, 0, 0, 0), leslie=6.6):
        """Organ from sine 'drawbars' (16', 5 1/3', 8', 4', 2 2/3', 2', 1 3/5', 1 1/3', 1');
        leslie (Hz) wobbles a tonewheel organ, 0 makes it a pipe organ."""
        n = int(beats * self.beat * R)
        t = np.arange(n) / R
        wob = np.cumsum(1 + 0.002 * np.sin(2 * np.pi * leslie * t)) / R
        s = sum(lvl * np.sin(2 * np.pi * midi(note) * r * wob)
                for note in notes for r, lvl in zip((0.5, 1.5, 1, 2, 3, 4, 5, 6, 8), stops) if lvl)
        s *= (1 + 0.2 * np.sin(2 * np.pi * leslie * t)) * adsr(n, 0.006 if leslie else 0.04, 0.1, 1.0, 0.04)
        s /= len(notes) * sum(stops)
        if leslie:
            s[:int(0.006 * R)] += bandpass(self.rng.uniform(-1, 1, int(0.006 * R)), 1000, 4000) * 0.3   # key click
        self.add(self.at(bar, beat), s, gain, "organ")

    def choir(self, bar, beat, notes, beats, gain=1.0):
        """Gang vocal "oh": a few detuned buzzes per note through the vowel's formants."""
        n = int(beats * self.beat * R)
        t = np.arange(n) / R
        s = sum(osc(midi(note) * 2 ** (c / 1200) * (1 + 0.004 * np.sin(2 * np.pi * (4.8 + 0.5 * k) * t + k)), n)
                for note in notes for k, c in enumerate((-14, -5, 4, 13)))
        s = formant(s, ((430, 1.0, 70), (820, 0.5, 90), (2700, 0.06, 200)))
        self.add(self.at(bar, beat), s * adsr(n, 0.05, 0.3, 0.85, 0.1) / len(notes), gain, "choir")

    def arp(self, bar, beat, note, beats, gain=1.0, cutoff=1500):
        """Robotic sequencer blip: a narrow pulse through a resonant filter set per step."""
        n = int(beats * self.beat * R)
        s = reso(osc(midi(note), n, 0.3), cutoff, 4.0) * adsr(n, 0.002, 0.05, 0.4, 0.015)
        self.add(self.at(bar, beat), s * 0.3, gain, "arp")

    def glitch(self, bar, beat, notes, beats, gain=1.0, stutter=0):
        """Bit-crushed chord stab; stutter re-fires its first 32nd like a skipping CD."""
        n = int(beats * self.beat * R)
        s = sum(osc(midi(note), n) for note in notes) * adsr(n, 0.001, 0.08, 0.5, 0.02) / len(notes)
        s = lowpass(crush(s, 4, 4), 3500)
        if stutter:
            cut = int(self.beat / 8 * R)
            s = np.concatenate([s[:cut] * adsr(cut, 0.001, 0.1, 1.0, 0.004)] * stutter + [s])
        self.add(self.at(bar, beat), s, gain, "stab")

    def soar(self, bar, melody, gain=1.0, glide=0.03, cutoff=3200):
        """Legato synth lead for a whole phrase: two detuned saws over a square an octave down,
        each note gliding from the last, with a dotted-eighth echo."""
        n = int(sum(b for _, b in melody) * self.beat * R)
        logf = np.zeros(n)
        env = np.zeros(n)
        pos, cur = 0.0, None
        for note, beats in melody:
            a, b = int(pos * self.beat * R), int((pos + beats) * self.beat * R)
            if note is None:
                logf[a:b] = cur or 0.0
            else:
                target = np.log(midi(note))
                cur = target if cur is None else cur
                logf[a:b] = target + (cur - target) * np.exp(-np.arange(b - a) / R / glide)
                cur = logf[b - 1]
                env[a:b] = adsr(b - a, 0.01, 0.3, 0.8, 0.03)
            pos += beats
        f = np.exp(logf)
        s = osc(f * 1.003, n) + osc(f / 1.003, n, phase=0.4) + 0.5 * osc(f / 2, n, 0.5)
        s = lowpass(s, cutoff) * env
        start = self.at(bar, 0)
        for k, g in enumerate((1.0, 0.35, 0.15)):
            self.add(start + int(k * 0.75 * self.beat * R), s, gain * g, "lead")

    def render(self):
        n = int(self.bars * 4 * self.beat * R)
        out = self.buf[:n].copy()
        out[:len(self.buf) - n] += self.buf[n:]      # wrap tails into the start for a clean loop
        if self.wet is not None:
            wet = self.wet[:n].copy()
            wet[:len(self.wet) - n] += self.wet[n:]
            # circular convolution over the loop, so the reverb tail wraps around too
            out += np.fft.irfft(np.fft.rfft(wet) * np.fft.rfft(self.ir, n), n)
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


# ---------------------------------------------------------------- roster themes (M8)
# Each states its hook from bar 0: entrances play a theme from the top for ten-odd seconds.

BB_MAJOR = (10, 0, 2, 3, 5, 7, 9)


def quetzal_theme():
    """Quetzal Neón, "Alas de Neón": latin party rock in Bb. Clave, cáscara, cowbell, congas and
    timbal fills under brassy stabs and a heroic trumpet, doubled in thirds second time round."""
    s = Track(150, 24, 6)
    s.room(1.4, 3500, snare=0.25, lead=0.2, brass=0.2, perc=0.1)
    bb, eb, f, gm, cm = (34, [62, 65, 70]), (39, [63, 67, 70]), (41, [60, 65, 69]), (43, [62, 67, 70]), (36, [60, 63, 67])
    hook_chords = [[bb], [bb], [eb], [f], [gm], [eb], [cm, f], [bb]]
    form = hook_chords + [[gm], [gm], [eb], [eb], [cm], [cm], [f], [f]] + hook_chords
    for bar, chords in enumerate(form):
        sec = bar // 8                      # 0 hook, 1 bridge, 2 hook in thirds
        c1, c2 = chords[0], chords[-1]
        split = c1 is not c2
        # bass and guitar ride the tresillo (3+3+2 eighths)
        for beat, (r, _), step, beats in ((0, c1, 0, 1.4), (1.5, c1, 7, 0.45 if split else 1.4), (3, c2, 12, 0.45), (3.5, c2, 7, 0.45)):
            s.pbass(bar, beat, r + step, beats, 0.6)
        for beat, (r, _), beats in ((0, c1, 1.4), (1.5, c1, 0.45 if split else 1.4), (3, c2, 0.9)) + (((2, c2, 0.9),) if split else ()):
            s.guitar(bar, beat, 40 + (r - 40) % 12, beats, 0.2)
        if sec == 1:
            if bar % 2 == 0:
                s.brass(bar, 0, c1[1], 7.5, 0.25)
            else:
                s.brass(bar, 3.5, form[(bar + 1) % 24][0][1], 0.35, 0.45)
        else:
            s.brass(bar, 1.5, [n + 12 for n in c1[1]], 0.3, 0.4)
            s.brass(bar, 3, [n + 12 for n in c2[1]], 0.3, 0.4)
        # drums and latin percussion
        for beat in (0, 2, 3.5) if bar % 2 else (0, 2):
            s.thump(bar, beat, 0.75, low=52, punch=120, decay=0.12, click=0.4)
        s.crack(bar, 1, 0.6, body=230, decay=0.09, drive=1.0)
        s.crack(bar, 3, 0.65, body=230, decay=0.09, drive=1.0)
        for k in range(8):
            s.hat(bar, k * 0.5, 0.5 if k % 2 else 0.3)
        for beat in (1, 2) if bar % 2 else (0, 1.5, 3):          # son clave, 3-2
            s.clave(bar, beat, 0.6)
        if sec == 0:
            for beat, _ in hits("x.xx.x.x" if bar % 2 else "x.x.xx.x", 0.5):
                s.cascara(bar, beat, 0.55)
        else:
            for beat, acc in hits("X.xxX.xx", 0.5):              # mambo bell
                s.cowbell(bar, beat, 0.55 if acc else 0.35)
        s.conga(bar, 1, 0.35, slap=True)
        s.conga(bar, 3, 0.55)
        s.conga(bar, 3.5, 0.55, high=False)
        for k in range(8):
            s.shaker(bar, k * 0.5, 0.4 if k % 2 else 0.25)
        if bar % 8 == 7:                                          # timbal fill into the next section
            for k, high in enumerate("HHLLHLHL"):
                s.timbale(bar, 2 + k * 0.25, 0.35 + k * 0.05, high == "H", rim=bar == 23 and k >= 6)
            s.brass(bar, 2.5, c2[1], 0.3, 0.3)
            s.brass(bar, 3, c2[1], 0.3, 0.35)
        if bar % 4 == 0:
            s.cymbal(bar, 0, 0.5 if bar % 8 == 0 else 0.35, decay=1.0)
            s.timbale(bar, 0, 0.4, rim=True)
    hook = notes("F4/.5 Bb4/.5 D5 F5/1.5 Eb5/.5  D5/1.5 C5/1.5 Bb4/.5 C5/.5  Eb5/.5 G5/.5 Bb5 G5/1.5 F5/.5"
                 "  F5/1.5 Eb5/1.5 D5/.5 C5/.5  D5/.5 G5/.5 Bb5 A5 G5  G5/1.5 F5/1.5 Eb5/.5 D5/.5  Eb5 C5 F5 A5")
    for bar in (0, 16):
        s.line(bar, hook, s.trumpet, gain=0.5)
        s.trumpet(bar + 7, 0, 82, 2.5, 0.5, shake=True)
    s.line(16, harmony(hook, -2, BB_MAJOR), s.trumpet, gain=0.3)
    s.trumpet(23, 0, 79, 2.5, 0.3, shake=True)
    s.line(8, notes("Bb5/2 A5 G5  D5/3 r  G5/2 F5 Eb5  Bb4/3 r  Eb5 G5 C6/2  Bb5 G5 Eb5 G5  A5 C6 A5 F5  A5/2"),
           s.trumpet, gain=0.5)
    return s.render()


def silas_theme():
    """Silas Wren, "Opening Gambit": C minor. A harpsichord works rising broken thirds round the
    circle of fifths over a rock beat, then a pipe organ plays the stately theme over a pedal figure."""
    s = Track(112, 16, 7)
    s.room(1.8, 3200, harpsichord=0.15, organ=0.3, snare=0.2, tom=0.2)
    circle = [(36, [60, 63, 67]), (41, [60, 65, 68]), (34, [62, 65, 70]), (39, [63, 67, 70]),     # Cm Fm Bb Eb
              (32, [60, 63, 68]), (38, [62, 65, 68]), (31, [59, 62, 65]), (36, [60, 63, 67])]     # Ab Ddim G7 Cm
    gambit = [(32, [60, 63, 68]), (41, [60, 65, 68]), (43, [59, 62, 67]), (36, [60, 63, 67]),     # Ab Fm G Cm
              (32, [60, 63, 68]), (37, [61, 65, 68]), (43, [59, 62, 67]), (43, [59, 62, 65])]     # Ab Db G G7
    climb = [0, 2, 4, 2, 1, 3, 5, 3, 2, 4, 6, 4, 3, 5, 4, 2]      # broken thirds up to the top on beat 3
    pedal = [0, 3, 1, 3, 2, 3, 1, 3] * 2                          # the lower notes move under a held top
    for bar, (root, chord) in enumerate(circle + gambit):
        ladder = [n + 12 * o for o in range(3) for n in chord]
        for k, i in enumerate(climb if bar < 8 else pedal):
            s.harpsichord(bar, k * 0.25, ladder[i], 0.5, 0.55 if k % 4 == 0 else 0.45)
        s.organ(bar, 0, chord, 4, 0.12, stops=(0, 0, 1, 0.6, 0, 0.3, 0, 0, 0), leslie=0)
        for e in range(8):
            s.pbass(bar, e * 0.5, root + (12 if e == 7 else 0), 0.45, 0.55)
        s.guitar(bar, 0, 40 + (root - 40) % 12, 1.5, 0.16)
        s.guitar(bar, 2, 40 + (root - 40) % 12, 1.5, 0.16)
        for beat in (0, 1.5, 2) if bar < 8 else (0, 1.5, 2, 2.5):
            s.thump(bar, beat, 0.8, low=50, punch=110, decay=0.14, click=0.3)
        s.crack(bar, 1, 0.6, body=200, decay=0.12, drive=0.8)
        s.crack(bar, 3, 0.65, body=200, decay=0.12, drive=0.8)
        for k in range(8):
            s.hat(bar, k * 0.5, 0.45 if k % 2 else 0.3)
        if bar % 8 == 0:
            s.cymbal(bar, 0, 0.5, decay=1.1)
    for k, note in enumerate((50, 50, 47, 45, 43, 43)):          # tom run into each half
        s.tom(7, 2.5 + k * 0.25, note, 0.6)
        s.tom(15, 2.5 + k * 0.25, note, 0.6)

    def stop(bar, beat, note, beats, gain):
        s.organ(bar, beat, [note], beats * 0.95, gain, stops=(0, 0, 1, 0.8, 0.4, 0.6, 0, 0, 0), leslie=0)

    # a chorale line falling a third in every bar, then the theme
    s.line(0, notes("G5/2 Eb5/2  Ab5/2 F5/2  F5/2 D5/2  G5/2 Eb5/2  Eb5/2 C5/2  F5/2 D5/2  D5/2 B4/2  Eb5/2 C5/2"), stop, gain=0.3)
    s.line(8, notes("C5/2 Eb5/2  Ab5/3 G5  F5 Eb5 D5 B4  C5/4  Eb5/2 C6/2  Ab5/1.5 F5/.5 Db5/2  B4 D5 G5/2  F5/2 D5 B4"),
           stop, gain=0.45)
    return s.render()


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
