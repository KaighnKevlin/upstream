"""Seesaw: a timber plank with brass end caps on a riveted brass fulcrum.

    python3 tools/art/gen_seesaw.py [preview_dir]

Writes assets/sprites/seesaw_plank.png (76x16, centred on the pivot at
(38, 11); the plank's top surface is at y 8, raised caps at the ends) and seesaw_base.png (28x20,
feet at the bottom centre (14, 19); the pivot is at (0, -16) from the feet).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [(41, 38, 31), (75, 54, 43), (99, 76, 54), (134, 97, 60), (168, 143, 103)]
EXTRA = ['4b362b', '634c36', '86613c', 'a88f67']


def plank():
    fig = Figure()
    fig.box((-33, -3, 33, 3), WOOD, z=0, bevel=1.0, grit=0.12)
    for x in range(-28, 30, 8):
        fig.capsule((x, -2.4), (x, 2.4), 0.25, [(60, 44, 34)] * 2, z=0.1)   # board joints
    for x in (-34, 34):
        fig.box((x - 2.5, -9.5, x + 2.5, 3.6), BRONZE, z=0.5, bevel=0.8)   # raised end caps
    fig.disc((0, 0), 3.0, STEEL, z=1)
    fig.sphere((0, 0), 1.3, BRONZE, z=1.1)
    return fig.render(76, 16, (38, 11), extra=EXTRA)


def base():
    fig = Figure()
    fig.poly([(-12, 0), (12, 0), (3, -16), (-3, -16)], BRONZE, z=0, shade=0.75)
    fig.poly([(-8, -1), (8, -1), (2, -12), (-2, -12)], DARK, z=0.1, shade=0.4)
    for x in (-8, 8):
        fig.sphere((x, -2.5), 0.7, STEEL, z=0.2)
    fig.box((-13, -2.5, 13, 0), STEEL, z=0.3, bevel=0.6)
    fig.disc((0, -16), 3.4, BRONZE, z=0.4)
    return fig.render(28, 20, (14, 19), extra=EXTRA)


def main():
    write_png(SPR + 'seesaw_plank.png', 76, 16, plank())
    write_png(SPR + 'seesaw_base.png', 28, 20, base())
    print('wrote seesaw_plank.png, seesaw_base.png')
    if len(sys.argv) > 1:
        big = side_by_side([plank(), base()], 6)
        write_png(sys.argv[1] + '/seesaw_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
