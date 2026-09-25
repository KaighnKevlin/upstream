"""Harpoon ballista: a heavy crossbow on a brass turntable, with a rope winch
drum on the base and an ammo hopper on its side.

    python3 tools/art/gen_harpoon.py [preview_dir]

Writes assets/sprites/harpoon_base.png (48x40, feet at the bottom centre
(24, 39); the turntable pivot is at (0, -24) from the feet; the hopper mouth
spans x -22..-12 at y -30) and harpoon_bow.png (40x24, pivot at (10, 12),
pointing right: stock, steel bow arms, the loaded harpoon's barbed head).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [(41, 38, 31), (75, 54, 43), (99, 76, 54), (134, 97, 60), (168, 143, 103)]
ROPE = [(60, 50, 36), (120, 100, 70), (170, 150, 110)]
EXTRA = ['4b362b', '634c36', '86613c', 'a88f67', '3c3224', '786446', 'aa9670']


def base():
    fig = Figure()
    for x in (-15, 15):
        fig.ellipsoid((x, -1.5), (3.5, 1.5), BRONZE, z=0)
    fig.box((-18, -14, 18, -3), WOOD, z=1, bevel=1.5, grit=0.12)
    fig.box((-19, -15, 19, -12), BRONZE, z=1.1, bevel=0.8)
    # rope winch drum
    fig.ellipsoid((6, -8), (7, 4.5), ROPE, z=1.2, grit=0.1)
    for x in (0, 3, 6, 9, 12):
        fig.capsule((x, -12), (x + 1.5, -4), 0.4, [(40, 34, 26)] * 2, z=1.3)
    fig.disc((13.5, -8), 2.2, STEEL, z=1.4)
    # turntable post
    fig.box((-5, -24, 5, -14), STEEL, z=1.5, bevel=1.2)
    fig.ellipsoid((0, -24), (9, 2.4), BRONZE, z=1.6)
    # ammo hopper on the left
    fig.poly([(-22, -30), (-12, -30), (-14, -20), (-20, -20)], STEEL, z=2, shade=0.7)
    fig.poly([(-21, -29.5), (-13, -29.5), (-14.8, -21), (-19.2, -21)], DARK, z=2.05, shade=0.3)
    fig.capsule((-22.5, -30), (-11.5, -30), 0.8, BRONZE, z=2.1)
    fig.capsule((-17, -20), (-10, -16), 1.2, STEEL, z=1.9)
    return fig.render(48, 40, (24, 39), extra=EXTRA)


def bow():
    fig = Figure()
    fig.box((-8, -2.5, 20, 2.5), WOOD, z=0, bevel=1.0, grit=0.1)        # stock
    fig.capsule((-8, 0), (-10, 3), 1.5, BRONZE, z=0.1)
    # bow arms swept back, and the string
    for s in (-1, 1):
        fig.capsule((12, 0), (6, s * 10), 1.3, STEEL, z=0.5)
        fig.capsule((6, s * 10), (-2, 0), 0.35, ROPE, z=0.4)
    fig.sphere((12, 0), 2.0, BRONZE, z=0.6)
    # the harpoon: shaft and barbed head
    fig.capsule((-2, 0), (24, 0), 0.8, STEEL, z=1)
    fig.poly([(24, -2.5), (29, 0), (24, 2.5)], STEEL, z=1.1, shade=0.8)
    for s in (-1, 1):
        fig.capsule((25, 0), (22, s * 3.2), 0.5, STEEL, z=1.05)
    return fig.render(40, 24, (10, 12), extra=EXTRA)


def main():
    write_png(SPR + 'harpoon_base.png', 48, 40, base())
    write_png(SPR + 'harpoon_bow.png', 40, 24, bow())
    print('wrote harpoon_base.png, harpoon_bow.png')
    if len(sys.argv) > 1:
        big = side_by_side([base(), bow()], 6)
        write_png(sys.argv[1] + '/harpoon_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
