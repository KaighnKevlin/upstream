#!/usr/bin/env python3
"""Quick sound effects, in themed rounds.

Each effect is a function (rng) -> mono or stereo float array; it is rendered
in VARIANTS slightly different takes (so repeats don't sound robotic), each
normalised to its own peak level, and saved as sfx/<effect>_<n>.wav. A round
preview plays every effect's takes in a row with gaps between effects:
renders/sfx_<round>.mp3.

    .venv/bin/python sfx.py <round>        (rounds listed in ROUNDS at the end)
"""
import sys
from pathlib import Path

import numpy as np
from pedalboard import Pedalboard, Reverb
from pedalboard.io import AudioFile

import instruments as inst
from instruments import SR, _t, modes, smooth
from mixing import export

VARIANTS = 3
OUT = Path(__file__).parent / "sfx"


def noise(rng, seconds):
    return rng.uniform(-1, 1, int(seconds * SR))


def env(seconds, attack=0.002, decay=0.1):
    t = _t(seconds)
    return np.minimum(1, t / attack) * np.exp(-t / decay)


def sweep(f0, f1, seconds, curve=1.0):
    """Sine gliding f0 -> f1 (exponential glide)."""
    t = _t(seconds)
    f = f0 * (f1 / f0) ** ((t / seconds) ** curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def mix_at(*parts):
    """Overlay (start_sec, signal) parts into one mono buffer."""
    n = max(int(s * SR) + len(x) for s, x in parts)
    out = np.zeros(n)
    for s, x in parts:
        i = int(s * SR)
        out[i:i + len(x)] += x
    return out


def room(x, size=0.3, wet=0.2):
    st = np.vstack([x, x]).astype(np.float32) if x.ndim == 1 else x.astype(np.float32)
    st = np.pad(st, ((0, 0), (0, int(0.6 * SR))))
    return Pedalboard([Reverb(room_size=size, wet_level=wet, dry_level=1.0)])(st, SR)


LOOPS = {"low_health", "crawler_skitter", "mite_swarm", "drill_burrow", "dreadnought_engine"}


def finish(x, peak_db, loop=False):
    """Stereo, trimmed of trailing silence, short fade-out, set to a peak level.
    Loops keep their exact length and get no fade, so they repeat cleanly."""
    x = np.vstack([x, x]) if x.ndim == 1 else x
    x = x.astype(np.float32)
    if loop:
        return x * 10 ** (peak_db / 20) / (np.abs(x).max() + 1e-9)
    live = np.where(np.abs(x).max(axis=0) > 10 ** (-60 / 20) * np.abs(x).max())[0]
    x = x[:, : live[-1] + 1] if live.size else x
    fade = min(x.shape[1], int(0.01 * SR))
    x[:, -fade:] *= np.linspace(1, 0, fade)
    return x * 10 ** (peak_db / 20) / (np.abs(x).max() + 1e-9)


# =============================================================================
# Round 1: damage
# =============================================================================
def player_hurt(rng):
    """You get hit: a punchy thud, a sour metal clank, a quick falling 'oof' tone."""
    thud = sweep(160, 55, 0.25) * env(0.25, decay=0.07)
    clank = modes(_t(0.4), [(f, a, d) for f, a, d in
                            [(rng.uniform(700, 800), 0.5, 18), (1130, 0.35, 25), (1790, 0.25, 30)]])
    oof = sweep(rng.uniform(420, 470), 190, 0.18) * env(0.18, 0.005, 0.08) * 0.5
    crack = smooth(noise(rng, 0.06), 3) * env(0.06, decay=0.012)
    return np.tanh(mix_at((0, thud), (0, clank * 0.6), (0, crack * 0.7), (0.01, oof)) * 1.8)


def dome_hit(rng):
    """The vault dome takes a blow: a heavy boom and the dome shuddering
    like a struck bell, wobbling."""
    t = _t(1.6)
    boom = sweep(90, 38, 1.0) * env(1.0, decay=0.35)
    f = rng.uniform(300, 340)
    shudder = modes(t, [(f, 1.0, 3), (f * 1.006, 1.0, 3), (f * 2.32, 0.5, 5), (f * 3.1, 0.3, 7)])
    shudder *= 0.75 + 0.25 * np.sin(2 * np.pi * 7 * t)            # the wobble
    grit = smooth(noise(rng, 0.3), 12) * env(0.3, decay=0.05)
    return room(np.tanh(mix_at((0, boom), (0, shudder * 0.35), (0, grit)) * 1.5), 0.6, 0.25)


def piece_break(rng):
    """A wooden piece snaps apart: a sharp crack, splinters, bits clattering down."""
    crack = (noise(rng, 0.05) - smooth(noise(rng, 0.05), 4)) * env(0.05, decay=0.008)
    splinters = inst.woodblock(rng.uniform(0.3, 0.7), rng.uniform(0.6, 1.6))[:int(0.12 * SR)]
    parts = [(0, crack * 1.4), (0.005, splinters)]
    at = 0.08
    for i in range(rng.integers(4, 7)):                       # debris bouncing, getting quieter
        parts.append((at, inst.woodblock(0.5 * 0.75 ** i, rng.uniform(1.2, 2.2))[:int(0.08 * SR)]))
        at += rng.uniform(0.05, 0.11) * (0.85 ** i)
    return room(mix_at(*parts), 0.3, 0.15)


def low_health(rng):
    """Warning: a heavy heartbeat with a thin high ringing (loops cleanly at 1.3 s)."""
    beat = inst.heartbeat(1.0)
    t = _t(1.3)
    ring = np.sin(2 * np.pi * 2900 * t) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 1.3))
    out = np.zeros(int(1.3 * SR))
    out[:beat.size] += beat
    return loopable(out + ring, 1.3)


