#!/usr/bin/env python3
"""Throne v3: v2's energy, softened, with a new palette of sounds.

From v2: no silent gaps, no siren, much less distortion, no deliberately
clashing notes in the stabs and brass, a ringing fade instead of a hard cut.
New: plucked strings carry the racing line, bowed metal swells, a heartbeat,
cave wind, reverse-echo swells into big hits, and a warped music box playing
the Factory track's bell tune.

    .venv/bin/python throne3.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import (Compressor, Distortion, HighpassFilter, LowpassFilter,
                        Pedalboard, Reverb)

import instruments as inst
from factory import BELL as FACTORY_TUNE
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_bass, setup_siege_drone, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

CYCLE = [   # Am - Fm - Am - Ebm - E, as in throne v1/v2
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
STABS = [0, 3, 6, 8, 11, 14]        # 3+3+2 accents in 16th-note steps

SECTIONS = [   # (name, bars, layers, half steps up per 8-bar half)
    ("omen",    4, {"wind", "heart", "choir", "metal_swell", "timp_roll"}, (0,)),
    ("hunt",    8, {"choir", "pluck", "beat", "bass", "timp", "ticks", "strings"}, (0,)),
    ("wrath",  16, {"choir", "pluck", "beat", "bass", "timp", "ticks", "strings",
                    "chant", "stabs", "brass", "anvil", "reverse"}, (0, 0)),
    ("break",   4, {"wind", "heart", "musicbox", "pluck_soft", "metal_swell", "riser"}, (1,)),
    ("frenzy", 16, {"choir", "pluck", "beat", "hats16", "bass", "timp", "ticks", "strings",
                    "chant", "chant_hi", "stabs", "brass", "anvil", "reverse"}, (1, 1)),
    ("end",     2, {"final", "metal_swell", "choir"}, (1,)),
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
    out = [(t(bar), n * BAR, m, 0.8)
           for bar, n in chord_blocks("choir") for m in chord_at(bar)[0]]
    end = starts("final")[0]                      # last chord rings out long
    out += [(t(end), 2 * BAR, m, 0.9) for m in chord_at(end - 1)[0]]
    return out


def chant_notes():
    out = []
    for layer, up, vel in (("chant", 0, 1.0), ("chant_hi", 12, 0.6)):
        for bar in list(active(layer))[::8]:
            for beat, length, m in CHANT:
                out.append((t(bar) + beat * BEAT, length * BEAT * 0.9,
                            m + up + shift(bar + int(beat // 4)), vel))
    return out


def stab_notes():
    """Shouted choir hits on the chord's own notes, every other bar only."""
    out = []
    for bar in active("stabs"):
        if bar % 2:
            continue
        v, _ = chord_at(bar)
        for i, s in enumerate(STABS[:3]):
            out += [(t(bar, s / 4), BEAT * 0.3, m, 1.0 if i == 0 else 0.7) for m in v[1:]]
    return out


# --- Surge parts -------------------------------------------------------------
def strings_notes():
    return [(t(bar), n * BAR * 0.98, m + 12, 75)
            for bar, n in chord_blocks("strings") for m in chord_at(bar)[0][1:]]


def bass_notes():
    out = []
    for bar in active("bass"):
        r = chord_at(bar)[1] + 12
        for e in range(8):
            out.append((t(bar, e / 2), BEAT * 0.4, r + (12 if e == 3 else 0),
                        110 if e % 2 == 0 else 90))
    return out


def brass_notes():
    """Power chords (root, fifth, octave) on the 3+3+2 accents, every other bar."""
    out = []
    for bar in active("brass"):
        if bar % 2 == 0:
            continue
        _, r = chord_at(bar)
        chord = [r + 24, r + 31, r + 36]
        for i, s in enumerate(STABS[:3]):
            length = BEAT * (1.4 if i == 2 else 0.5)
            out += [(t(bar, s / 4), length, m, 115 if i == 0 else 95) for m in chord]
    return out


