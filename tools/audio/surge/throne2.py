#!/usr/bin/env python3
"""Throne v2: the Throne track pushed to aggressive, jarring and panicky.

Changes from throne.py: no slow intro (it opens on an alarm); a breakbeat
instead of a half-time groove; a racing high string line built on clashing
notes; choir and brass as short shouted stabs on lopsided 3+3+2 accents;
sudden one-beat silences; screeching sliding string clusters; a siren; and
the whole song climbing a half step at a time as panic rises.

    .venv/bin/python throne2.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import (Bitcrush, Compressor, Distortion, HighpassFilter,
                        LowpassFilter, Pedalboard, Reverb)

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_bass, setup_siege_drone, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# Same sinister chords as throne.py: Am - Fm - Am - Ebm - E.
CYCLE = [
    (0, 2, [45, 52, 57, 60], 33),
    (2, 2, [41, 48, 53, 56], 29),
    (4, 2, [45, 52, 57, 60], 33),
    (6, 1, [39, 46, 51, 54], 27),
    (7, 1, [40, 47, 52, 56], 28),
]
CHANT = [
    (0, 4, 57), (4, 3, 60), (7, 1, 59),
    (8, 4, 56), (12, 2, 53), (14, 2, 55),
    (16, 3, 57), (19, 1, 64), (20, 2, 62), (22, 2, 60),
    (24, 2, 58), (26, 2, 54), (28, 4, 56),
]
# Lopsided accents: 16th-note steps 0, 3, 6 | 8, 11, 14 (3+3+2, twice per bar).
STABS = [0, 3, 6, 8, 11, 14]

# --- structure: (name, bars, layers, half steps up per 8-bar half) ------------
SECTIONS = [
    ("alarm",   2, {"siren", "shriek", "timp_roll", "ticks"}, (0,)),
    ("hunt",    8, {"choir", "ostinato", "beat", "bass", "timp", "ticks"}, (0,)),
    ("wrath",  16, {"choir", "ostinato", "beat", "bass", "timp", "ticks", "chant",
                    "stabs", "brass", "metal", "gaps", "siren_low"}, (0, 1)),
    ("shriek",  2, {"shriek", "ostinato", "riser"}, (1,)),
    ("frenzy", 16, {"choir", "ostinato", "beat", "double", "bass", "timp", "ticks",
                    "chant", "chant_hi", "stabs", "brass", "metal", "gaps", "gaps2",
                    "siren_low"}, (2, 3)),
    ("cut",     1, {"final"}, (3,)),
]
TOTAL_BARS = sum(n for _, n, _, _ in SECTIONS)


def spans():
    bar = 0
    for name, n, layers, _ in SECTIONS:
        yield name, bar, bar + n, layers
        bar += n


def active(layer):
    for _, a, b, layers in spans():
        if layer in layers:
            yield from range(a, b)


def starts(layer):
    return [a for _, a, _, layers in spans() if layer in layers]


def shift(bar):
    """Half steps the whole song has climbed by this bar."""
    at = 0
    for _, n, _, ups in SECTIONS:
        if bar < at + n:
            return ups[min((bar - at) // 8, len(ups) - 1)]
        at += n
    return SECTIONS[-1][3][-1]


def chord_at(bar):
    b, k = bar % 8, shift(bar)
    for off, n, v, r in CYCLE:
        if off <= b < off + n:
            return [m + k for m in v], r + k


def t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


def chord_blocks(layer):
    on = set(active(layer))
    return [(bar, n) for bar in sorted(on) for off, n, _, _ in CYCLE if bar % 8 == off]


# --- voices ------------------------------------------------------------------
def choir_notes():
    return [(t(bar), n * BAR, m, 0.8)
            for bar, n in chord_blocks("choir") for m in chord_at(bar)[0]]


def chant_notes():
    out = []
    for layer, up, vel in (("chant", 0, 1.0), ("chant_hi", 12, 0.7)):
        for bar in list(active(layer))[::8]:
            for beat, length, m in CHANT:
                b = bar + int(beat // 4)
                out.append((t(bar) + beat * BEAT, length * BEAT * 0.9,
                            m + up + shift(b), vel))
    return out


def stab_notes():
    """Shouted choir hits: the chord's top three notes plus the note a half
    step above the root, so every stab clashes."""
    out = []
    for bar in active("stabs"):
        v, r = chord_at(bar)
        notes = v[1:] + [v[0] + 13]
        for i, s in enumerate(STABS):
            vel = 1.0 if i % 3 == 0 else 0.75
            out += [(t(bar, s / 4), BEAT * 0.2, m, vel) for m in notes]
    return out


# --- Surge parts -------------------------------------------------------------
def ostinato_notes():
    """Racing 16ths up high: root, the clashing half step above it, root,
    and the tritone (the most unstable note there is)."""
    out = []
    for bar in active("ostinato"):
        _, r = chord_at(bar)
        top = r + 48
        cells = [0, 1, 0, 6, 0, 1, 0, 7]
        for i in range(16):
            out.append((t(bar, i / 4), BEAT / 4 * 0.7, top + cells[i % 8],
                        115 if i % 4 == 0 else 85))
    return out


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] + 12
        for i in range(16):                       # driving 16ths
            if i % 4 == 3 and bar % 2:
                continue
            out.append((t(bar, i / 4), BEAT * 0.2, r + (12 if i in (6, 14) else 0),
                        115 if i % 4 == 0 else 85))
    return out


def brass_notes():
    """Brass clusters on the same lopsided accents as the choir stabs."""
    out = []
    for bar in active("brass"):
        _, r = chord_at(bar)
        cluster = [r + 24, r + 25, r + 30, r + 36]   # root, half step, tritone, octave
        for i, s in enumerate(STABS):
            length = BEAT * (0.9 if i in (2, 5) else 0.4)
            out += [(t(bar, s / 4), length, m, 120 if i % 3 == 0 else 95) for m in cluster]
    return out


# --- drums and effects ---------------------------------------------------------
def kick_times():
    out = []
    for bar in active("beat"):
        hits = [0, 1.75, 2.5]
        if bar in set(active("double")):
            hits += [0.5, 2.75, 3.25]
        if bar % 4 == 3:
            hits += [3.5, 3.75]
        out += [t(bar, h) for h in hits]
    return out


def beat(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(70)
    kick, sn = inst.hard_kick(rng=rng), inst.snare(rng=rng)
    for k in kick_times():
        inst.place(buf, kick, k)
    for bar in active("beat"):
        for s in (1, 3):
            inst.place(buf, sn, t(bar, s), pan=0.05)
        for g in (1.25, 2.25, 3.75):                  # nervous ghost notes
            inst.place(buf, sn, t(bar, g), pan=0.1, gain=0.25)
        if bar % 2:                                   # snare burst at the end of every 2 bars
            for i in range(6):
                inst.place(buf, sn, t(bar, 3 + i / 6), pan=0.1, gain=0.3 + 0.1 * i)
        for i in range(16):
            open_ = i % 8 == 6 and rng.uniform() < 0.5
            inst.place(buf, inst.hat(0.75 if i % 2 else 0.4, rng, open_), t(bar, i / 4), 0.35)
    return buf


def timpani(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(71)
    for bar in active("timp_roll"):
        k = bar - starts("timp_roll")[0]
        for i in range(32):
            g = (0.3 + 0.35 * (k + i / 32) / 2) * rng.uniform(0.85, 1.0)
            inst.place(buf, inst.war_drum(55, g, rng), t(bar, i / 8), -0.1)
    for bar in active("timp"):
        f = inst.hz(chord_at(bar)[1] + 12)
        f = f if f > 50 else f * 2
        for s in STABS[:3]:
            inst.place(buf, inst.war_drum(f, 0.9, rng), t(bar, s / 4), -0.15)
        inst.place(buf, inst.war_drum(f * 1.5, 0.8, rng), t(bar, 3), 0.15)
        inst.place(buf, inst.war_drum(f * 1.5, 0.9, rng), t(bar, 3.5), 0.15)
    return buf


def ticks(n):
    """The machine's clock, panicking: 16ths, every bar a little faster-sounding
    because the accent moves around."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(72)
    for bar in active("ticks"):
        for i in range(16):
            accent = i % 3 == bar % 3
            inst.place(buf, inst.tick(3400 if i % 2 else 2500, 0.9 if accent else 0.45, rng),
                       t(bar, i / 4), pan=-0.6 if i % 2 else 0.6)
    return buf