# =============================================================================
# Round 2: marbles
# =============================================================================
def glass(rng, f=None, vel=1.0, length=0.15):
    """Glass marble clack: very high, slightly clashing overtones, very short."""
    f = f or rng.uniform(2800, 3600)
    t = _t(length)
    return modes(t, [(f, 1.0, 60), (f * 1.58, 0.6, 80), (f * 2.37, 0.35, 110),
                     (f * 0.71, 0.3, 50)]) * vel


def marble_click(rng):
    """Two glass marbles knock together (a quick double tap, the bounce)."""
    return mix_at((0, glass(rng)), (rng.uniform(0.03, 0.05), glass(rng, vel=0.3)))


def short(x, seconds):
    """Cut a sound to length with a quick fade, for effects that fire constantly."""
    x = x[..., :int(seconds * SR)].copy()
    fade = int(min(0.4, seconds / 4) * SR)
    x[..., -fade:] *= np.linspace(1, 0, fade) ** 2
    return x


def marble_cup(rng):
    """A marble drops into a cup, spins round the inside and settles."""
    parts = [(0, glass(rng, vel=1.0)), (0.004, modes(_t(0.3), [(420, 0.6, 18), (1100, 0.2, 30)]))]
    at, gap = 0.12, 0.09
    for i in range(14):                             # round and round, faster and quieter
        parts.append((at, glass(rng, rng.uniform(3000, 3400), 0.35 * 0.88 ** i, 0.05)))
        at += gap
        gap *= 0.86
    t = _t(at)
    whirr = smooth(noise(rng, at), 25) * np.minimum(1, t / 0.1) * np.exp(-t * 2) * 0.15
    parts.append((0.1, whirr))
    return room(mix_at(*parts), 0.2, 0.1)


def marble_lift(rng):
    """The Upstream catches a marble: an airy shimmer rising up."""
    d = 0.45
    t = _t(d)
    rise = sweep(500, 1600, d, 0.7) * np.sin(np.pi * t / d) ** 2 * 0.4
    sparkles = mix_at(*[(i * 0.07, inst.sparkle(int(rng.choice([81, 84, 88, 91])) + i, 0.3)[:int(0.3 * SR)])
                        for i in range(4)])
    air = smooth(noise(rng, d), 6) * np.sin(np.pi * t / d) ** 2 * 0.25
    return short(room(mix_at((0, rise), (0, air), (0.03, sparkles)), 0.3, 0.15), 0.8)


def marble_fling(rng):
    """Flung off the top of the beam: a quick swish and a glint."""
    t = _t(0.35)
    swish = (noise(rng, 0.35) - smooth(noise(rng, 0.35), 3))
    swish = smooth(swish, 2) * np.sin(np.pi * t / 0.35) ** 3 * 0.5
    glint = inst.sparkle(int(rng.choice([86, 88, 91])), 0.6)[:int(0.3 * SR)]
    return short(room(mix_at((0, swish), (0.12, glint)), 0.2, 0.1), 0.6)


def marble_land(rng):
    """Lands on a wooden track and rolls away."""
    knock = inst.woodblock(0.8, rng.uniform(0.9, 1.1))[:int(0.15 * SR)]
    t = _t(0.6)
    roll = smooth(noise(rng, 0.6), 18) * np.exp(-t * 4) * np.minimum(1, t / 0.03) * 0.5
    roll *= 0.8 + 0.2 * np.sin(2 * np.pi * 23 * t)         # the joints going by
    return mix_at((0, glass(rng, vel=0.5)), (0, knock), (0.02, roll))