# --- hand-built parts --------------------------------------------------------
def plucks(n):
    """Racing plucked strings: root, fifth, minor sixth, fifth (unsettled, not
    clashing), alternating sides."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(100)
    cell = [0, 7, 8, 7, 0, 7, 12, 7]
    soft = set(active("pluck_soft"))
    for bar in sorted(set(active("pluck")) | soft):
        _, r = chord_at(bar)
        top = r + 36
        for i in range(16):
            if bar in soft and i % 2:
                continue
            vel = (1.0 if i % 4 == 0 else 0.65) * (0.5 if bar in soft else 1.0)
            note = inst.pluck(top + cell[i % 8], vel, ring=0.9, bright=0.7, rng=rng)
            inst.place(buf, note, t(bar, i / 4), pan=-0.5 if i % 2 else 0.5)
    return buf


def kick_times():
    out = []
    for bar in active("beat"):
        out += [t(bar, h) for h in (0, 1.75, 2.5)]
    return out


def beat(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(101)
    kick, sn = inst.hard_kick(rng=rng), inst.snare(rng=rng)
    for k in kick_times():
        inst.place(buf, kick, k)
    hats16 = set(active("hats16"))
    for bar in active("beat"):
        for s in (1, 3):
            inst.place(buf, sn, t(bar, s), pan=0.05)
        inst.place(buf, sn, t(bar, 3.75), pan=0.1, gain=0.2)
        steps = 16 if bar in hats16 else 8
        for i in range(steps):
            accent = i % (steps // 4) == steps // 8
            inst.place(buf, inst.hat(0.6 if accent else 0.3, rng), t(bar, 4 * i / steps), 0.35)
    return buf


def drums(n):
    """Timpani and frame drums (big hand drums) on the 3+3+2 accents."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(102)
    for bar in active("timp_roll"):
        if bar != max(active("timp_roll")):
            continue
        for i in range(32):
            inst.place(buf, inst.war_drum(55, 0.1 + 0.4 * i / 32, rng), t(bar, i / 8), -0.1)
    for bar in active("timp"):
        f = inst.hz(chord_at(bar)[1] + 12)
        f = f if f > 50 else f * 2
        inst.place(buf, inst.war_drum(f, 1.0, rng), t(bar, 0), -0.15)
        for s in STABS[1:3] + STABS[4:]:
            inst.place(buf, inst.war_drum(150, 0.45, rng), t(bar, s / 4), 0.3)
    return buf


