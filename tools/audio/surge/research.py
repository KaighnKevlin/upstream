#!/usr/bin/env python3
"""Research: the lab, the bell jar, science flasks, the tech tree screen.

Curious and a little playful: bubbling flasks, tiptoeing plucked strings,
a celesta-like bell asking questions, the lab timer ticking, a "thinking"
pattern that runs three-against-four like gears of different sizes, then a
eureka: a run of glints up to a bright chord. Same 90 BPM / A minor family.

    .venv/bin/python research.py [name]      -> renders/<name>.mp3
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

# A minor with a raised F# (D major instead of D minor) sounds curious rather
# than sad. Am - D - Am - Em, then F - G - E - E.
CYCLE = [
    ([57, 60, 64], 45), ([54, 57, 62], 50), ([57, 60, 64], 45), ([55, 59, 64], 40),
    ([53, 57, 60], 41), ([55, 59, 62], 43), ([52, 56, 59], 40), ([52, 56, 59], 40),
]


def chord_at(bar):
    return CYCLE[bar % 8]


# Questions on the bell: short phrases that end going up. (beat, note)
QUESTIONS = [(0, 76), (0.5, 74), (1, 76), (1.5, 78), (2, 81),
             (8, 77), (8.5, 76), (9, 74), (9.5, 76), (10, 79), (11, 83),
             (16, 76), (16.5, 72), (17, 74), (17.5, 76), (18, 78), (19, 81),
             (24, 80), (24.5, 76), (25, 74), (25.5, 71), (26, 76), (27, 80)]

SECTIONS = [
    ("flasks", 4, {"bubbles", "ticks", "pad"}),
    ("ponder", 8, {"bubbles", "ticks", "pad", "tiptoe", "questions"}),
    ("work",   8, {"bubbles", "ticks", "pad", "tiptoe", "gears", "bass", "kit", "questions"}),
    ("eureka", 4, {"pad_bright", "eureka", "ticks_slow", "bubbles"}),
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


EUREKA_CHORDS = [[48, 60, 64, 67, 72], [52, 59, 64, 68, 71], [45, 57, 60, 64, 69], [45, 57, 60, 64, 69]]


def pad_notes():
    out = [(t(bar), BAR * 0.98, m, 55) for bar in active("pad") for m in chord_at(bar)[0]]
    for i, bar in enumerate(active("pad_bright")):     # C - E - Am: the bright answer
        out += [(t(bar), BAR * (0.98 if i < 2 else 1.96), m, 65)
                for m in EUREKA_CHORDS[i] if i < 3]
    return out


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] - 12
        out += [(t(bar, 0), BEAT * 0.8, r, 95), (t(bar, 1.5), BEAT * 0.4, r + 7, 70),
                (t(bar, 2), BEAT * 0.8, r, 85), (t(bar, 3.5), BEAT * 0.4, r + 12, 70)]
    return out


def strings(n):
    """Tiptoe: short plucks walking up and down on the off-beats.
    Gears: a 3-note figure every dotted 8th (three-against-four)."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(190)
    for bar in active("tiptoe"):
        v, r = chord_at(bar)
        walk = [r + 12, v[0], v[1], v[0]]
        for i, m in enumerate(walk):
            inst.place(buf, inst.pluck(m, 0.7, ring=0.35, bright=0.5, rng=rng),
                       t(bar, i + 0.5), pan=-0.4)
    for bar in active("gears"):
        v, _ = chord_at(bar)
        for i in range(int(4 / 0.75) + 1):
            beat = i * 0.75
            if beat >= 4:
                break
            m = [v[0] + 12, v[1] + 12, v[2] + 12][i % 3]
            inst.place(buf, inst.pluck(m, 0.55, ring=0.5, bright=0.6, rng=rng), t(bar, beat),
                       pan=0.45)
    return buf


def bells(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(191)
    for bar in list(active("questions"))[::8]:
        for beat, m in QUESTIONS:
            inst.place(buf, inst.bell(m, 0.75), t(bar) + beat * BEAT, pan=0.2)
    for bar in starts("eureka"):                       # glints racing up, then a chime
        run = [69, 71, 72, 74, 76, 77, 79, 81, 83, 84, 86, 88]
        for i, m in enumerate(run):
            inst.place(buf, inst.sparkle(m, 0.5 + 0.04 * i), t(bar) - BEAT * 1.5 + i * BEAT / 8,
                       pan=-0.7 + 0.12 * i)
        for m in (72, 76, 79, 84):
            inst.place(buf, inst.bell(m, 0.8), t(bar), pan=0.1)
    return buf


def lab(n):
    """Bubbles, the timer and a light kit."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(192)
    bars = list(active("bubbles"))
    b = inst.bubbling(len(bars) * BAR + 2, rate=5, rng=rng)
    buf[:, int(t(bars[0]) * SR):int(t(bars[0]) * SR) + b.shape[1]] += b[:, :n - int(t(bars[0]) * SR)]
    for bar in active("ticks"):
        for e in range(8):
            inst.place(buf, inst.tick(3600 if e % 2 else 2800, 0.5 if e % 2 else 0.7, rng),
                       t(bar, e / 2), pan=0.6 if e % 2 else -0.6)
    for bar in active("ticks_slow"):
        for beat in range(4):
            inst.place(buf, inst.tick(2800, 0.5, rng), t(bar, beat), pan=-0.6)
    block = inst.woodblock()
    for bar in active("kit"):
        inst.place(buf, inst.felt_kick(0.8), t(bar, 0))
        inst.place(buf, inst.felt_kick(0.5), t(bar, 2.5))
        inst.place(buf, block, t(bar, 1), pan=0.3, gain=0.5)
        inst.place(buf, inst.woodblock(1, 1.4), t(bar, 3), pan=-0.3, gain=0.4)
        inst.place(buf, inst.woodblock(1, 1.4), t(bar, 3.25), pan=-0.3, gain=0.3)
    return buf


MIX = {         # (loudness while sounding, room send)
    "pad":     (-24, 0.35),
    "bass":    (-23, 0.05),
    "strings": (-21, 0.25),
    "bells":   (-21, 0.40),
    "lab":     (-24, 0.20),
}
ROOM_RETURN = 0.28
TARGET_DB = -18


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "research_v1"
    seconds = TOTAL_BARS * BAR + 6
    n = int(seconds * SR)
    stems = {
        "pad": fit(render_part(pad_notes(), setup_cave_pad, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_soft_bass, seconds), n),
        "strings": strings(n), "bells": bells(n), "lab": lab(n),
    }
    shape = {
        "pad": Pedalboard([HighpassFilter(100)]),
        "bass": Pedalboard([LowpassFilter(600), Compressor(-20, 3)]),
        "strings": Pedalboard([HighpassFilter(120)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # A small stone lab: shorter, brighter echo than the cave.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    room = fit(Pedalboard([HighpassFilter(200),
                           Reverb(room_size=0.7, damping=0.4, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(7000)])(send, SR), n)
    mix = sum(stems.values()) + room * ROOM_RETURN
    mix = Pedalboard([Compressor(threshold_db=-20, ratio=2, attack_ms=20,
                                 release_ms=250)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "room": room * ROOM_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
