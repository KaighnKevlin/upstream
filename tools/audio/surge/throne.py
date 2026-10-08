#!/usr/bin/env python3
"""Throne: a slow, menacing, heavy track in the spirit of the Emperor's Theme.

Low male choir chanting over sinister chord moves, timpani and deep brass,
on top of a half-time beat with a distorted bass that pumps against the kick.
Same 90 BPM as factory/siege (the beat is half-time, so it feels like 45).

    .venv/bin/python throne.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import (Compressor, Distortion, HighpassFilter, LowpassFilter,
                        Pedalboard, Reverb)

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_bass, setup_siege_drone, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# --- harmony -----------------------------------------------------------------
# Minor chords that slide to unexpected minor chords: that's the sinister,
# "something is wrong" sound. A minor -> F minor -> A minor -> E-flat minor
# (the furthest, most unsettling chord from A) -> E, which pulls home to A.
# (bar offset, bars, choir voicing, bass root)
CYCLE = [
    (0, 2, [45, 52, 57, 60], 33),   # A minor
    (2, 2, [41, 48, 53, 56], 29),   # F minor
    (4, 2, [45, 52, 57, 60], 33),   # A minor
    (6, 1, [39, 46, 51, 54], 27),   # E-flat minor
    (7, 1, [40, 47, 52, 56], 28),   # E major
]


def chord_at(bar):
    b = bar % 8
    for off, n, v, r in CYCLE:
        if off <= b < off + n:
            return v, r


# Chant line over one 8-bar cycle: (beat, beats long, note)
CHANT = [
    (0, 4, 57), (4, 3, 60), (7, 1, 59),
    (8, 4, 56), (12, 2, 53), (14, 2, 55),
    (16, 3, 57), (19, 1, 64), (20, 2, 62), (22, 2, 60),
    (24, 2, 58), (26, 2, 54), (28, 4, 56),
]

# --- structure ---------------------------------------------------------------
SECTIONS = [
    ("throne",  4, {"drone", "choir", "timp_roll"}),
    ("chant",   8, {"drone", "choir", "chant", "strings", "timp"}),
    ("march",   8, {"drone", "choir", "chant", "strings", "timp", "beat", "bass", "brass"}),
    ("wrath",  16, {"drone", "choir", "chant", "chant_hi", "strings", "timp", "beat",
                    "hats16", "bass", "brass", "metal"}),
    ("hush",    2, {"choir", "swell"}),
    ("end",     8, {"drone", "choir", "chant", "chant_hi", "strings", "timp", "beat",
                    "hats16", "bass", "brass", "metal", "final"}),
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


def chord_blocks(layer):
    """(bar, bars) for each chord change while `layer` plays."""
    on = set(active(layer))
    out = []
    for bar in sorted(on):
        b = bar % 8
        for off, n, _, _ in CYCLE:
            if b == off:
                out.append((bar, n))
    return out


# --- choir -------------------------------------------------------------------
def choir_notes():
    out = []
    for bar, n in chord_blocks("choir"):
        for m in chord_at(bar)[0]:
            out.append((t(bar), n * BAR, m, 0.8))
    return out


def chant_notes():
    out = []
    for layer, shift, vel in (("chant", 0, 1.0), ("chant_hi", 12, 0.6)):
        for bar in list(active(layer))[::8]:
            for beat, length, m in CHANT:
                out.append((t(bar) + beat * BEAT, length * BEAT * 0.95, m + shift, vel))
    return out


# --- Surge parts -------------------------------------------------------------
def drone_notes():
    return [(t(bar), n * BAR, chord_at(bar)[1] + 12, 90) for bar, n in chord_blocks("drone")]


def strings_notes():
    return [(t(bar), n * BAR * 0.98, m + 12, 80)
            for bar, n in chord_blocks("strings") for m in chord_at(bar)[0][1:]]


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] + 12
        for e in range(8):                       # steady 8ths; the pumping makes the groove
            out.append((t(bar, e / 2), BEAT * 0.45, r, 110 if e % 2 == 0 else 90))
    return out


def brass_notes():
    """Low brass hits on 1 and the 'and' of 2, a long blast every 4th bar."""
    out = []
    for bar in active("brass"):
        v, r = chord_at(bar)
        notes = [r + 12, v[1], v[2]]
        if bar % 4 == 3:
            out += [(t(bar), BAR * 0.95, m, 105) for m in notes]
        else:
            out += [(t(bar, 0), BEAT * 0.9, m, 110) for m in notes]
            out += [(t(bar, 1.5), BEAT * 0.6, m, 90) for m in notes]
    return out


# --- drums and effects ---------------------------------------------------------
def kick_times():
    """Half-time groove: kick on 1, a pickup before 3, and a skip on the 'and' of 4."""
    out = []
    for bar in active("beat"):
        out += [t(bar, 0), t(bar, 1.75)]
        if bar % 2:
            out.append(t(bar, 3.5))
    return out


def beat(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(50)
    kick, sn = inst.hard_kick(rng=rng), inst.snare(rng=rng)
    for k in kick_times():
        inst.place(buf, kick, k)
    hats16 = set(active("hats16"))
    for bar in active("beat"):
        inst.place(buf, sn, t(bar, 2), pan=0.05)     # the big half-time snare on 3
        if bar % 4 == 3:                               # hat roll: triplet stutter
            for i in range(6):
                inst.place(buf, inst.hat(0.3 + 0.08 * i, rng), t(bar, 3 + i / 6), 0.3)
        steps = 16 if bar in hats16 else 8
        for i in range(steps):
            if bar % 4 == 3 and i >= steps * 3 // 4:
                continue
            accent = i % (steps // 4) == steps // 8
            inst.place(buf, inst.hat(0.7 if accent else 0.35, rng),
                       t(bar, 4 * i / steps), pan=0.3)
    return buf


def timpani(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(51)
    for bar in active("timp_roll"):        # low rumble that swells into the chant
        k = bar - starts("timp_roll")[0]
        for i in range(32):
            g = (0.08 + 0.12 * k + 0.12 * i / 32) * rng.uniform(0.85, 1.0)
            inst.place(buf, inst.war_drum(55, g, rng), t(bar, i / 8), -0.1)
    for bar in active("timp"):
        r = hz_root(bar)
        inst.place(buf, inst.war_drum(r, 1.0, rng), t(bar, 0), -0.1)
        if bar % 2:
            inst.place(buf, inst.war_drum(r * 1.5, 0.7, rng), t(bar, 3), 0.1)
            inst.place(buf, inst.war_drum(r * 1.5, 0.8, rng), t(bar, 3.5), 0.1)
    return buf


def hz_root(bar):
    f = inst.hz(chord_at(bar)[1] + 12)
    return f if f > 50 else f * 2


def metal(n):
    buf = np.zeros((2, n), np.float32)
    for bar in list(active("metal"))[::4]:
        inst.place(buf, inst.anvil(0.9), t(bar), pan=0.5)
    return buf


def fx(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(52)
    for bar in starts("swell"):
        inst.place(buf, inst.riser(2 * BAR, rng), t(bar))
    for bar in starts("beat") + starts("final"):
        inst.place(buf, inst.boom(rng=rng), t(bar))
    end = TOTAL_BARS
    inst.place(buf, inst.boom(1.0, rng), t(end - 1, 2))  # last hit before the choir fades
    return buf


# --- mix ---------------------------------------------------------------------
MIX = {          # (loudness while sounding, hall send)
    "choir":   (-21, 0.55),
    "chant":   (-19, 0.45),
    "drone":   (-21, 0.05),
    "strings": (-25, 0.30),
    "bass":    (-19, 0.00),
    "brass":   (-21, 0.35),
    "beat":    (-17, 0.12),
    "timpani": (-19, 0.35),
    "metal":   (-27, 0.50),
    "fx":      (-20, 0.25),
}
HALL_RETURN = 0.22
TARGET_DB = -15
RIDE = {"throne": -6, "chant": -2}     # section volume (dB) so the start builds


def ride(n):
    """Volume curve across sections, eased so there are no jumps."""
    g = np.ones(n)
    for name, a, b, _ in spans():
        g[int(t(a) * SR):int(t(b) * SR)] = 10 ** (RIDE.get(name, 0) / 20)
    return inst.smooth(g, int(BAR * SR))


def tremolo(x, steps=4):
    """Fast, hard volume chop (16th notes): agitated bowed strings."""
    tt = np.arange(x.shape[1]) / SR
    gate = (np.sin(2 * np.pi * tt * steps / BEAT) > 0).astype(np.float32)
    return x * (0.3 + 0.7 * inst.smooth(gate, int(0.006 * SR)))


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "throne_v1"
    seconds = TOTAL_BARS * BAR + 5
    n = int(seconds * SR)

    choir = inst.formant(inst.choir_source(choir_notes(), n, voices=6, seed=40), "oh")
    chant = inst.formant(inst.choir_source(chant_notes(), n, voices=8, seed=41), "ah")
    stems = {
        "choir": choir, "chant": chant,
        "drone": fit(render_part(drone_notes(), setup_bass, seconds), n),
        "strings": fit(render_part(strings_notes(), setup_siege_drone, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_bass, seconds), n),
        "brass": fit(render_part(brass_notes(), setup_siege_lead, seconds), n),
        "beat": beat(n), "timpani": timpani(n), "metal": metal(n), "fx": fx(n),
    }
    stems["strings"] = tremolo(stems["strings"])

    shape = {
        "drone": Pedalboard([LowpassFilter(200)]),               # pure sub rumble
        "bass": Pedalboard([HighpassFilter(60), Distortion(drive_db=18),
                            LowpassFilter(1800), Compressor(-20, 4)]),
        "brass": Pedalboard([Distortion(drive_db=6), LowpassFilter(2500)]),
        "strings": Pedalboard([HighpassFilter(200), LowpassFilter(5000)]),
        "beat": Pedalboard([Compressor(-16, 3, attack_ms=5, release_ms=80)]),
        "choir": Pedalboard([HighpassFilter(80)]),
        "chant": Pedalboard([HighpassFilter(100)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # The pump: bass and drone dip hard on every kick, choir and strings a little.
    kicks = kick_times()
    for k, depth in (("bass", 0.85), ("drone", 0.7), ("strings", 0.3), ("choir", 0.2)):
        stems[k] = stems[k] * inst.duck(n, kicks, depth, release=0.22)

    # A huge stone hall.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    hall = fit(Pedalboard([HighpassFilter(220),
                           Reverb(room_size=0.95, damping=0.6, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(5000)])(send, SR), n)

    mix = (sum(stems.values()) + hall * HALL_RETURN) * ride(n)
    mix = Pedalboard([Compressor(threshold_db=-18, ratio=2.5, attack_ms=15,
                                 release_ms=200)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "hall": hall * HALL_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
