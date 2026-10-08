#!/usr/bin/env python3
"""Marble Siege track: a hostile wave hitting the machine.

Same tempo (90) and key centre (A minor) as factory.py so the two can
crossfade in-game. The Factory's clock ticks come back at double speed, the
machine straining. Drone, bass, arp and lead are Surge XT; drums and effects
are hand-built in instruments.py.

    .venv/bin/python siege.py [name]      -> renders/<name>.mp3
"""
import sys

import numpy as np
from pedalboard import (Compressor, Delay, HighpassFilter, LowpassFilter,
                        Pedalboard, Reverb)

import instruments as inst
from mixing import SR, balance, db, export, fit, limit, report
from render import render_part
from sounds import setup_arp, setup_bass, setup_siege_drone, setup_siege_lead

BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT

# --- harmony: 8-bar cycle of 2-bar chords, (drone voicing, bass root) ---------
# Am - Bb - Dm - E. The Bb, one step above A, is the menacing chord.
CYCLE = [
    ([45, 57, 60, 64], 45),   # A minor
    ([46, 58, 62, 65], 46),   # B flat major: the threat
    ([50, 57, 62, 65], 50),   # D minor
    ([52, 56, 59, 64], 52),   # E major: tension, pulls back to A
]


def chord_at(bar):
    return CYCLE[(bar % 8) // 2]


# --- structure ---------------------------------------------------------------
SECTIONS = [
    ("alarm",     4, {"drone", "ticks", "drums_build", "riser"}),
    ("march",     8, {"drone", "ticks", "bass8", "arp", "kit_half", "drums", "boom"}),
    ("assault",  16, {"drone", "ticks", "gallop", "arp", "kit", "drums", "lead", "anvil", "boom"}),
    ("break",     4, {"drone", "arp", "drums_sparse", "riser"}),
    ("final",    16, {"drone", "ticks", "gallop", "arp", "kit", "kit_drive", "drums",
                      "lead_hi", "anvil", "boom"}),
    ("aftermath", 4, {"drone", "ticks_slow", "boom"}),
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
    """First bar of every section that has `layer`."""
    return [a for _, a, _, layers in spans() if layer in layers]


def ends(layer):
    return [b for _, _, b, layers in spans() if layer in layers]


def t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


# --- Surge parts -------------------------------------------------------------
def drone_notes():
    return [(t(bar), 2 * BAR * 0.98, m, 75)
            for bar in active("drone") if bar % 2 == 0
            for m in chord_at(bar)[0]]


def bass_notes():
    out = []
    for bar in sorted(set(active("bass8")) | set(active("gallop"))):
        r = chord_at(bar)[1] - 12
        gallop = bar in set(active("gallop"))
        for beat in range(4):
            hits = [0, 0.5, 0.75] if gallop else [0, 0.5]
            for h in hits:
                up = gallop and beat == 3 and h == 0.75
                out.append((t(bar, beat + h), BEAT * 0.22, r + (12 if up else 0),
                            110 if h == 0 else 85))
    return out


def arp_notes():
    out = []
    order = [0, 1, 2, 3, 2, 1, 2, 3]
    for bar in active("arp"):
        v = chord_at(bar)[0][1:]
        tones = [m + 12 for m in v] + [v[0] + 24]
        for i in range(16):
            out.append((t(bar, i / 4), BEAT / 4 * 0.5, tones[order[i % 8]],
                        100 if i % 4 == 0 else 72))
    return out


# 8-bar melody: (beat, length in beats, note)
LEAD = [
    (0, 3, 69), (3, 1, 72), (4, 2, 71), (6, 2, 69),
    (8, 3, 70), (11, 1, 74), (12, 4, 77),
    (16, 2, 76), (18, 2, 74), (20, 1, 77), (21, 1, 76), (22, 2, 74),
    (24, 2, 76), (26, 2, 68), (28, 2, 71), (30, 2, 76),
]


def lead_notes():
    out = []
    for layer, shift in (("lead", 0), ("lead_hi", 12)):
        for bar in list(active(layer))[::8]:
            for beat, length, m in LEAD:
                out.append((t(bar) + beat * BEAT, length * BEAT * 0.92, m + shift, 95))
    return out


# --- drums and effects ---------------------------------------------------------
def ticks(n):
    """The Factory's clock, now running at double speed, then winding down."""
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(30)
    for bar in active("ticks"):
        for i in range(16):
            inst.place(buf, inst.tick(3300 if i % 2 == 0 else 2400,
                                      0.9 if i % 4 == 0 else 0.5, rng),
                       t(bar, i / 4), pan=-0.4 if i % 2 == 0 else 0.4)
    for bar in starts("ticks_slow"):       # machine running down to a stop
        at, gap, i = t(bar), BEAT / 4, 0
        while at < t(bar + 4) - 0.5:
            inst.place(buf, inst.tick(3300 if i % 2 == 0 else 2400, 0.7, rng), at,
                       pan=-0.4 if i % 2 == 0 else 0.4)
            at += gap
            gap *= 1.09
            i += 1
    return buf


def kit(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(31)
    kick, sn = inst.hard_kick(rng=rng), inst.snare(rng=rng)
    half, full, drive = set(active("kit_half")), set(active("kit")), set(active("kit_drive"))
    fill_bars = {b - 1 for b in ends("kit") + ends("kit_half")}
    for bar in sorted(half | full):
        last4 = bar in drive and bar >= max(drive) - 3
        if bar in half:
            kicks, snares = [0], [2]
        else:
            kicks, snares = ([0, 1, 2, 3] if last4 else [0, 1.75, 2.5]), [1, 3]
        for k in kicks:
            inst.place(buf, kick, t(bar, k))
        if bar in fill_bars:              # snare roll into the next section
            snares = [s for s in snares if s < 2]
            for i in range(8):
                inst.place(buf, sn, t(bar, 2 + i / 4), pan=0.1, gain=0.35 + 0.08 * i)
        for s in snares:
            inst.place(buf, sn, t(bar, s), pan=0.1)
        steps = 16 if bar in drive else 8
        for i in range(steps):
            accent = (i % (steps // 4)) == steps // 8
            inst.place(buf, inst.hat(0.8 if accent else 0.45, rng), t(bar, 4 * i / steps),
                       pan=0.35)
        if bar in full and bar % 2:
            inst.place(buf, inst.hat(0.5, rng, open_=True), t(bar, 3.5), pan=0.35)
    return buf


def war_drums(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(32)
    low, high = inst.war_drum(72, rng=rng), inst.war_drum(115, rng=rng)
    build = list(active("drums_build"))
    for k, bar in enumerate(build):        # alarm: hits gather pace
        g = 0.3 + 0.5 * k / max(1, len(build) - 1)
        for beat in ([0], [0, 2], [0, 1, 2, 3], [i / 2 for i in range(8)])[min(k, 3)]:
            inst.place(buf, low if beat % 1 == 0 else high, t(bar, beat), -0.2, g)
    for bar in active("drums"):
        inst.place(buf, low, t(bar, 0), -0.2)
        inst.place(buf, low, t(bar, 2.5), -0.2, 0.8)
        inst.place(buf, high, t(bar, 3), 0.25, 0.7)
        inst.place(buf, high, t(bar, 3.5), 0.25, 0.6)
    for bar in active("drums_sparse"):
        inst.place(buf, low, t(bar, 0), -0.2, 0.9)
    return buf


def metal(n):
    buf = np.zeros((2, n), np.float32)
    for bar in list(active("anvil"))[::4]:
        inst.place(buf, inst.anvil(1.0), t(bar), pan=0.5)
        inst.place(buf, inst.anvil(0.6), t(bar + 2, 2.5), pan=-0.5)
    return buf


def fx(n):
    buf = np.zeros((2, n), np.float32)
    rng = np.random.default_rng(33)
    for b in ends("riser"):
        inst.place(buf, inst.riser(2 * BAR, rng), t(b - 2))
    for bar in starts("boom"):
        inst.place(buf, inst.boom(rng=rng), t(bar))
    return buf


# --- mix ---------------------------------------------------------------------
MIX = {          # (loudness while sounding, room send)
    "drone": (-22, 0.25),
    "bass":  (-19, 0.00),
    "arp":   (-23, 0.30),
    "lead":  (-20, 0.35),
    "kit":   (-17, 0.10),
    "drums": (-19, 0.25),
    "ticks": (-28, 0.15),
    "metal": (-25, 0.45),
    "fx":    (-20, 0.20),
}
ROOM_RETURN = 0.45
TARGET_DB = -15        # louder and denser than the Factory track


def throb(x):
    """Pulse the drone in 8th notes, like it's breathing hard."""
    tt = np.arange(x.shape[1]) / SR
    return x * (0.72 + 0.28 * np.cos(2 * np.pi * tt / (BEAT / 2)))


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "siege_v1"
    seconds = TOTAL_BARS * BAR + 4
    n = int(seconds * SR)

    stems = {
        "drone": fit(render_part(drone_notes(), setup_siege_drone, seconds), n),
        "bass": fit(render_part(bass_notes(), setup_bass, seconds), n),
        "arp": fit(render_part(arp_notes(), setup_arp, seconds), n),
        "lead": fit(render_part(lead_notes(), setup_siege_lead, seconds), n),
        "kit": kit(n), "drums": war_drums(n), "ticks": ticks(n),
        "metal": metal(n), "fx": fx(n),
    }
    stems["drone"] = throb(stems["drone"])
    shape = {
        "drone": Pedalboard([HighpassFilter(140)]),          # leave the lows to the bass
        "bass": Pedalboard([LowpassFilter(1400), Compressor(-20, 4)]),
        "arp": Pedalboard([HighpassFilter(300),
                           Delay(delay_seconds=BEAT * 0.75, feedback=0.3, mix=0.25)]),
        "lead": Pedalboard([Delay(delay_seconds=BEAT * 0.5, feedback=0.25, mix=0.2)]),
        "kit": Pedalboard([Compressor(-16, 3, attack_ms=5, release_ms=80)]),
        "ticks": Pedalboard([HighpassFilter(1000)]),
    }
    for k, board in shape.items():
        stems[k] = fit(board(stems[k], SR), n)
    for k, (target, _) in MIX.items():
        stems[k] = balance(stems[k], target).astype(np.float32)

    # A tighter, harder room than the Factory's cave: this is up close.
    send = sum(stems[k] * MIX[k][1] for k in MIX)
    room = fit(Pedalboard([HighpassFilter(250),
                           Reverb(room_size=0.7, damping=0.5, wet_level=1.0,
                                  dry_level=0.0, width=1.0),
                           LowpassFilter(6000)])(send, SR), n)

    mix = sum(stems.values()) + room * ROOM_RETURN
    mix = Pedalboard([Compressor(threshold_db=-18, ratio=2.5, attack_ms=15,
                                 release_ms=200)])(mix, SR)
    mix *= 10 ** (TARGET_DB / 20) / np.sqrt((mix[:, :int(t(TOTAL_BARS) * SR)] ** 2).mean())
    mix = limit(mix)

    mp3 = export(mix, name)
    report({**stems, "room": room * ROOM_RETURN}, mix,
           [(nm, t(a), t(b)) for nm, a, b, _ in spans()])
    print(f"{mp3}  {seconds:.0f}s  peak={np.abs(mix).max():.2f}  rms={db(mix):.1f}dB")


if __name__ == "__main__":
    main()