def ticks(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(103)
    for bar in active("ticks"):
        for i in range(8):
            inst.place(buf, inst.tick(3300 if i % 2 else 2400, 0.7 if i % 2 == 0 else 0.4, rng),
                       t(bar, i / 2), pan=-0.5 if i % 2 else 0.5)
    return buf


def textures(n):
    """Wind, heartbeat, bowed metal and the warped music box."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(104)
    for name, a, b, layers in spans():
        if "wind" in layers:
            w = inst.wind((b - a) * BAR + 2, rng)
            inst.place(buf, w, t(a), pan=-0.3, gain=0.8)
            inst.place(buf, inst.wind((b - a) * BAR + 2, rng), t(a), pan=0.3, gain=0.8)
        if "metal_swell" in layers:
            f0 = inst.hz(chord_at(a)[1] + 24)
            inst.place(buf, inst.bowed_metal(f0, 6.0, rng), t(a), pan=0.4)
    heart = set(active("heart"))
    for bar in sorted(heart):
        for beat in range(4):
            inst.place(buf, inst.heartbeat(0.8), t(bar, beat))
    for bar in starts("musicbox"):
        for beat, m, v in FACTORY_TUNE:
            if beat < 16:
                inst.place(buf, inst.warble(inst.bell(m + 12 + shift(bar), v * 0.8)),
                           t(bar) + beat * BEAT, pan=0.2)
    return buf


def hits(n):
    """Anvils, booms and risers."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(105)
    for bar in list(active("anvil"))[::4]:
        inst.place(buf, inst.anvil(0.8), t(bar), pan=0.5)
    for bar in starts("riser"):
        inst.place(buf, inst.riser(2 * BAR, rng), t(bar + 2), gain=0.7)
    for bar in starts("beat") + starts("final"):
        inst.place(buf, inst.boom(rng=rng), t(bar))
    return buf


def reverse_swells(n, source):
    """Take the sound of each big downbeat, echo it, play the echo backwards
    so it swells up and lands exactly on the hit."""
    buf = np.zeros((2, n), np.float32)
    hall = Pedalboard([Reverb(room_size=0.9, wet_level=1.0, dry_level=0.0, width=1.0)])
    length = int(2 * BEAT * SR)
    downbeats = [b for b in active("reverse") if b % 4 == 0] + starts("final")
    for bar in downbeats:
        s = int(t(bar) * SR)
        grab = np.zeros((2, length), np.float32)
        piece = source[:, s:s + int(0.25 * SR)]
        grab[:, :piece.shape[1]] = piece
        rev = hall(grab, SR)[:, ::-1]
        a = max(0, s - length)
        buf[:, a:s] += rev[:, length - (s - a):]
    return buf


# --- mix ---------------------------------------------------------------------
MIX = {          # (loudness while sounding, hall send)
    "choir":    (-22, 0.45),
    "chant":    (-20, 0.40),
    "stabs":    (-22, 0.45),
    "plucks":   (-20, 0.25),
    "strings":  (-26, 0.30),
    "bass":     (-19, 0.00),
    "brass":    (-21, 0.35),
    "beat":     (-17, 0.12),
    "drums":    (-19, 0.25),
    "ticks":    (-29, 0.15),
    "textures": (-22, 0.45),
    "hits":     (-21, 0.30),
    "reverse":  (-21, 0.00),
}
HALL_RETURN = 0.25
TARGET_DB = -15
RIDE = {"omen": -4, "break": -2}      # section volume (dB): quieter start and breather


def ride(n):
    g = np.ones(n)
    for name, a, b, _ in spans():
        g[int(t(a) * SR):int(t(b) * SR)] = 10 ** (RIDE.get(name, 0) / 20)
    return inst.smooth(g, int(BAR * SR / 2))


def tremolo(x, steps=4):
    tt = np.arange(x.shape[1]) / SR
    gate = (np.sin(2 * np.pi * tt * steps / BEAT) > 0).astype(np.float32)
    return x * (0.4 + 0.6 * inst.smooth(gate, int(0.008 * SR)))


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "throne_v3"
    seconds = TOTAL_BARS * BAR + 6
    n = int(seconds * SR)

    end = starts("final")[0]
    final_stab = [(t(end), BEAT * 0.4, m, 1.0) for m in chord_at(end - 1)[0][1:]]
    stems = {
        "choir": inst.formant(inst.choir_source(choir_notes(), n, 6, 110), "oh"),
        "chant": inst.formant(inst.choir_source(chant_notes(), n, 8, 111, attack=0.2), "ah"),
        "stabs": inst.formant(inst.choir_source(stab_notes() + final_stab, n, 8, 112,
                                                attack=0.02, tail=0.3), "ah"),
        "plucks": plucks(n),
        "strings": fit(render_part(strings_notes(), setup_siege_drone, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_bass, seconds), n),
        "brass": fit(render_part(brass_notes(), setup_siege_lead, seconds), n),
        "beat": beat(n), "drums": drums(n), "ticks": ticks(n),
        "textures": textures(n), "hits": hits(n),
    }
    stems["strings"] = tremolo(stems["strings"])
    shape = {
        "choir": Pedalboard([HighpassFilter(80)]),
        "chant": Pedalboard([HighpassFilter(100)]),
        "stabs": Pedalboard([HighpassFilter(150), Distortion(drive_db=4)]),
        "plucks": Pedalboard([HighpassFilter(200), Compressor(-18, 3)]),
        "strings": Pedalboard([HighpassFilter(200), LowpassFilter(4500)]),
        "bass": Pedalboard([HighpassFilter(45), Distortion(drive_db=10),
                            LowpassFilter(1500), Compressor(-20, 4)]),
        "brass": Pedalboard([Distortion(drive_db=5), LowpassFilter(2600)]),
        "beat": Pedalboard([Compressor(-16, 3, attack_ms=5, release_ms=80)]),
        "ticks": Pedalboard([HighpassFilter(1200)]),
        "textures": Pedalboard([HighpassFilter(40)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        if k != "reverse":
            stems[k] = balance(stems[k], target).astype(np.float32)

    # Reverse swells are built from the choir + stabs + brass that land on each hit.
    stems["reverse"] = balance(reverse_swells(n, stems["choir"] + stems["stabs"] + stems["brass"]),
                               MIX["reverse"][0]).astype(np.float32)

    kicks = kick_times()
    for k, depth in (("bass", 0.7), ("choir", 0.2), ("strings", 0.25)):
        stems[k] = stems[k] * inst.duck(n, kicks, depth, release=0.2)

    send = sum(stems[k] * MIX[k][1] for k in MIX)
    hall = fit(Pedalboard([HighpassFilter(220),
                           Reverb(room_size=0.92, damping=0.55, wet_level=1.0,
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
