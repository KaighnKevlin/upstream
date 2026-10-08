#!/usr/bin/env python3
"""Title screen: the game's main theme, over the attract-mode camera drift.

Built on a rising four-note idea (the Upstream lifting ore), played on a
music box, then answered by plucked harp and warm pad. Inviting, a little
mysterious. Same 90 BPM / A minor family as the other tracks.

    .venv/bin/python title.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import Compressor, HighpassFilter, LowpassFilter, Pedalboard, Reverb

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_cave_pad, setup_soft_bass

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# Am - F - C - E: a minor key that opens up to a brighter C before the pull home.
CYCLE = [
    (0, 2, [57, 60, 64, 71], 45),   # A minor (with a misty added B)
    (2, 2, [53, 57, 60, 64], 41),   # F major 7
    (4, 2, [55, 60, 64, 67], 48),   # C major: the hopeful lift
    (6, 2, [52, 56, 59, 64], 40),   # E major: leans back to A minor
]


def chord_at(bar):
    b = bar % 8
    for off, n, v, r in CYCLE:
        if off <= b < off + n:
            return v, r


# The theme: (beat, note, strength). It always starts by climbing A-B-C-E.
THEME = [
    (0, 69, 1.0), (0.5, 71, 0.7), (1, 72, 0.8), (2, 76, 1.0), (5, 74, 0.6), (6, 72, 0.7),
    (8, 69, 0.9), (8.5, 72, 0.7), (9, 77, 0.8), (10, 76, 1.0), (13, 72, 0.6), (14, 74, 0.7),
    (16, 72, 1.0), (16.5, 74, 0.7), (17, 76, 0.8), (18, 79, 1.0), (21, 76, 0.6), (22, 74, 0.7),
    (24, 76, 1.0), (26, 71, 0.7), (27, 74, 0.6), (28, 68, 0.9), (30, 71, 0.6),
]

SECTIONS = [
    ("dawn",   4, {"pad", "harp_slow", "swell"}),
    ("theme",  8, {"pad", "harp", "musicbox", "ticks"}),
    ("lift",   8, {"pad", "harp", "musicbox", "pluck_theme", "ticks", "bass", "kit", "drips"}),
    ("settle", 4, {"pad", "harp_slow", "musicbox_end", "drips"}),
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


def starts(layer):
    return [a for _, a, _, layers in spans() if layer in layers]


def t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


def pad_notes():
    return [(t(bar), n * BAR * 0.97, m, 58)
            for bar in active("pad") for off, n, v, _ in CYCLE if bar % 8 == off
            for m in v]


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] - 12
        out += [(t(bar), BEAT * 2.5, r, 90), (t(bar, 3), BEAT * 0.8, r + 7, 70)]
    return out


def harp(n):
    """Rising plucked arpeggios: every bar climbs, like ore riding the beam."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(200)
    slow = set(active("harp_slow"))
    for bar in sorted(slow | set(active("harp"))):
        v, r = chord_at(bar)
        climb = [r, v[0], v[1], v[2], v[3], v[1] + 12, v[2] + 12, v[3] + 12]
        step = 1.0 if bar in slow else 0.5
        for i, m in enumerate(climb[: int(4 / step)]):
            inst.place(buf, inst.pluck(m, 0.55 + 0.05 * i, ring=1.8, bright=0.45, rng=rng),
                       t(bar, i * step), pan=-0.6 + 0.15 * i)
    return buf


def musicbox(n):
    buf = np.zeros((2, n), np.float32)
    for bar in list(active("musicbox"))[::8]:
        for beat, m, v in THEME:
            inst.place(buf, inst.bell(m, v), t(bar) + beat * BEAT, pan=0.15)
    for bar in starts("musicbox_end"):              # first phrase once more, slowing
        for beat, m, v in THEME[:6]:
            inst.place(buf, inst.bell(m, v * 0.8), t(bar) + beat * BEAT * 1.25, pan=0.15)
    return buf


def pluck_theme(n):
    """The theme doubled an octave down on plucked string, for warmth."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(201)
    for bar in list(active("pluck_theme"))[::8]:
        for beat, m, v in THEME:
            inst.place(buf, inst.pluck(m - 12, v * 0.7, ring=1.5, bright=0.35, rng=rng),
                       t(bar) + beat * BEAT, pan=-0.2)
    return buf


def machine(n):
    """Soft clock, felt kick and woodblock, cave drips, a bowed-metal swell."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(202)
    for bar in active("ticks"):
        for beat in range(4):
            inst.place(buf, inst.tick(2100 if beat % 2 else 3300, 0.6, rng), t(bar, beat),
                       pan=0.45 if beat % 2 else -0.45)
    kick, block = inst.felt_kick(), inst.woodblock()
    for bar in active("kit"):
        inst.place(buf, kick, t(bar, 0))
        inst.place(buf, kick, t(bar, 2.5), gain=0.5)
        inst.place(buf, block, t(bar, 2), pan=0.2, gain=0.6)
        for e in range(8):
            inst.place(buf, inst.shaker(0.8 if e % 2 else 0.4, rng), t(bar, e / 2), pan=-0.25)
    bars = list(active("drips"))
    at = t(bars[0])
    while at < t(TOTAL_BARS):
        if int(at / BAR) in bars:
            inst.place(buf, inst.drip(rng), at, rng.uniform(-0.8, 0.8), rng.uniform(0.3, 0.8))
        at += rng.exponential(2.0) + 0.3
    for bar in starts("swell"):
        inst.place(buf, inst.bowed_metal(inst.hz(57), 7.0, rng), t(bar), pan=0.3, gain=0.8)
    return buf


MIX = {         # (loudness while sounding, cave send)
    "pad":      (-23, 0.35),
    "bass":     (-24, 0.05),
    "harp":     (-22, 0.35),
    "musicbox": (-20, 0.45),
    "pluck":    (-24, 0.30),
    "machine":  (-25, 0.25),
}
CAVE_RETURN = 0.33
TARGET_DB = -18


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "title_v1"
    seconds = TOTAL_BARS * BAR + 6
    n = int(seconds * SR)
    stems = {
        "pad": fit(render_part(pad_notes(), setup_cave_pad, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_soft_bass, seconds), n),
        "harp": harp(n), "musicbox": musicbox(n), "pluck": pluck_theme(n),
        "machine": machine(n),
    }
    shape = {
        "pad": Pedalboard([HighpassFilter(90)]),
        "bass": Pedalboard([LowpassFilter(600), Compressor(-20, 3)]),
        "harp": Pedalboard([HighpassFilter(120)]),
        "pluck": Pedalboard([HighpassFilter(150)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    send = sum(stems[k] * MIX[k][1] for k in MIX)
    cave = fit(Pedalboard([HighpassFilter(200),
                           Reverb(room_size=0.92, damping=0.55, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(5000)])(send, SR), n)
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
