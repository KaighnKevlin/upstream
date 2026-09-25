"""Trapdoor: two hinged iron leaves skinned with turf, so from above it
looks like the ground around it. Enemies that step on it drop through.

    python3 tools/art/gen_trapdoor.py [preview_dir]

Writes assets/sprites/trapdoor_leaf.png (24x11, hinge at the left end, top
surface at y 2; flip for the right leaf) and trapdoor_frame.png (56x10: the
brass lip frame with a hinge block at each end, laid at the surface, centre
(28, 1)).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

DIRT = [(41, 38, 31), (75, 50, 38), (99, 66, 46), (122, 84, 56), (140, 100, 66)]
GRASS = [(30, 50, 30), (48, 92, 44), (72, 128, 58), (104, 160, 72)]
EXTRA = ['4b3226', '634230', '7a5438', '8c6442', '305c2c', '48803a', '68a048']


def leaf():
    fig = Figure()
    fig.box((0.5, 6, 23.5, 8.5), STEEL, z=0, bevel=0.6, grit=0.05)       # thin iron plate under the turf
    for x in (3, 12, 21):
        fig.sphere((x, 7.3), 0.5, BRONZE, z=0.2)
    fig.box((0.5, 0.5, 23.5, 6.5), DIRT, z=0.5, bevel=0.6, grit=0.25)    # thick turf skin
    for x in (4, 10, 17, 21):
        fig.sphere((x, 3.5 + (x % 3) * 0.6), 0.7, [(60, 44, 34), (80, 58, 42)], z=0.55)   # pebbles
    fig.box((0.5, 0.2, 23.5, 1.8), GRASS, z=0.6, bevel=0.4, grit=0.15)   # grass line
    for x in range(1, 24, 2):
        h = 1.2 + (x * 7 % 5) * 0.35
        fig.capsule((x, 0.8), (x + 0.4, 0.8 - h), 0.45, GRASS, z=0.7)
    fig.disc((1.5, 7.0), 1.2, BRONZE, z=0.8)                              # hinge knuckle
    return fig.render(24, 11, (0, 2), extra=EXTRA)


def frame():
    fig = Figure()
    for x in (-27, 23):
        fig.box((x, 0, x + 4, 9), BRONZE, z=0, bevel=0.8)
        fig.sphere((x + 2, 4.5), 0.8, STEEL, z=0.1)
    fig.capsule((-26, 8.5), (26, 8.5), 0.7, DARK, z=-0.5)                # stop bar below
    return fig.render(56, 10, (28, 1), extra=EXTRA)


def main():
    write_png(SPR + 'trapdoor_leaf.png', 24, 11, leaf())
    write_png(SPR + 'trapdoor_frame.png', 56, 10, frame())
    print('wrote trapdoor_leaf.png, trapdoor_frame.png')
    if len(sys.argv) > 1:
        big = side_by_side([leaf(), frame()], 8)
        write_png(sys.argv[1] + '/trapdoor_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
