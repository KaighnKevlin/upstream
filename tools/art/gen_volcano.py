"""Volcano: a riveted iron cone on a foot ring, brass bands, a brass-lipped
crater the pile sits in, a steam pipe with a copper valve wheel on its
flank and a dark gauge plate at its foot (the code lights the pips on it).

    python3 tools/art/gen_volcano.py [preview_dir]

Writes assets/sprites/volcano.png (62x38, the node origin, the middle of
the cup's mouth, at (31, 6)). The cone runs from half-width 17 at y -3 to
28 at y 30; the crater is the trapezoid 13 wide at y 0 to 9 at y 21; the
rim is on row -2; the gauge plate is x -14..14, y 23.5..28.5.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 62, 38, (31, 6)


def body():
    fig = Figure()
    # the cone: iron plates, stepping darker from the lit left to the right
    n = 6
    for k in range(n):
        u0, u1 = -1 + 2 * k / n, -1 + 2 * (k + 1) / n
        fig.poly([(17 * u0, -3), (17 * u1, -3), (28 * u1, 30), (28 * u0, 30)], STEEL, z=0,
                 shade=0.5 - 0.36 * k / (n - 1), grit=0.02)
        if k:
            fig.capsule((17 * u0, -2), (28 * u0, 29), 0.35, DARK, z=0.1)       # plate seams
    # brass bands, riveted
    for y in (10, 22):
        hw = 15.0 + 11.0 * (y + 1.0) / 30.0
        fig.box((-hw - 0.5, y - 1.3, hw + 0.5, y + 1.3), BRONZE, z=0.3, bevel=0.6)
        for x in range(-int(hw) + 3, int(hw) - 1, 6):
            fig.sphere((x, y), 0.5, STEEL, z=0.35)
    # the foot ring
    fig.box((-29.5, 28, 29.5, 31.5), BRONZE, z=0.4, bevel=0.8)
    # the crater: a dark, sooty throat
    fig.poly([(-13, 0), (13, 0), (9, 21), (-9, 21)], DARK, z=0.5, shade=0.35)
    fig.poly([(-11, 0), (11, 0), (7.5, 19), (-7.5, 19)], DARK, z=0.55, shade=0.12, grit=0.08)
    # the rim: a heavy brass lip, riveted
    fig.box((-19, -4.2, 19, -0.2), BRONZE, z=1, bevel=1.1)
    for x in (-15, -5, 5, 15):
        fig.sphere((x, -2.3), 0.55, STEEL, z=1.1)
    # the steam pipe and its valve wheel
    fig.capsule((18, 17), (25, 12), 1.2, BRONZE, z=0.6)
    fig.disc((26, 11), 3.2, COPPER, z=0.7)
    fig.disc((26, 11), 1.8, DARK, z=0.75)
    fig.sphere((26, 11), 0.9, COPPER, z=0.8)
    # the gauge plate (the pips are lit in code)
    fig.box((-14, 23.5, 14, 28.5), DARK, z=0.9, bevel=0.6, grit=0.03)
    return fig.render(W, H, O, extra=COPPER_EXTRA)


def main():
    b = body()
    write_png(SPR + 'volcano.png', W, H, b)
    print('wrote volcano.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/volcano_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