def marble_lost(rng):
    """Falls off into the dark: a falling whistle, then a tiny clack far below."""
    t = _t(1.0)
    whistle = sweep(1800, 500, 1.0, 1.4) * np.exp(-t * 2.2) * np.minimum(1, t / 0.05) * 0.25
    far = glass(rng, vel=0.25)
    return room(mix_at((0, whistle), (1.05, far), (1.13, glass(rng, vel=0.08))), 0.9, 0.5)


# =============================================================================
# Round 3: waves
# =============================================================================
def horn(notes, seconds):
    """Brass from Surge: notes = [(start, dur, midi, vel)]; returns mono."""
    from render import render_part
    from sounds import apply, setup_siege_lead

    def brassy(s):
        setup_siege_lead(s)
        apply(s, {"a_filter_1_cutoff": 1800.0, "a_filter_eg_sustain": 70.0})
    x = render_part(notes, brassy, seconds)
    return x.mean(axis=0)


def wave_warning(rng):
    """A war horn far away: low call rising a fifth. Enemies are coming."""
    v = int(rng.integers(95, 111))
    h = horn([(0, 0.7, 45, v), (0, 0.7, 57, v - 15), (0.75, 1.3, 52, v), (0.75, 1.3, 64, v - 15)], 2.6)
    return room(h, 0.9, 0.5)


def wave_start(rng):
    """The wave hits: war drum, boom, a brass stab, struck metal."""
    drum = inst.war_drum(70, 1.0, rng)
    stab = horn([(0, 0.35, m, 120) for m in (45, 52, 57, 60)], 1.2)
    return room(np.tanh(mix_at((0, drum), (0, inst.boom(0.8, rng)[:int(1.2 * SR)]),
                               (0.01, stab * 1.5), (0, inst.anvil(0.5)[:int(1.0 * SR)])) * 1.3), 0.6, 0.2)


def countdown_tick(rng):
    """3... 2... 1...: a deep clock tock with a low bell under it."""
    return mix_at((0, inst.tick(1500, 1.0, rng)), (0, inst.hammer(57, 0.5, rng)[:int(0.6 * SR)]))


def countdown_go(rng):
    """...GO: the same, an octave higher and brighter."""
    return mix_at((0, inst.tick(3000, 1.0, rng)), (0, inst.hammer(69, 0.7, rng)[:int(0.8 * SR)]),
                  (0, inst.hammer(76, 0.4, rng)[:int(0.8 * SR)]))


def wave_cleared(rng):
    """Phew: three bells stepping up into a warm major chord."""
    bells = mix_at((0, inst.bell(69, 0.7)), (0.16, inst.bell(73, 0.7)), (0.32, inst.bell(76, 0.9)))
    chord = horn([(0.32, 1.0, m, 70) for m in (57, 61, 64)], 2.0) * 0.6
    return room(mix_at((0, bells[:int(2.0 * SR)]), (0, chord)), 0.7, 0.3)


def boss_arrive(rng):
    """Something big: three slow war-drum hits, a deep groan, a metal shriek."""
    groan = inst.formant(inst.groan_source(2.5, 36, 4, rng), "oo").mean(axis=0) * 2.5
    shriek = inst.shriek(1.2, lo=70, rise=7, voices=6, rng=rng).mean(axis=0) * 0.5
    hits = [(i * 0.45, inst.war_drum(55, 1.0, rng)) for i in range(3)]
    return room(np.tanh(mix_at(*hits, (0.9, groan), (1.3, shriek)) * 1.4), 0.85, 0.35)


# =============================================================================
# Round 4: research
# =============================================================================
def flask_drop(rng):
    """A science flask clinks into the lab's funnel and sloshes."""
    clink = glass(rng, rng.uniform(1900, 2300), 1.0, 0.25)
    slosh = mix_at(*[(rng.uniform(0.05, 0.25), inst.bubble(rng) * rng.uniform(0.4, 0.9))
                     for _ in range(6)])
    return room(mix_at((0, clink), (0.03, glass(rng, rng.uniform(2400, 2700), 0.3, 0.1)), (0, slosh)), 0.3, 0.15)


def research_tick(rng):
    """One step of progress: a soft bubble and a tiny ping."""
    return mix_at((0, inst.bubble(rng) * 0.7), (0.03, inst.sparkle(int(rng.choice([88, 91, 93])), 0.5)[:int(0.4 * SR)]))


def research_complete(rng):
    """Eureka: glints racing up into a bright bell chord and a short 'ah'."""
    run = [(i * 0.045, inst.sparkle(m, 0.4 + 0.04 * i)[:int(0.4 * SR)])
           for i, m in enumerate([72, 74, 76, 79, 81, 84, 86, 88])]
    chord = [(0.4, inst.bell(m, 0.8)) for m in (72, 76, 79, 84)]
    voices = inst.formant(inst.choir_source([(0.4, 0.8, m, 0.8) for m in (60, 64, 67, 72)],
                                            int(2.2 * SR), 6, int(rng.integers(1e6)), attack=0.08, tail=0.5),
                          "ah").mean(axis=0) * 3
    return short(room(mix_at(*run, *chord, (0, voices)), 0.6, 0.25), 2.3)