def metal(n):
    buf = np.zeros((2, n), np.float32)
    for bar in list(active("metal"))[::2]:
        inst.place(buf, inst.anvil(1.0), t(bar), pan=0.6 if bar % 4 else -0.6)
    return buf


def screams(n):
    """Shrieks, sirens, risers and booms: the panic effects."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(73)
    for bar in starts("shriek"):
        s = inst.shriek(2 * BAR, lo=72 + shift(bar), rise=12, rng=rng)
        buf[:, int(t(bar) * SR):int(t(bar) * SR) + s.shape[1]] += s[:, :n - int(t(bar) * SR)]
    for bar in starts("siren"):
        inst.place(buf, inst.siren(2 * BAR), t(bar), pan=-0.3)
    for bar in list(active("siren_low"))[::8]:
        inst.place(buf, inst.siren(2 * BAR, 520, 740, 1.3), t(bar), pan=0.4, gain=0.45)
    for bar in starts("riser"):
        inst.place(buf, inst.riser(2 * BAR, rng), t(bar), gain=0.8)
    for bar in starts("beat") + starts("final"):
        inst.place(buf, inst.boom(rng=rng), t(bar))
    return buf


def gap_mask(n):
    """Dead silence for the last beat of some bars, then everything slams back."""
    g = np.ones(n, np.float32)
    every = {b: 4 for b in active("gaps")} | {b: 2 for b in active("gaps2")}
    for bar, k in every.items():
        if bar % k == k - 1:
            g[int(t(bar, 3) * SR):int(t(bar + 1) * SR)] = 0
    return inst.smooth(g, int(0.004 * SR))


def final_mask(n):
    """Hard stop: after the last stab, only the hall echo remains."""
    g = np.ones(n, np.float32)
    end = starts("final")[0]
    g[int(t(end, 0.5) * SR):] = 0
    return inst.smooth(g, int(0.004 * SR))


# --- mix ---------------------------------------------------------------------
MIX = {          # (loudness while sounding, hall send)
    "choir":    (-23, 0.45),
    "chant":    (-19, 0.35),
    "stabs":    (-19, 0.40),
    "ostinato": (-21, 0.20),
    "bass":     (-18, 0.00),
    "brass":    (-19, 0.25),
    "beat":     (-16, 0.10),
    "timpani":  (-18, 0.25),
    "ticks":    (-27, 0.10),
    "metal":    (-25, 0.45),
    "screams":  (-19, 0.30),
}
HALL_RETURN = 0.22
TARGET_DB = -14        # louder than v1


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "throne_v2"
    seconds = TOTAL_BARS * BAR + 5
    n = int(seconds * SR)

    final_stab = [(t(starts("final")[0]), BEAT * 0.3, m, 1.0) for m in chord_at(TOTAL_BARS - 1)[0]]
    stems = {
        "choir": inst.formant(inst.choir_source(choir_notes(), n, 6, 80), "oh"),
        "chant": inst.formant(inst.choir_source(chant_notes(), n, 8, 81, attack=0.15), "ah"),
        "stabs": inst.formant(inst.choir_source(stab_notes() + final_stab, n, 8, 82,
                                                attack=0.01, tail=0.12), "ah"),
        "ostinato": fit(render_part(ostinato_notes(), setup_siege_lead, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_bass, seconds), n),
        "brass": fit(render_part(brass_notes(), setup_siege_lead, seconds), n),
        "beat": beat(n), "timpani": timpani(n), "ticks": ticks(n),
        "metal": metal(n), "screams": screams(n),
    }
    shape = {
        "choir": Pedalboard([HighpassFilter(80)]),
        "chant": Pedalboard([HighpassFilter(100), Distortion(drive_db=8)]),
        "stabs": Pedalboard([HighpassFilter(150), Distortion(drive_db=14)]),
        "ostinato": Pedalboard([HighpassFilter(500), Distortion(drive_db=10),
                                Bitcrush(bit_depth=10), LowpassFilter(7000)]),
        "bass": Pedalboard([HighpassFilter(45), Distortion(drive_db=22),
                            LowpassFilter(2200), Compressor(-20, 4)]),
        "brass": Pedalboard([Distortion(drive_db=14), LowpassFilter(3000)]),
        "beat": Pedalboard([Distortion(drive_db=4),
                            Compressor(-16, 4, attack_ms=3, release_ms=60)]),
        "ticks": Pedalboard([HighpassFilter(1200)]),
        "screams": Pedalboard([HighpassFilter(120)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    kicks = kick_times()
    for k, depth in (("bass", 0.8), ("choir", 0.3), ("ostinato", 0.25)):
        stems[k] = stems[k] * inst.duck(n, kicks, depth, release=0.15)

    gaps, stop = gap_mask(n), final_mask(n)
    for k in stems:
        if k != "screams":
            stems[k] = stems[k] * gaps
        if k not in ("stabs", "screams", "timpani"):
            stems[k] = stems[k] * stop

    send = sum(stems[k] * MIX[k][1] for k in MIX)
    hall = fit(Pedalboard([HighpassFilter(220),
                           Reverb(room_size=0.9, damping=0.5, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(5500)])(send, SR), n)

    mix = sum(stems.values()) + hall * HALL_RETURN
    mix = Pedalboard([Compressor(threshold_db=-16, ratio=3, attack_ms=10,
                                 release_ms=150)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS - 1) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "hall": hall * HALL_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
