#!/usr/bin/env python3
"""Calm Factory-mode track: a marble machine ticking away in a cave.

Pad and bass are Surge XT; the machine (mallets, clock, gears, marbles,
drips, bells, kit) is hand-built in instruments.py. Every part sends into one
shared cave reverb so they sound like they're in the same room.

    .venv/bin/python factory.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import (Compressor, Delay, HighpassFilter,
                        LowpassFilter, Pedalboard, Reverb)

import instruments as inst
from mixing import balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_cave_pad, setup_soft_bass

SR = 44100
BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# --- harmony: an 8-bar cycle, (bar offset, bars, pad voicing, bass root) -------
# Slow chord changes are a big part of "calm". Am - Fmaj7 - Dm7 - Esus - E.
CYCLE = [
    (0, 2, [57, 60, 64, 71], 45),   # A minor with an added B: open, misty
    (2, 2, [53, 57, 60, 64], 41),   # F major 7: warm
    (4, 2, [50, 57, 60, 65], 38),   # D minor 7: wistful
    (6, 1, [52, 57, 59, 64], 40),   # E sus4: suspended, waiting
    (7, 1, [52, 56, 59, 64], 40),   # E major: the pull back to A minor
]


def chord_at(bar):
    b = bar % 8
    for off, n, notes, root in CYCLE:
        if off <= b < off + n:
            return notes, root


# --- structure: (name, bars, active layers) ----------------------------------
SECTIONS = [
    ("cave",  4, {"pad", "drips"}),
    ("wake",  8, {"pad", "drips", "clock", "mallet4"}),
    ("turn",  8, {"pad", "drips", "clock", "mallet8", "bass"}),
    ("work", 16, {"pad", "drips", "clock", "mallet8", "bass", "kit", "marbles"}),
    ("song", 16, {"pad", "drips", "clock", "mallet8", "bass", "kit", "marbles", "bell"}),
    ("rest",  8, {"pad", "drips", "clock", "mallet4"}),
]
TOTAL_BARS = sum(n for _, n, _ in SECTIONS)


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


# --- Surge parts -------------------------------------------------------------
def pad_notes():
    out = []
    for bar in active("pad"):
        b = bar % 8
        for off, n, notes, _ in CYCLE:
            if b == off:
                out += [(t(bar), n * BAR * 0.97, m, 60) for m in notes]
    return out


def bass_notes():
    out = []
    for bar in active("bass"):
        _, root = chord_at(bar)
        out.append((t(bar), BEAT * 2.6, root - 12, 95))
        out.append((t(bar, 3.5), BEAT * 0.4, root - 12, 70))
    return out


# --- the machine -------------------------------------------------------------
def mallets(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(10)
    gear = [0, 2, 1, 3, 2, 1, None, 2]          # 8th notes; None = a rest
    sparse = set(active("mallet4"))
    for bar in sorted(sparse | set(active("mallet8"))):
        notes, _ = chord_at(bar)
        up = [m + 12 for m in notes]
        for i, idx in enumerate(gear):
            if idx is None or (bar in sparse and i % 2):
                continue
            vel = (0.9 if i % 4 == 0 else 0.6) * rng.uniform(0.9, 1.05)
            pan = -0.35 + 0.1 * idx
            inst.place(buf, inst.mallet(up[idx], vel, rng), t(bar, i / 2), pan)
    return buf


def clock(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(11)
    for bar in active("clock"):
        for beat in range(4):
            tock = beat % 2
            inst.place(buf, inst.tick(2100 if tock else 3300, 0.8, rng),
                       t(bar, beat), pan=0.45 if tock else -0.45)
    # Gear winding in the last beats before each section change.
    for name, a, b, layers in spans():
        if "clock" in layers:
            inst.place(buf, inst.ratchet(rng=rng), t(b - 1, 2.5), pan=0.1, gain=0.8)
    return buf


def drips(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(12)
    bars = list(active("drips"))
    at, end = t(bars[0]), t(bars[-1] + 1)
    while at < end:
        inst.place(buf, inst.drip(rng), at, rng.uniform(-0.8, 0.8), rng.uniform(0.4, 1))
        at += rng.exponential(2.2) + 0.3
    return buf


def marbles(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(13)
    for bar in list(active("marbles"))[::4]:
        start = t(bar, rng.choice([0.5, 1.0, 1.5]))
        inst.place(buf, inst.marble_roll(rng.uniform(1.2, 2.0), rng), start,
                   pan=rng.uniform(-0.6, 0.6))
    return buf


# Bell tune over one 8-bar cycle: (beat, midi note, strength)
BELL = [
    (0, 76, 1.0), (3, 74, 0.6), (4, 72, 0.8), (6, 71, 0.6),
    (8, 69, 0.9), (10, 72, 0.6), (11, 76, 0.7), (12, 74, 0.8),
    (16, 77, 1.0), (18, 76, 0.6), (19, 74, 0.6), (20, 72, 0.8),
    (24, 71, 0.9), (26, 69, 0.6), (28, 68, 0.8), (30, 71, 0.6),
]


def bells(n):
    buf = np.zeros((2, n), np.float32)
    bars = list(active("bell"))
    for k, bar in enumerate(bars[::8]):
        for beat, m, v in BELL:
            if k % 2 and beat == 30:
                m = 76          # second time round, end higher so it doesn't loop flat
            inst.place(buf, inst.bell(m, v), t(bar) + beat * BEAT, pan=0.15)
    return buf


def kit(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(14)
    kick, block = inst.felt_kick(), inst.woodblock()
    for bar in active("kit"):
        inst.place(buf, kick, t(bar, 0))
        inst.place(buf, kick, t(bar, 2.5), gain=0.6)
        inst.place(buf, block, t(bar, 2), pan=0.2, gain=0.8)
        if bar % 2:
            inst.place(buf, inst.woodblock(1, 1.35), t(bar, 3.75), pan=0.3, gain=0.35)
        for e in range(8):
            swing = 0.06 if e % 2 else 0.0
            vel = 0.9 if e % 2 else 0.5
            inst.place(buf, inst.shaker(vel, rng), t(bar, e / 2 + swing), pan=-0.25)
    return buf


# --- mix ---------------------------------------------------------------------
# name: (target loudness dB while playing, cave reverb send)
MIX = {
    "pad":     (-22, 0.35),
    "bass":    (-22, 0.05),
    "mallets": (-21, 0.30),
    "bells":   (-22, 0.40),
    "kit":     (-21, 0.12),
    "clock":   (-30, 0.20),
    "marbles": (-29, 0.40),
    "drips":   (-31, 0.90),
}
CAVE_RETURN = 0.5      # how much of the shared cave echo we hear
TARGET_DB = -18        # overall average loudness: calm background music


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "factory_v1"
    seconds = TOTAL_BARS * BAR + 5           # reverb tail
    n = int(seconds * SR)

    pad = render_part(pad_notes(), setup_cave_pad, seconds)
    bass = render_part(bass_notes(), setup_soft_bass, seconds)
    stems = {
        "pad": fit(pad, n), "bass": fit(bass, n),
        "mallets": mallets(n), "bells": bells(n), "kit": kit(n),
        "clock": clock(n), "marbles": marbles(n), "drips": drips(n),
    }

    # Per-part tone shaping before balancing.
    fx = {
        "pad": Pedalboard([HighpassFilter(90)]),
        "bass": Pedalboard([LowpassFilter(700), Compressor(-20, 3)]),
        "mallets": Pedalboard([HighpassFilter(150)]),
        "bells": Pedalboard([Delay(delay_seconds=BEAT * 1.5, feedback=0.35, mix=0.3)]),
        "kit": Pedalboard([Compressor(-18, 3)]),
        "clock": Pedalboard([HighpassFilter(800)]),
    }
    for k, board in fx.items():
        stems[k] = board(stems[k], SR)[:, :n]
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # One shared cave: dark, long, nothing low and muddy in it.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    cave = Pedalboard([HighpassFilter(200),
                       Reverb(room_size=0.93, damping=0.55, wet_level=1.0,
                              dry_level=0.0, width=1.0),
                       LowpassFilter(4500)])(send, SR)[:, :n]

    mix = sum(stems.values()) + cave * CAVE_RETURN
    mix = Pedalboard([Compressor(threshold_db=-20, ratio=2, attack_ms=20,
                                 release_ms=250)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "cave": cave * CAVE_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