def tech_unlock(rng):
    """A new piece unlocked: a ratchet winding, a latch clunking open, a chime."""
    clunk = mix_at((0, inst.woodblock(1.0, 0.55)[:int(0.15 * SR)]),
                   (0, modes(_t(0.3), [(950, 0.6, 30), (2300, 0.3, 45)])))
    return short(room(mix_at((0, inst.ratchet(8, 0.04, rng)), (0.34, clunk), (0.42, inst.bell(81, 0.8)),
                       (0.42, inst.bell(88, 0.4))), 0.4, 0.2), 1.8)


def flask_rejected(rng):
    """Not a flask: spat back out with a 'pff' and a sulky low boop."""
    t = _t(0.12)
    pff = smooth(noise(rng, 0.12), 3) * np.sin(np.pi * t / 0.12) * 0.6
    boop = sweep(320, 200, 0.25) * env(0.25, 0.01, 0.1) * 0.6
    return mix_at((0, pff), (0.08, boop))


# =============================================================================
# Round 5: building
# =============================================================================
def brass_click(rng, f=None, vel=1.0):
    f = f or rng.uniform(2400, 2800)
    return modes(_t(0.08), [(f, 1.0, 120), (f * 1.9, 0.4, 180)]) * vel


def place_piece(rng):
    """A wooden piece set down and snapped into its brass fitting."""
    thunk = mix_at((0, inst.woodblock(1.0, rng.uniform(0.45, 0.55))[:int(0.2 * SR)]),
                   (0, sweep(140, 80, 0.12) * env(0.12, decay=0.04)))
    return mix_at((0, thunk), (0.06, brass_click(rng)))


def remove_piece(rng):
    """Prised off: a short wooden creak, then a pop as it comes free."""
    t = _t(0.18)
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(rng.uniform(55, 70) * (1 + 0.6 * t / 0.18)) / SR))
    creak = smooth(creak, 8) * np.sin(np.pi * t / 0.18) * 0.25
    pop = inst.woodblock(0.8, rng.uniform(0.8, 0.95))[:int(0.15 * SR)]
    return mix_at((0, creak), (0.17, pop), (0.17, brass_click(rng, vel=0.5)))


def rotate_piece(rng):
    """Turned a notch: three quick brass ratchet clicks."""
    return mix_at(*[(i * 0.035, brass_click(rng, 2600 + 120 * i, 0.8 - 0.15 * i)) for i in range(3)])


def invalid_place(rng):
    """Can't build there: two dull, soft buzzes."""
    t = _t(0.09)
    buzz = np.sign(np.sin(2 * np.pi * 150 * t)) * np.sin(np.pi * t / 0.09)
    buzz = smooth(buzz, 12) * 0.5
    return mix_at((0, buzz), (0.13, buzz * 0.8))


def track_segment(rng):
    """One piece of track laid while dragging: a light wooden tick
    (the game can raise the pitch a little for each segment in a row)."""
    return mix_at((0, inst.woodblock(0.7, rng.uniform(1.2, 1.35))[:int(0.1 * SR)]),
                  (0, brass_click(rng, vel=0.25)))


# =============================================================================
# Round 6: menus
# =============================================================================
def ui_hover(rng):
    """Mouse over a button: the faintest brass tick."""
    return brass_click(rng, rng.uniform(3800, 4200), 0.5)


def ui_click(rng):
    """Press a brass button: a firm click with a small wooden body."""
    return mix_at((0, brass_click(rng)), (0, inst.woodblock(0.5, 1.6)[:int(0.06 * SR)]))


def ui_open(rng):
    """A brass panel slides open: a short rising swish and a soft chime."""
    t = _t(0.18)
    swish = smooth(noise(rng, 0.18), 4) * np.sin(np.pi * t / 0.18) ** 2 * 0.4
    rise = sweep(600, 1200, 0.18) * np.sin(np.pi * t / 0.18) * 0.15
    return short(mix_at((0, swish), (0, rise), (0.14, inst.bell(84, 0.5))), 0.9)


def ui_close(rng):
    """It slides shut: a falling swish and a soft wooden stop."""
    t = _t(0.16)
    swish = smooth(noise(rng, 0.16), 6) * np.sin(np.pi * t / 0.16) ** 2 * 0.4
    fall = sweep(900, 450, 0.16) * np.sin(np.pi * t / 0.16) * 0.15
    return mix_at((0, swish), (0, fall), (0.13, inst.woodblock(0.6, 0.9)[:int(0.12 * SR)]))


