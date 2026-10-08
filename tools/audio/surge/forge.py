#!/usr/bin/env python3
"""Forge: smelting and smithing (furnace rails, foundry, bellows, stamp presses).

A working rhythm: tuned hammers on anvils are both the beat and part of the
tune, bellows breathe every two beats, the fire crackles, and steam hisses
when hot metal is quenched. Warm and busy, between Factory's calm and Siege's
threat. Same 90 BPM / A minor family.

    .venv/bin/python forge.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import Compressor, HighpassFilter, LowpassFilter, Pedalboard, Reverb

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_siege_drone, setup_siege_lead, setup_soft_bass

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# Am - G - F - E: a stepping-down line, like a heavy weight being lowered.
CYCLE = [
    ([57, 60, 64], 45),   # A minor
    ([55, 59, 62], 43),   # G major
    ([53, 57, 60], 41),   # F major
    ([52, 56, 59], 40),   # E major
]


def chord_at(bar):
    return CYCLE[(bar % 8) // 2]


# The smith's pattern in one bar: (beat, which chord tone, strength).
# Strike, rebound tap, strike... the classic "clang, tink, clang".
SMITH = [(0, 0, 1.0), (0.5, 2, 0.35), (1, 1, 0.7), (2, 0, 1.0), (2.5, 2, 0.35),
         (2.75, 2, 0.3), (3, 1, 0.8)]

# Horn tune over 8 bars: (beat, beats long, note).
HORN = [
    (0, 3, 64), (3, 1, 67), (4, 4, 69),
    (8, 2, 67), (10, 2, 66), (12, 4, 62),
    (16, 3, 65), (19, 1, 64), (20, 2, 62), (22, 2, 60),
    (24, 4, 59), (28, 4, 64),
]

SECTIONS = [
    ("kindle", 4, {"fire", "bellows", "drone", "hammer_one"}),
    ("work",   8, {"fire", "bellows", "drone", "smith", "bass", "drum"}),
    ("pour",  16, {"fire", "bellows", "drone", "smith", "bass", "drum", "horn",
                   "plucks", "steam"}),
    ("quench", 4, {"fire", "drone", "hammer_one", "steam_big"}),
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
    return [(t(bar), 2 * BAR * 0.98, m - 12, 70)
            for bar in active("drone") if bar % 2 == 0 for m in chord_at(bar)[0]]


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] - 12
        out += [(t(bar, 0), BEAT * 1.5, r, 100), (t(bar, 2), BEAT * 1.5, r, 90)]
    return out


def horn_notes():
    return [(t(bar) + b * BEAT, ln * BEAT * 0.95, m, 90)
            for bar in list(active("horn"))[::8] for b, ln, m in HORN]


def hammers(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(130)
    for bar in active("smith"):
        v, _ = chord_at(bar)
        for beat, idx, vel in SMITH:
            two_smiths = idx == 2                 # light taps from a second smith
            inst.place(buf, inst.hammer(v[idx] + 12, vel * rng.uniform(0.9, 1.05), rng),
                       t(bar, beat), pan=0.4 if two_smiths else -0.3)
    for bar in active("hammer_one"):
        v, _ = chord_at(bar)
        inst.place(buf, inst.hammer(v[0] + 12, 0.8, rng), t(bar), pan=-0.3)
    return buf


def plucks(n):
    """Low plucked strings walking under the horn."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(131)
    for bar in active("plucks"):
        v, r = chord_at(bar)
        for i, m in enumerate([r, v[0], v[1], v[0], r + 12, v[1], v[2], v[1]]):
            inst.place(buf, inst.pluck(m, 0.6 if i % 2 else 0.85, ring=0.8, bright=0.4, rng=rng),
                       t(bar, i / 2), pan=0.25)
    return buf


def workshop(n):
    """Fire, bellows, steam and the big drum."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(132)
    fire_bars = list(active("fire"))
    fire = inst.crackle(len(fire_bars) * BAR + 3, rng=rng)
    inst.place(buf, fire, t(fire_bars[0]), pan=-0.2, gain=0.7)
    inst.place(buf, inst.crackle(len(fire_bars) * BAR + 3, rng=rng), t(fire_bars[0]), pan=0.3,
               gain=0.5)
    for bar in active("bellows"):
        for half in (0, 2):
            inst.place(buf, inst.bellows(BEAT * 1.8, rng), t(bar, half), pan=-0.5, gain=0.9)
    for bar in active("drum"):
        inst.place(buf, inst.war_drum(62, 0.9, rng), t(bar, 0), pan=0)
        inst.place(buf, inst.war_drum(62, 0.6, rng), t(bar, 2), pan=0)
    for bar in active("steam"):
        if bar % 4 == 3:
            inst.place(buf, inst.hiss(1.5, rng), t(bar, 3), pan=0.5, gain=0.6)
    for bar in starts("steam_big"):
        inst.place(buf, inst.hiss(4.0, rng), t(bar), pan=0.2)
        inst.place(buf, inst.hiss(4.0, rng), t(bar, 0.1), pan=-0.4, gain=0.7)
    return buf


MIX = {         # (loudness while sounding, forge-room send)
    "drone":    (-24, 0.25),
    "bass":     (-22, 0.05),
    "hammers":  (-19, 0.30),
    "horn":     (-21, 0.40),
    "plucks":   (-24, 0.25),
    "workshop": (-22, 0.20),
}
ROOM_RETURN = 0.3
TARGET_DB = -17


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "forge_v1"
    seconds = TOTAL_BARS * BAR + 5
    n = int(seconds * SR)
    stems = {
        "drone": fit(render_part(drone_notes(), setup_siege_drone, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_soft_bass, seconds), n),
        "hammers": hammers(n),
        "horn": fit(render_part(horn_notes(), setup_siege_lead, seconds), n),
        "plucks": plucks(n), "workshop": workshop(n),
    }
    shape = {
        "drone": Pedalboard([HighpassFilter(70), LowpassFilter(1200)]),
        "bass": Pedalboard([LowpassFilter(600), Compressor(-20, 3)]),
        "horn": Pedalboard([LowpassFilter(2200)]),           # mellow, far-off horn
        "hammers": Pedalboard([Compressor(-18, 3, attack_ms=2, release_ms=100)]),
        "plucks": Pedalboard([HighpassFilter(90)]),
        "workshop": Pedalboard([HighpassFilter(40)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # A stone forge room: smaller and warmer than the cave.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    room = fit(Pedalboard([HighpassFilter(200),
                           Reverb(room_size=0.65, damping=0.7, wet_level=1.0,
                                  dry_level=0.0, width=0.9),
                           LowpassFilter(4500)])(send, SR), n)
    mix = sum(stems.values()) + room * ROOM_RETURN
    mix = Pedalboard([Compressor(threshold_db=-18, ratio=2, attack_ms=15,
                                 release_ms=200)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "room": room * ROOM_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
