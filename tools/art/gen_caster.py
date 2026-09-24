"""Clockwork tesla caster: hovering sentinel with twin coils (replaces the wizard).

    python3 tools/art/gen_caster.py [preview_dir]

Writes assets/sprites/caster_hover.png (6 frames) and caster_attack.png
(6 frames: coils charge, arc, discharge), 40x46, facing right.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH = 40, 46
ORIGIN = (18, 44)   # (0, 0) = ground under the caster
N = 6


def build(i, charge=0.0, arcs=False, fire=False):
    ph = i / N * 2 * math.pi
    bob = 1.5 * math.sin(ph)
    y0 = -18 - bob          # body centre
    fig = Figure()
    fig.ellipsoid((0, -0.8), (6.5 - bob * 0.4, 1.1), DARK, z=0, grit=0.0)          # ground shadow
    flick = 1.0 + 0.8 * abs(math.sin(ph * 3.1))
    fig.ellipsoid((0, y0 + 9 + flick), (1.8, 2.6 + flick), GLOW, z=1, emissive=True)  # thruster
    fig.ellipsoid((0, y0 + 6), (6.5, 2.3), STEEL, z=4)                              # thruster ring
    # coils (the far one first), each: rod, three bronze windings, glowing tip
    tip_r = 1.7 + 1.1 * charge
    tips = []
    for k, (bx, tx, z) in enumerate(((-4.5, -6.0, 3), (2.0, 3.0, 8))):
        base = (bx, y0 - 6); top = (tx, y0 - 15)
        fig.capsule(base, top, 1.0, STEEL, z=z)
        for w in range(3):
            t = 0.25 + w * 0.22
            fig.ellipsoid((base[0] + (top[0] - base[0]) * t, base[1] + (top[1] - base[1]) * t),
                          (1.9, 0.75), BRONZE, z=z + 0.1, grit=0.02)
        fig.sphere(top, tip_r, GLOW, z=z + 0.2, emissive=True)
        tips.append(top)
    fig.ellipsoid((0, y0), (9, 8), BRONZE, z=5)                                     # body
    fig.ellipsoid((-1, y0 - 4.5), (6, 2.5), BRONZE, z=5.5, grit=0.1)                # top plate
    fig.disc((-3.5, y0 + 0.5), 3.8, DARK, z=5.8)                                    # gear recess
    fig.gear((-3.5, y0 + 0.5), 3.3, 8, i * 20, STEEL, z=6)
    fig.disc((4.2, y0), 4.9, DARK, z=6.5)                                           # eye socket
    fig.sphere((4.8, y0), 3.7 + (1.0 if fire else 0), GLOW, z=7, emissive=True)     # core eye
    for a in (30, 150, 210, 330):                                                   # rivets
        fig.sphere((math.cos(math.radians(a)) * 7.2, y0 + math.sin(math.radians(a)) * 6.2), 0.7, STEEL, z=6)
    if arcs:
        bolt(fig, tips[0], tips[1], seed=i * 7 + 1)
        bolt(fig, tips[1], (4.8, y0 - 2), seed=i * 7 + 3, jag=1.2, segs=4)
    if fire:
        fig.sphere((10, y0), 3.2, GLOW, z=21, emissive=True)                        # muzzle flash
        bolt(fig, (8, y0 - 3), (14, y0 - 6), seed=i + 11, jag=1.0, segs=3)
        bolt(fig, (8, y0 + 3), (14, y0 + 5), seed=i + 13, jag=1.0, segs=3)
    return fig.render(FW, FH, ORIGIN)


def main():
    hover = [build(i) for i in range(N)]
    attack = [build(0, 0.2), build(1, 0.5), build(2, 0.8, arcs=True), build(3, 1.0, arcs=True),
              build(4, 1.0, arcs=True, fire=True), build(5, 0.3)]
    for name, frames in (('caster_hover', hover), ('caster_attack', attack)):
        rows = [sum((f[y] for f in frames), []) for y in range(FH)]
        write_png(SPR + name + '.png', FW * len(frames), FH, rows)
    print('wrote caster_hover.png, caster_attack.png')
    if len(sys.argv) > 1:
        big = side_by_side(hover + attack, 7)
        write_png(sys.argv[1] + '/caster_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/caster.gif', hover + hover + attack + hover, [9] * (N * 3 + 6), 8)


if __name__ == '__main__':
    main()