def lever_on(rng):
    """Flip a lever up: two clicks rising in pitch."""
    return mix_at((0, brass_click(rng, 2200, 0.7)), (0.05, brass_click(rng, 3100, 1.0)))


def lever_off(rng):
    """Flip it down: two clicks falling."""
    return mix_at((0, brass_click(rng, 3100, 0.7)), (0.05, brass_click(rng, 2200, 1.0)))


def ui_error(rng):
    """A gentle 'no': two soft low notes stepping down."""
    a = sweep(392, 392, 0.12) * env(0.12, 0.005, 0.05)
    b = sweep(330, 330, 0.18) * env(0.18, 0.005, 0.07)
    return mix_at((0, a * 0.6), (0.11, b * 0.6))


# =============================================================================
# Round 7: smelting
# =============================================================================
def ore_into_furnace(rng):
    """Ore hits the fire: a soft 'whumph' of flame and a sizzle."""
    t = _t(0.5)
    whumph = smooth(noise(rng, 0.5), 40) * np.minimum(1, t / 0.03) * np.exp(-t * 7) * 1.2
    sizzle = inst.hiss(0.5, rng) * 0.5
    crack = inst.crackle(0.5, 30, rng) * 0.6
    return mix_at((0, whumph), (0.02, sizzle), (0, crack))


def ingot_done(rng):
    """An ingot comes off the grate: a bright metal ding and a short hiss."""
    return short(mix_at((0, inst.hammer(int(rng.choice([76, 79])), 0.8, rng)),
                        (0.03, inst.hiss(0.4, rng) * 0.4)), 0.9)


def crucible_pour(rng):
    """Molten metal pouring: thick bubbling, then a rising sizzle as it lands."""
    blorps = [(rng.uniform(0, 0.9), inst.magma(rng) * rng.uniform(0.5, 1)) for _ in range(9)]
    t = _t(1.2)
    stream = smooth(noise(rng, 1.2), 30) * np.sin(np.pi * t / 1.2) * 0.4
    return room(mix_at(*blorps, (0, stream), (0.5, inst.hiss(1.0, rng) * 0.5)), 0.3, 0.15)


def stamp_press(rng):
    """A heavy stamp: clank down, a deep thud, then the steam lets go."""
    clank = modes(_t(0.4), [(rng.uniform(380, 420), 1.0, 12), (1020, 0.5, 18), (1730, 0.3, 25)])
    thud = sweep(110, 45, 0.3) * env(0.3, decay=0.08)
    return room(np.tanh(mix_at((0, clank * 0.6), (0, thud), (0.2, inst.hiss(0.6, rng) * 0.4)) * 1.4),
                0.3, 0.15)


def crusher_crunch(rng):
    """Rock crushed between rollers: gritty crunches in quick succession."""
    parts = []
    at = 0
    for i in range(rng.integers(5, 8)):
        d = rng.uniform(0.03, 0.07)
        grit = smooth(noise(rng, d), int(rng.integers(2, 6))) * env(d, decay=d / 2)
        parts.append((at, grit * rng.uniform(0.5, 1.0)))
        at += rng.uniform(0.04, 0.09)
    parts.append((0, sweep(80, 60, at + 0.1) * env(at + 0.1, decay=0.15) * 0.4))
    return mix_at(*parts)


# =============================================================================
# Round 8: enemies (all clockwork)
# =============================================================================
def loopable(x, seconds):
    """Cut to exactly `seconds` and blend the end into the start so it repeats
    without a click."""
    n, f = int(seconds * SR), int(0.05 * SR)
    x = np.pad(x, (0, max(0, n + f - len(x))))
    out = x[:n].copy()
    ramp = np.linspace(0, 1, f)
    out[:f] = out[:f] * ramp + x[n:n + f] * (1 - ramp)
    return out


def crawler_skitter(rng):
    """Clockwork spider legs scuttling over rock (repeats seamlessly, 0.8 s)."""
    parts, at = [], 0.0
    while at < 0.85:
        parts.append((at, inst.tick(rng.uniform(1800, 3200), rng.uniform(0.3, 0.8), rng)))
        at += rng.uniform(0.025, 0.06)
    return loopable(mix_at(*parts), 0.8)


def gremlin_unscrew(rng):
    """A gremlin at your machine: a wrench ratcheting and a squeaky little snigger."""
    wrench = inst.ratchet(10, 0.05, rng)
    snig = []
    for i in range(3):
        f0 = rng.uniform(900, 1100) * (1 + 0.15 * i)
        squeak = sweep(f0, f0 * 1.3, 0.07) * env(0.07, 0.005, 0.03)
        snig.append((0.6 + i * 0.09, squeak * 0.5))
    return mix_at((0, wrench), *snig)


