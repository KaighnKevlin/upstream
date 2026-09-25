"""Assembler: a brass-framed steel cabinet on short legs with an intake
funnel on top, a porthole showing its works turning, a piston on the side
and an output spout. The game draws the current recipe's product on the
plate under the porthole.

    python3 tools/art/gen_assembler.py [preview_dir]

Writes assets/sprites/assembler.png: 4 frames of 48x60, feet at the bottom
centre (24, 59). Funnel mouth spans x -13..13 at y -58; the spout's mouth is
at (+22, -16); the recipe plate is centred at (0, -14).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 48, 60, (24, 59)
N = 4


def build(i):
    ph = i / N * 2 * math.pi
    fig = Figure()
    # legs
    for x in (-12, 12):
        fig.capsule((x, -6), (x, -1), 1.5, DARK, z=0)
        fig.ellipsoid((x, -0.5), (3, 1.0), BRONZE, z=0.1)
    # cabinet: steel body, brass frame
    fig.box((-15, -40, 15, -5), STEEL, z=1, bevel=2.0, grit=0.04)
    fig.box((-16, -41, 16, -38), BRONZE, z=1.2, bevel=1.0)
    fig.box((-16, -8, 16, -5), BRONZE, z=1.2, bevel=1.0)
    for x in (-15.5, 15.5):
        fig.capsule((x, -40), (x, -6), 0.9, BRONZE, z=1.3)
    for (x, y) in ((-13, -36), (13, -36), (-13, -10), (13, -10)):
        fig.sphere((x, y), 0.7, BRONZE, z=1.4)
    # porthole with the works turning inside
    fig.disc((0, -27), 7.5, BRONZE, z=2)
    fig.disc((0, -27), 6.2, DARK, z=2.1)
    fig.gear((-1.5, -26), 4.2, 9, i * 20, BRONZE, z=2.2)
    fig.gear((3.2, -30.5), 2.4, 6, -i * 33 + 15, STEEL, z=2.3)
    fig.disc((-1.5, -26), 1.0, DARK, z=2.4)
    fig.ellipsoid((-3, -30), (1.6, 0.8), [(205, 222, 232)] * 2, z=2.5, emissive=True)   # glass glint
    # recipe plate (blank: the game draws the product on it)
    fig.box((-6, -18, 6, -10), BRONZE, z=2, bevel=1.0)
    fig.box((-5, -17, 5, -11), DARK, z=2.1, bevel=0.5)
    # intake funnel on top
    fig.poly([(-13, -58), (13, -58), (5, -42), (-5, -42)], STEEL, z=3, shade=0.7)
    fig.capsule((-13.5, -58), (13.5, -58), 1.0, BRONZE, z=3.1)
    fig.poly([(-9, -56.5), (9, -56.5), (3, -44), (-3, -44)], DARK, z=3.05, shade=0.3)
    # output spout on the right
    fig.capsule((15, -16), (21, -16), 2.4, STEEL, z=1.5)
    fig.capsule((21.5, -18.5), (21.5, -13.5), 0.9, BRONZE, z=1.6)
    # piston on the left, pumping
    stroke = 3.0 * math.sin(ph)
    fig.capsule((-19, -34), (-19, -20), 1.8, DARK, z=0.9)
    fig.capsule((-19, -31 + stroke), (-19, -24 + stroke), 2.2, BRONZE, z=1.0)
    fig.capsule((-19, -24 + stroke), (-15, -22), 0.7, STEEL, z=1.05)
    return fig.render(FW, FH, O)


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'assembler.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote assembler.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/assembler_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
