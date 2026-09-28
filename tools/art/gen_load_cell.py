"""Load cell: a brass weighing pan (its dark inside showing, so what's in
it reads as in it) on a steel coil spring, over a round dial with an
ivory face and tick marks (the code draws the needle, the reading and
the wire).

    python3 tools/art/gen_load_cell.py [preview_dir]

Writes load_cell.png (34x42, the node origin at (17, 22): the pan's walls
at x +-13 from y -18 to its floor on y 0, the spring y 1..8, the dial's
centre (0, 12) radius 7).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]


def body():
    fig = Figure()
    fig.poly([(-12, -17.5), (12, -17.5), (12, -1), (-12, -1)], DARK, z=0, shade=0.25, grit=0.01)   # inside
    for s in (-1, 1):
        fig.box((s * 13 - 1.3, -18.5, s * 13 + 1.3, 1), BRONZE, z=0.5, bevel=0.7)   # walls
        fig.box((s * 13 - 1.8, -19.5, s * 13 + 1.8, -17.3), STEEL, z=0.6, bevel=0.5)  # their caps
    fig.box((-14, -1.3, 14, 1.4), BRONZE, z=0.55, bevel=0.7)                         # the floor
    for x in (-8, 0, 8):
        fig.sphere((x, 0), 0.5, STEEL, z=0.6)
    # the spring
    for k in range(4):
        y = 1.8 + k * 1.7
        fig.capsule((-2.8, y), (2.8, y + 0.85), 0.5, STEEL, z=0.3)
    # the dial
    fig.disc((0, 12), 7.2, STEEL, z=1)
    fig.disc((0, 12), 5.6, IVORY, z=1.1)
    for k in range(7):
        a = -math.pi * 0.75 + k * math.pi * 1.5 / 6 - math.pi * 0.5
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * 4.0, 12 + s * 4.0), (c * 5.0, 12 + s * 5.0), 0.3, DARK, z=1.2)
    fig.sphere((0, 12), 0.8, BRONZE, z=1.3)
    return fig.render(34, 42, (17, 22), extra=IVORY_EXTRA)


def main():
    b = body()
    write_png(SPR + 'load_cell.png', 34, 42, b)
    print('wrote load_cell.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/load_cell_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