def mite_swarm(rng):
    """A swarm of rivet-sized clockwork ticks seeping through the rock (loops, 1 s)."""
    parts = [(rng.uniform(0, 1.05), inst.tick(rng.uniform(4000, 6500), rng.uniform(0.1, 0.4), rng))
             for _ in range(90)]
    return loopable(mix_at(*parts), 1.0)


def drill_burrow(rng):
    """A brass drill-mole boring through rock: whine plus grinding rumble (loops, 1.5 s)."""
    t = _t(1.6)
    whine = np.sin(2 * np.pi * np.cumsum(900 + 40 * np.sin(2 * np.pi * 3 * t)) / SR) * 0.15
    whine += np.sin(2 * np.pi * np.cumsum(1810 + 60 * np.sin(2 * np.pi * 3 * t)) / SR) * 0.06
    grind = smooth(noise(rng, 1.6), 20) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 11 * t))) * 0.6
    return loopable(whine + grind, 1.5)


def magpie_snatch(rng):
    """A clockwork magpie swoops: wingbeats and a tinny 'kraa'."""
    flaps = []
    for i in range(3):
        d = 0.08
        t = _t(d)
        flaps.append((i * 0.12, smooth(noise(rng, d), 10) * np.sin(np.pi * t / d) * 0.6))
    t = _t(0.22)
    f = rng.uniform(600, 700) * (1 - 0.2 * t / 0.22)
    caw = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.sin(np.pi * t / 0.22)
    caw = inst.formant(np.vstack([caw, caw]), "ah").mean(axis=0) * 1.5
    return mix_at(*flaps, (0.38, caw), (0.38, brass_click(rng, vel=0.3)))


def dreadnought_engine(rng):
    """The flying fortress overhead: deep thrumming propellers and a chugging
    engine (loops, 2 s)."""
    t = _t(2.1)
    thrum = np.sin(2 * np.pi * 48 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * t))
    chug = smooth(noise(rng, 2.1), 60) * (np.sin(2 * np.pi * 3 * t) > 0.3) * 0.8
    rattle = smooth(noise(rng, 2.1), 4) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * t))
    return loopable(np.tanh((thrum + smooth(chug, 200) + rattle) * 1.2), 2.0)


def wyrm_roar(rng):
    """The magma wyrm rears up: a huge grinding groan through bellows."""
    groan = inst.formant(inst.groan_source(2.0, 43, 7, rng), "ah").mean(axis=0) * 3
    t = _t(2.0)
    roar = smooth(noise(rng, 2.0), 15) * np.sin(np.pi * t / 2.0) ** 0.7 * 0.5
    gears = mix_at(*[(i * 0.07, inst.tick(rng.uniform(700, 1100), 0.4, rng)) for i in range(25)])
    return room(np.tanh(mix_at((0, groan), (0, roar), (0.1, gears)) * 1.5), 0.7, 0.3)


# =============================================================================
# Round 9: defences
# =============================================================================
def cannon_fire(rng):
    """Cannon: a sharp crack, a deep boom, and the barrel ringing."""
    crack = (noise(rng, 0.04) - smooth(noise(rng, 0.04), 3)) * env(0.04, decay=0.01) * 1.5
    boom = sweep(120, 40, 0.6) * env(0.6, decay=0.15)
    body = smooth(noise(rng, 0.5), 25) * env(0.5, decay=0.1)
    ring = modes(_t(0.6), [(rng.uniform(560, 620), 0.15, 8), (1430, 0.08, 12)])
    return room(np.tanh(mix_at((0, crack), (0, boom), (0, body), (0.01, ring)) * 2), 0.5, 0.2)


def mortar_launch(rng):
    """Mortar: a hollow 'thoomp' and the shell whistling up."""
    thoomp = sweep(200, 70, 0.2) * env(0.2, 0.002, 0.06)
    pop = smooth(noise(rng, 0.1), 15) * env(0.1, decay=0.03)
    t = _t(0.9)
    whistle = sweep(1200, 2200, 0.9, 0.6) * np.minimum(1, t / 0.1) * np.exp(-t * 3) * 0.12
    return mix_at((0, thoomp), (0, pop), (0.1, whistle))


def shell_impact(rng):
    """The shell lands: an explosion with rocks raining down."""
    blast = smooth(noise(rng, 0.8), 8) * env(0.8, 0.002, 0.12)
    low = sweep(90, 30, 0.8) * env(0.8, decay=0.2)
    debris = [(rng.uniform(0.15, 0.7), inst.woodblock(rng.uniform(0.1, 0.3), rng.uniform(0.6, 1.4))[:int(0.08 * SR)])
              for _ in range(8)]
    return room(np.tanh(mix_at((0, blast), (0, low), *debris) * 2.2), 0.6, 0.25)


