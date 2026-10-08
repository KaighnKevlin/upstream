#!/usr/bin/env python3
"""End-of-siege stingers for the two banners: VAULT HELD and VAULT BROKEN.

Held: brass fanfare climbing F - G - A *major* (the minor key turning bright
is the victory), choir and pealing bells, then the Factory's clock ticks
back to work. Broken: a falling lament with a funeral bell, then the
Factory's music-box tune winding down as its spring runs out.

    .venv/bin/python banners.py [suffix]   -> renders/vault_held_<suffix>.mp3
                                              renders/vault_broken_<suffix>.mp3
"""
import sys

import numpy as np
from pedalboard import HighpassFilter, LowpassFilter, Pedalboard, Reverb

import instruments as inst
from factory import BELL as FACTORY_TUNE
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import apply, setup_cave_pad, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT


def t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


def finish(stems, targets, name, sections, target_db, room=0.92, ret=0.3):
    for k, lvl in targets.items():
        stems[k] = balance(stems[k], lvl[0]).astype(np.float32)
    n = next(iter(stems.values())).shape[1]
    send = sum(stems[k] * targets[k][1] for k in targets)
    hall = fit(Pedalboard([HighpassFilter(200),
                           Reverb(room_size=room, damping=0.5, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(6000)])(send, SR), n)
    mix = sum(stems.values()) + hall * ret
    body = mix[:, :int(sections[-1][2] * SR)]
    mix *= 10 ** (target_db / 20) / np.sqrt((body ** 2).mean())
    mix = limit(mix)
    mp3 = export(mix, name)
    report({**stems, "hall": hall * ret}, mix, sections)
    print(f"{mp3}  {n / SR:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB\n")


# --- VAULT HELD --------------------------------------------------------------
# F major, G major, then A major: borrowed bright chords climbing to a major
# home. (bar, bars, chord)
HELD_CHORDS = [(0, 1, [53, 57, 60, 65]), (1, 1, [55, 59, 62, 67]),
               (2, 3, [57, 61, 64, 69]), (5, 3, [57, 60, 64, 69])]   # ends back in A minor, at peace
# Fanfare: triplet pickups, then the long top note. (beat, beats, note)
FANFARE = [(0, 1 / 3, 72), (1 / 3, 1 / 3, 72), (2 / 3, 1 / 3, 72), (1, 3, 77),
           (4, 1 / 3, 74), (4 + 1 / 3, 1 / 3, 74), (4 + 2 / 3, 1 / 3, 74), (5, 3, 79),
           (8, 1 / 3, 76), (8 + 1 / 3, 1 / 3, 78), (8 + 2 / 3, 1 / 3, 80), (9, 7, 81)]


def setup_fanfare(s):
    """The siege war-horn, but staying bright while it holds a note."""
    setup_siege_lead(s)
    apply(s, {"a_filter_1_cutoff": 2200.0, "a_filter_eg_sustain": 85.0,
              "a_amp_eg_sustain": 95.0})


def held(name):
    bars = 8
    seconds = bars * BAR + 5
    n = int(seconds * SR)
    rng = np.random.default_rng(160)

    brass = []
    for b, ln, m in FANFARE:
        brass += [(t(0) + b * BEAT, ln * BEAT * 0.9, m, 110), (t(0) + b * BEAT, ln * BEAT * 0.9, m - 12, 95)]
    for bar, nb, chord in HELD_CHORDS[:3]:
        brass += [(t(bar), nb * BAR * 0.95, m - 12, 80) for m in chord[:3]]
    pad = [(t(bar), nb * BAR * 0.98, m, 60) for bar, nb, chord in HELD_CHORDS for m in chord]
    choir = [(t(bar), nb * BAR, m, 0.9) for bar, nb, chord in HELD_CHORDS[1:3] for m in chord]

    perc = np.zeros((2, n), np.float32)
    for beat in (0, 1 / 3, 2 / 3, 1, 4, 4 + 1 / 3, 4 + 2 / 3, 5):    # drums follow the fanfare
        inst.place(perc, inst.war_drum(80 if beat % 1 == 0 else 110, 0.9, rng), t(0, beat))
    for i in range(12):                                                 # roll into the big chord
        inst.place(perc, inst.war_drum(70, 0.3 + 0.05 * i, rng), t(1, 2 + i / 6))
    inst.place(perc, inst.boom(rng=rng), t(2))
    inst.place(perc, inst.anvil(0.7), t(2), pan=0.5)

    bells = np.zeros((2, n), np.float32)
    peal = [81, 76, 73, 69, 76, 73, 81, 85]                             # A major bells ringing down and up
    for i, m in enumerate(peal * 2):
        inst.place(bells, inst.bell(m, 0.8 - 0.03 * i), t(2, i / 2), pan=-0.4 + 0.1 * (i % 8))

    machine = np.zeros((2, n), np.float32)                              # back to work
    for bar in range(5, 8):
        for beat in range(4):
            inst.place(machine, inst.tick(2100 if beat % 2 else 3300, 0.6, rng), t(bar, beat),
                       pan=0.45 if beat % 2 else -0.45)
    for beat, m, v in FACTORY_TUNE[:4]:
        inst.place(machine, inst.bell(m, v * 0.6), t(5) + beat * BEAT, pan=0.2)

    stems = {
        "brass": fit(render_part(brass, setup_fanfare, seconds), n),
        "pad": fit(render_part(pad, setup_cave_pad, seconds), n),
        "choir": inst.formant(inst.choir_source(choir, n, 8, 161, attack=0.3), "ah"),
        "drums": perc, "bells": bells, "machine": machine,
    }
    stems["brass"] = fit(Pedalboard([LowpassFilter(3500)])(stems["brass"], SR), n)
    finish(stems, {"brass": (-18, 0.35), "pad": (-23, 0.3), "choir": (-21, 0.45),
                   "drums": (-19, 0.3), "bells": (-22, 0.45), "machine": (-25, 0.25)},
           name, [("fanfare", 0, t(2)), ("triumph", t(2), t(5)), ("work", t(5), t(8))], -16)


# --- VAULT BROKEN ------------------------------------------------------------
# A minor, F minor, then A minor low and alone. (bar, bars, chord)
BROKEN_CHORDS = [(0, 2, [45, 52, 57, 60]), (2, 2, [41, 48, 53, 56]), (4, 4, [33, 45, 52, 57])]
LAMENT = [(0, 2, 64), (2, 2, 62), (4, 4, 60), (8, 2, 60), (10, 2, 58), (12, 4, 56),
          (16, 6, 57)]


def broken(name):
    bars = 8
    seconds = bars * BAR + 6
    n = int(seconds * SR)
    rng = np.random.default_rng(170)

    pad = [(t(bar), nb * BAR * 0.98, m, 55) for bar, nb, chord in BROKEN_CHORDS for m in chord]
    choir = [(t(bar), nb * BAR, m, 0.8) for bar, nb, chord in BROKEN_CHORDS for m in chord if m >= 45]
    lament = [(t(0) + b * BEAT, ln * BEAT * 0.95, m - 12, 0.9) for b, ln, m in LAMENT]

    perc = np.zeros((2, n), np.float32)
    for i in range(24):                                       # timpani roll dying away
        inst.place(perc, inst.war_drum(55, 0.6 * (1 - i / 24) + 0.05, rng), t(0, i / 6))
    for bar in (0, 2, 4):                                     # funeral bell: low, slow
        inst.place(perc, inst.hammer(45, 0.9, rng), t(bar), pan=-0.2)
        inst.place(perc, inst.bowed_metal(inst.hz(57), 5.0, rng), t(bar), pan=0.3, gain=0.5)

    dying = np.zeros((2, n), np.float32)
    # The Factory's music box, its spring running down: each note later than
    # the last and sinking out of tune, until it stops.
    at, gap, sag = t(4), BEAT * 0.5, 0.0
    for i, (beat, m, v) in enumerate(FACTORY_TUNE[:9]):
        note = inst.bell(m, v * 0.7)
        ratio = 2 ** (-sag / 12)                              # play slower = lower
        idx = np.arange(0, note.size - 1, ratio)
        note = np.interp(idx, np.arange(note.size), note).astype(np.float32)
        inst.place(dying, inst.warble(note, 0.5, 25), at, pan=0.2)
        at += gap
        gap *= 1.22
        sag += 0.35
    for i in range(10):                                       # the gears clicking to a stop
        inst.place(dying, inst.tick(2400, 0.5 * (1 - i / 10), rng),
                   t(4) + sum(BEAT * 0.25 * 1.25 ** k for k in range(i)), pan=-0.4)

    stems = {
        "pad": fit(render_part(pad, setup_cave_pad, seconds), n),
        "choir": inst.formant(inst.choir_source(choir, n, 6, 171, attack=1.0, tail=2.0), "oo"),
        "lament": inst.formant(inst.choir_source(lament, n, 6, 172, attack=0.3), "oh"),
        "toll": perc, "musicbox": dying,
    }
    finish(stems, {"pad": (-23, 0.35), "choir": (-23, 0.5), "lament": (-20, 0.45),
                   "toll": (-20, 0.4), "musicbox": (-21, 0.4)},
           name, [("fall", 0, t(4)), ("windown", t(4), t(8))], -19)


if __name__ == "__main__":
    suffix = sys.argv[1] if len(sys.argv) > 1 else "v1"
    held(f"vault_held_{suffix}")
    broken(f"vault_broken_{suffix}")
