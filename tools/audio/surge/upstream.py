#!/usr/bin/env python3
"""The Upstream: the magic column of rising blue light, the one true power.

Weightless and glowing. An endlessly rising tone (the Shepard illusion: it
always climbs but never gets higher), a high airy "oo" choir, glassy
sparkles that only ever go up, a low power hum, and slow harp. No drums.
Same 90 BPM / A minor family.

    .venv/bin/python upstream.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import Chorus, HighpassFilter, LowpassFilter, Pedalboard, Reverb

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_cave_pad

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# Dreamy chords: A minor 9, F with a raised B (the "magic" note), C major 7, E minor.
CYCLE = [
    ([57, 60, 64, 71], 45),   # A minor 9
    ([53, 57, 60, 64, 71], 41),   # F major 7 with B: floating, magical
    ([55, 59, 60, 64], 48),   # C major 7
    ([52, 55, 59, 62], 40),   # E minor 7
]


def chord_at(bar):
    return CYCLE[(bar % 8) // 2]


SECTIONS = [
    ("glow",  4, {"hum", "rise", "pad"}),
    ("lift",  8, {"hum", "rise", "pad", "choir", "sparkle"}),
    ("crown", 8, {"hum", "rise", "pad", "choir", "sparkle", "harp", "bells"}),
    ("drift", 4, {"hum", "rise", "pad", "sparkle_slow"}),
]
TOTAL_BARS = sum(n for _, n, _ in SECTIONS)

# A slow bell line for the crown: (beat, note), always stepping upward in pairs.
BELLS = [(0, 76), (1, 79), (4, 74), (5, 77), (8, 72), (9, 76), (12, 71), (13, 74),
         (16, 76), (17, 81), (20, 79), (21, 83), (24, 79), (26, 76), (28, 74), (30, 71)]


def spans():
    bar = 0
    for name, n, layers in SECTIONS:
        yield name, bar, bar + n, layers
        bar += n


def active(layer):
    for _, a, b, layers in spans():
        if layer in layers:
            yield from range(a, b)


def t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


def pad_notes():
    return [(t(bar), 2 * BAR * 0.98, m, 52)
            for bar in active("pad") if bar % 2 == 0 for m in chord_at(bar)[0]]


def choir_notes():
    return [(t(bar), 2 * BAR, m + 12, 0.7)
            for bar in active("choir") if bar % 2 == 0 for m in chord_at(bar)[0][1:4]]


def sparkles(n):
    """Glints that only ever climb: runs of 3-5 chord notes going up."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(140)
    slow = set(active("sparkle_slow"))
    for bar in sorted(set(active("sparkle")) | slow):
        v, _ = chord_at(bar)
        pool = sorted({m + 24 for m in v} | {m + 12 for m in v})
        runs = 1 if bar in slow else 2
        for _ in range(runs):
            start = rng.integers(0, 6) / 2
            i0 = rng.integers(0, len(pool) - 4)
            for j in range(rng.integers(3, 6)):
                if i0 + j >= len(pool):
                    break
                inst.place(buf, inst.sparkle(pool[i0 + j], 0.5 + 0.1 * j),
                           t(bar, start + j * 0.25), pan=-0.6 + 0.3 * j)
    return buf


def harp(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(141)
    for bar in active("harp"):
        v, r = chord_at(bar)
        for i, m in enumerate([r, v[0], v[1], v[2], v[3] if len(v) > 3 else v[0] + 12,
                               v[1] + 12, v[2] + 12, v[0] + 24]):
            inst.place(buf, inst.pluck(m, 0.6, ring=2.0, bright=0.4, rng=rng), t(bar, i / 2),
                       pan=-0.5 + 0.14 * i)
    return buf


def bells(n):
    buf = np.zeros((2, n), np.float32)
    for bar in list(active("bells"))[::8]:
        for beat, m in BELLS:
            inst.place(buf, inst.bell(m, 0.8), t(bar) + beat * BEAT, pan=0.2)
    return buf


def power(n):
    """The beam itself: the endless rise, plus a low hum that swells gently."""
    buf = np.zeros((2, n), np.float32)
    bars = list(active("rise"))
    rise = inst.endless_rise(len(bars) * BAR + 4, period=4 * BAR, base=55.0)
    inst.place(buf, rise, t(bars[0]), pan=-0.15)
    inst.place(buf, inst.endless_rise(len(bars) * BAR + 4, period=4 * BAR, base=55.0 * 1.003),
               t(bars[0]), pan=0.15)
    hum_bars = list(active("hum"))
    tt = np.arange(int(len(hum_bars) * BAR * SR)) / SR
    hum = (np.sin(2 * np.pi * 55 * tt) + 0.3 * np.sin(2 * np.pi * 110.4 * tt))
    hum *= 0.75 + 0.25 * np.sin(2 * np.pi * tt / (2 * BAR))      # breathes every 2 bars
    hum *= np.minimum(1, tt / 3) * np.minimum(1, (tt[-1] - tt) / 3)
    inst.place(buf, (hum * 0.3).astype(np.float32), t(hum_bars[0]))
    return buf


MIX = {         # (loudness while sounding, sky-reverb send)
    "pad":      (-24, 0.40),
    "choir":    (-24, 0.55),
    "power":    (-23, 0.25),
    "sparkles": (-24, 0.60),
    "harp":     (-23, 0.40),
    "bells":    (-21, 0.55),
}
SKY_RETURN = 0.22
TARGET_DB = -19        # quiet and glowing


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "upstream_v1"
    seconds = TOTAL_BARS * BAR + 7
    n = int(seconds * SR)
    stems = {
        "pad": fit(render_part(pad_notes(), setup_cave_pad, seconds), n),
        "choir": inst.formant(inst.choir_source(choir_notes(), n, 8, 150, attack=1.5, tail=2.0),
                              "oo"),
        "power": power(n), "sparkles": sparkles(n), "harp": harp(n), "bells": bells(n),
    }
    shape = {
        "pad": Pedalboard([HighpassFilter(120), Chorus(depth=0.4, mix=0.5)]),
        "choir": Pedalboard([HighpassFilter(200), Chorus(depth=0.3, mix=0.4)]),
        "power": Pedalboard([LowpassFilter(6000)]),
        "harp": Pedalboard([HighpassFilter(120)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # Open sky rather than a cave: huge, bright-ish, very long.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    sky = fit(Pedalboard([HighpassFilter(250),
                          Reverb(room_size=0.98, damping=0.3, wet_level=1.0,
                                 dry_level=0.0, width=1.0),
                          LowpassFilter(8000)])(send, SR), n)
    mix = sum(stems.values()) + sky * SKY_RETURN
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "sky": sky * SKY_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