def trap_snap(rng):
    """A spring trap fires: a sproing and a metal jaw clacking shut."""
    t = _t(0.35)
    f = 220 * (1 + 0.08 * np.sin(2 * np.pi * 28 * t) * np.exp(-t * 9))
    sproing = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.5
    jaw = modes(_t(0.2), [(rng.uniform(1700, 1900), 1.0, 40), (3300, 0.5, 60)])
    return mix_at((0, jaw), (0, sproing))


def tesla_zap(rng):
    """Tesla coil: a crackling electric zap."""
    d = rng.uniform(0.25, 0.35)
    t = _t(d)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.25
    arcs = (noise(rng, d) - smooth(noise(rng, d), 2)) * (rng.uniform(0, 1, t.size) > 0.7) * 0.8
    return np.tanh((buzz + arcs) * np.minimum(1, t / 0.005) * np.exp(-t * 6) * 2)


def harpoon_fire(rng):
    """Harpoon winch: a heavy twang and the chain rattling out."""
    t = _t(0.4)
    twang = sweep(180, 140, 0.4) * np.exp(-t * 8) * 0.8
    chain = mix_at(*[(0.03 + i * 0.022, brass_click(rng, rng.uniform(1800, 2600), 0.5 * 0.93 ** i))
                     for i in range(20)])
    return mix_at((0, twang), (0, chain))


def catapult_release(rng):
    """A catapult arm lets go: wood creak, a whoosh, a thud as the arm stops."""
    t = _t(0.15)
    creak = smooth(np.sign(np.sin(2 * np.pi * np.cumsum(60 + 30 * t / 0.15) / SR)), 10) * np.sin(np.pi * t / 0.15) * 0.25
    t2 = _t(0.3)
    whoosh = smooth(noise(rng, 0.3), 8) * np.sin(np.pi * t2 / 0.3) ** 2 * 0.5
    stop = inst.woodblock(1.0, 0.5)[:int(0.2 * SR)]
    return mix_at((0, creak), (0.12, whoosh), (0.38, stop))


def barricade_hit(rng):
    """An enemy batters a barricade: wood thump and a splintery crack."""
    thump = mix_at((0, inst.woodblock(1.0, rng.uniform(0.4, 0.5))[:int(0.2 * SR)]),
                   (0, sweep(120, 70, 0.15) * env(0.15, decay=0.05)))
    crack = (noise(rng, 0.03) - smooth(noise(rng, 0.03), 3)) * env(0.03, decay=0.008) * 0.6
    return mix_at((0, thump), (0.01, crack))


# =============================================================================
# Round 10: rewards and progress
# =============================================================================
def pickup_ore(rng):
    """Grab a piece of ore: a clink and a tiny rising ping."""
    return mix_at((0, glass(rng, rng.uniform(1800, 2200), 0.6, 0.1)),
                  (0.04, inst.sparkle(int(rng.choice([84, 86, 88])), 0.5)[:int(0.3 * SR)]))


def pickup_rare(rng):
    """Found something rare: a shimmer and two chimes stepping up."""
    t = _t(0.5)
    shimmer = sum(np.sin(2 * np.pi * f * t) for f in (2637, 3136, 3951)) * np.sin(np.pi * t / 0.5) * 0.05
    return short(mix_at((0, shimmer), (0.05, inst.bell(81, 0.7)), (0.2, inst.bell(88, 0.8))), 1.3)


def milestone(rng):
    """A milestone: a quick music-box flourish up an A major chord."""
    notes = [(i * 0.09, inst.bell(m, 0.6 + 0.08 * i)) for i, m in enumerate([69, 73, 76, 81])]
    return short(room(mix_at(*notes, (0.27, inst.bell(85, 0.5))), 0.5, 0.2), 1.8)


def game_saved(rng):
    """Saved: a tick-tock and a soft low chime."""
    return short(mix_at((0, inst.tick(3300, 0.6, rng)), (0.18, inst.tick(2100, 0.6, rng)),
                        (0.36, inst.bell(69, 0.5))), 1.2)


def new_area(rng):
    """Discovered a new cave: a bowed-metal swell and a low 'oh' chord."""
    metal = inst.bowed_metal(inst.hz(57), 2.5, rng)
    voices = inst.formant(inst.choir_source([(0.2, 1.6, m, 0.8) for m in (45, 52, 57, 60)],
                                            int(3 * SR), 6, int(rng.integers(1e6)), attack=0.5, tail=0.7),
                          "oh").mean(axis=0) * 2
    return room(mix_at((0, metal), (0, voices)), 0.85, 0.35)


