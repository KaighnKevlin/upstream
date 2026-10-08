#!/usr/bin/env python3
"""The Depths: the prospector exploring deep caves by lamplight.

Dark, sparse and uneasy but curious. A low drone and cave wind, a lone
plucked line wandering, distant pickaxes echoing, then the hot chambers:
magma bubbling, clockwork cinder bats chirping, a slow heavy pulse and a far
horn. At the bottom, something huge groans. Same 90 BPM / A minor family.

    .venv/bin/python depths.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import HighpassFilter, LowpassFilter, Pedalboard, Reverb

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_siege_drone, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# Very slow chords. A minor, then B-flat (one step up: the cave closing in),
# back to A minor; D minor, then E, which leans back to A.
CYCLE = [(0, 4, [45, 52, 57], 33), (4, 2, [46, 53, 58], 34), (6, 2, [45, 52, 57], 33),
         (8, 4, [50, 53, 57], 38), (12, 4, [52, 56, 59], 40)]


def chord_at(bar):
    b = bar % 16
    for off, n, v, r in CYCLE:
        if off <= b < off + n:
            return v, r


# The wandering line: (beat within 16 bars, note). Long gaps on purpose.
WANDER = [(0, 57), (1.5, 60), (2, 59), (4, 57), (10, 64), (11, 62), (11.5, 60), (12, 62),
          (16, 58), (17.5, 57), (18, 58), (20, 62), (24, 60), (25, 57),
          (32, 62), (33.5, 65), (34, 64), (36, 62), (42, 69), (43, 65), (44, 64),
          (48, 64), (49.5, 68), (50, 71), (52, 68), (56, 64), (58, 63), (59, 64)]
HORN = [(0, 4, 57), (4, 2, 60), (6, 6, 58), (16, 3, 62), (19, 1, 60), (20, 8, 64)]

SECTIONS = [
    ("descent", 4, {"drone", "wind", "drips"}),
    ("tunnels", 8, {"drone", "wind", "drips", "wander", "picks", "metal"}),
    ("hot",     8, {"drone", "drips", "wander", "magma", "bats", "pulse", "horn"}),
    ("deep",    4, {"drone", "wind", "groan", "drips"}),
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


def drone_notes():
    out = []
    for bar in active("drone"):
        for off, n, v, r in CYCLE:
            if bar % 16 == off:
                out += [(t(bar), n * BAR * 0.98, m, 60) for m in [r + 12] + v[:2]]
    return out


def horn_notes():
    return [(t(bar) + b * BEAT, ln * BEAT * 0.95, m, 85)
            for bar in starts("horn") for b, ln, m in HORN]


def wander(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(220)
    bars = list(active("wander"))
    first = bars[0]
    for beat, m in WANDER:
        bar = first + int(beat // 4)
        if bar in bars:
            inst.place(buf, inst.pluck(m - 12, 0.8, ring=2.2, bright=0.35, rng=rng),
                       t(first) + beat * BEAT, pan=-0.15)
    return buf


def cave(n):
    """Wind, drips, distant pickaxes, bowed metal."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(221)
    for name, a, b, layers in spans():
        if "wind" in layers:
            inst.place(buf, inst.wind((b - a) * BAR + 2, rng), t(a), pan=-0.4)
            inst.place(buf, inst.wind((b - a) * BAR + 2, rng), t(a), pan=0.4)
    drip_bars = set(active("drips"))
    at = 0.5
    while at < t(TOTAL_BARS):
        if int(at / BAR) in drip_bars:
            inst.place(buf, inst.drip(rng), at, rng.uniform(-0.9, 0.9), rng.uniform(0.3, 1.0))
        at += rng.exponential(1.6) + 0.2
    for bar in active("picks"):                     # someone far off, chipping at a vein
        if bar % 2 == 0:
            beat = rng.choice([0.5, 1.5, 2.5])
            for k in range(3):
                inst.place(buf, inst.hammer(81, 0.3 - 0.06 * k, rng), t(bar, beat + k * 0.75),
                           pan=0.7)
    for bar in starts("metal"):
        inst.place(buf, inst.bowed_metal(inst.hz(45), 9.0, rng), t(bar + 2), pan=-0.3)
    return buf


def creatures(n):
    """Magma, cinder bats, the heavy pulse, and the groan from below."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(222)
    hot = list(active("magma"))
    at = t(hot[0])
    while at < t(hot[-1] + 1):
        inst.place(buf, inst.magma(rng), at, rng.uniform(-0.5, 0.5), rng.uniform(0.5, 1.0))
        at += rng.exponential(0.7) + 0.15
    for bar in active("bats"):
        if bar % 2 == 1:
            inst.place(buf, inst.bat_chirps(rng), t(bar, rng.uniform(0, 3)),
                       pan=rng.choice([-0.8, 0.8]), gain=0.8)
    for bar in active("pulse"):                     # slow heavy heartbeat of the deep
        inst.place(buf, inst.war_drum(50, 0.8, rng), t(bar, 0))
        inst.place(buf, inst.war_drum(50, 0.5, rng), t(bar, 2))
    return buf


MIX = {          # (loudness while sounding, deep-cave send)
    "drone":     (-24, 0.20),
    "wander":    (-21, 0.45),
    "horn":      (-23, 0.55),
    "cave":      (-24, 0.40),
    "creatures": (-23, 0.30),
    "groan":     (-22, 0.50),
}
CAVE_RETURN = 0.3
TARGET_DB = -19


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "depths_v1"
    seconds = TOTAL_BARS * BAR + 7
    n = int(seconds * SR)
    groan = np.zeros((2, n), np.float32)
    for bar in starts("groan"):
        g = inst.groan_source(3 * BAR, start_midi=40, drop=5)
        s = int(t(bar, 1) * SR)
        groan[:, s:s + g.shape[1]] += g[:, :n - s]
    stems = {
        "drone": fit(render_part(drone_notes(), setup_siege_drone, seconds), n),
        "wander": wander(n),
        "horn": fit(render_part(horn_notes(), setup_siege_lead, seconds), n),
        "cave": cave(n), "creatures": creatures(n),
        "groan": inst.formant(groan, "oo"),
    }
    shape = {
        "drone": Pedalboard([HighpassFilter(40), LowpassFilter(700)]),
        "horn": Pedalboard([LowpassFilter(1500)]),              # far away, through rock
        "wander": Pedalboard([HighpassFilter(70)]),
        "groan": Pedalboard([LowpassFilter(1200)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # The deepest, darkest cave yet.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    deep = fit(Pedalboard([HighpassFilter(150),
                           Reverb(room_size=0.97, damping=0.7, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(3500)])(send, SR), n)
    mix = sum(stems.values()) + deep * CAVE_RETURN
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "deep": deep * CAVE_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