def game_start(rng):
    """Start a game from the title: a big gear clunks into place, the beam
    shimmers up, a deep boom."""
    clunk = mix_at((0, inst.woodblock(1.0, 0.4)[:int(0.2 * SR)]),
                   (0, modes(_t(0.4), [(380, 0.7, 15), (950, 0.4, 25)])))
    t = _t(1.0)
    rise = sweep(300, 1500, 1.0, 0.6) * np.sin(np.pi * t / 1.0) ** 2 * 0.3
    return room(np.tanh(mix_at((0, inst.ratchet(6, 0.04, rng)), (0.22, clunk), (0.25, rise),
                               (1.1, inst.boom(0.8, rng)[:int(1.5 * SR)])) * 1.3), 0.6, 0.25)


ROUNDS = {
    "damage": [player_hurt, dome_hit, piece_break, low_health],
    "rewards": [pickup_ore, pickup_rare, milestone, game_saved, new_area, game_start],
    "defences": [cannon_fire, mortar_launch, shell_impact, trap_snap, tesla_zap, harpoon_fire,
                 catapult_release, barricade_hit],
    "enemies": [crawler_skitter, gremlin_unscrew, mite_swarm, drill_burrow, magpie_snatch,
                dreadnought_engine, wyrm_roar],
    "smelting": [ore_into_furnace, ingot_done, crucible_pour, stamp_press, crusher_crunch],
    "menus": [ui_hover, ui_click, ui_open, ui_close, lever_on, lever_off, ui_error],
    "building": [place_piece, remove_piece, rotate_piece, invalid_place, track_segment],
    "research": [flask_drop, research_tick, research_complete, tech_unlock, flask_rejected],
    "waves": [wave_warning, wave_start, countdown_tick, countdown_go, wave_cleared, boss_arrive],
    "marbles": [marble_click, marble_cup, marble_lift, marble_fling, marble_land, marble_lost],
}
PEAKS = {"low_health": -8, "player_hurt": -2, "dome_hit": -1,
         "marble_click": -9, "marble_land": -7, "marble_fling": -8,
         "countdown_tick": -6, "countdown_go": -4, "wave_cleared": -4,
         "research_tick": -10, "flask_drop": -6, "flask_rejected": -7,
         "place_piece": -5, "remove_piece": -6, "rotate_piece": -9, "invalid_place": -8,
         "track_segment": -10,
         "ui_hover": -18, "ui_click": -10, "ui_open": -10, "ui_close": -10, "lever_on": -10,
         "lever_off": -10, "ui_error": -9,
         "ore_into_furnace": -6, "ingot_done": -6, "crusher_crunch": -5,
         "crawler_skitter": -9, "mite_swarm": -10, "drill_burrow": -7, "gremlin_unscrew": -6,
         "magpie_snatch": -6, "dreadnought_engine": -4,
         "cannon_fire": -1, "shell_impact": -1, "mortar_launch": -4, "trap_snap": -5,
         "tesla_zap": -7, "harpoon_fire": -5, "catapult_release": -5, "barricade_hit": -5,
         "pickup_ore": -9, "pickup_rare": -5, "milestone": -4, "game_saved": -9, "new_area": -4}   # default -3 dB


def lengths(name):
    """Print how long each take is: game sounds should be short."""
    for f in sorted(OUT.glob("*.wav")):
        if any(f.stem.startswith(fx.__name__) for fx in ROUNDS[name]):
            with AudioFile(str(f)) as a:
                print(f"    {f.stem:22} {a.frames / SR:.2f}s")


def main():
    name = sys.argv[1]
    OUT.mkdir(exist_ok=True)
    gap_variant, gap_effect = 0.35, 1.2
    preview, at, order = [], 0.0, []
    for i, fx in enumerate(ROUNDS[name]):
        order.append((at, fx.__name__))
        for v in range(VARIANTS):
            x = finish(fx(np.random.default_rng(1000 * i + v)), PEAKS.get(fx.__name__, -3),
                       loop=fx.__name__ in LOOPS)
            with AudioFile(str(OUT / f"{fx.__name__}_{v + 1}.wav"), "w", SR, 2) as f:
                f.write(x)
            preview.append((at, x))
            at += x.shape[1] / SR + gap_variant
        at += gap_effect - gap_variant
    buf = np.zeros((2, int((at + 0.5) * SR)), np.float32)
    for s, x in preview:
        i = int(s * SR)
        buf[:, i:i + x.shape[1]] += x
    mp3 = export(buf, f"sfx_{name}")
    for s, fx in order:
        print(f"  {int(s // 60)}:{s % 60:04.1f}  {fx}")
    print(f"{mp3}  {at:.1f}s  peak={np.abs(buf).max():.2f}")
    lengths(name)


if __name__ == "__main__":
    main()
