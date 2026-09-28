"""Pair gate: two brass cups on a riveted steel crossbar, the joint spout
between them, and the brass medallion in the middle (the code writes the
ampersand on it and brightens it as a pair goes).

    python3 tools/art/gen_pair_gate.py [preview_dir]

Writes pair_gate.png (68x38, the node origin at (34, 20): the cups'
points at (+-22, 0), rims y -16 (+-10), floors y 2 (+-8); the spout's
walls (+-12, 4) -> (+-5, 14)) and pair_gate_plate.png (14x14, the
medallion's centre (0, -6) at (7, 7), radius 6).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def cup(fig, cx):
    fig.poly([(cx - 9.3, -15.5), (cx + 9.3, -15.5), (cx + 7.4, 1), (cx - 7.4, 1)], DARK, z=0, shade=0.25, grit=0.01)   # inside
    fig.poly([(cx - 10.5, -16), (cx - 8.8, -16), (cx - 6.8, 2), (cx - 8.5, 2)], BRONZE, z=0.5, shade=0.7)
    fig.poly([(cx + 8.8, -16), (cx + 10.5, -16), (cx + 8.5, 2), (cx + 6.8, 2)], BRONZE, z=0.5, shade=0.4)
    fig.box((cx - 9, 0.5, cx + 9, 3.5), BRONZE, z=0.6, bevel=0.8)        # the floor, a brass lip on top
    fig.box((cx - 11, -17.2, cx + 11, -14.8), STEEL, z=0.7, bevel=0.6)   # rim band
    for x in (cx - 9.5, cx + 9.5):
        fig.sphere((x, -16), 0.5, BRONZE, z=0.8)


def body():
    fig = Figure()
    fig.box((-14, 2.5, 14, 5.5), STEEL, z=-0.5, bevel=0.7)               # crossbar
    for x in (-10, 10):
        fig.sphere((x, 4), 0.55, BRONZE, z=-0.4)
    for s in (-1, 1):
        fig.capsule((s * 12, 4), (s * 5, 14), 1.5, STEEL, z=0.2)         # the spout's walls
    fig.poly([(-12, 4), (12, 4), (5, 14), (-5, 14)], DARK, z=-1, shade=0.3, grit=0.01)
    fig.box((-1.6, -2, 1.6, 3), STEEL, z=-0.3, bevel=0.6)                # the medallion's post
    cup(fig, -22)
    cup(fig, 22)
    return fig.render(68, 38, (34, 20))


def plate():
    fig = Figure()
    fig.disc((0, 0), 6.2, BRONZE, z=0)
    fig.disc((0, 0), 4.6, BRONZE[2:], z=0.1)                              # a raised field for the sign
    return fig.render(14, 14, (7, 7))


def main():
    b, p = body(), plate()
    write_png(SPR + 'pair_gate.png', 68, 38, b)
    write_png(SPR + 'pair_gate_plate.png', 14, 14, p)
    print('wrote pair_gate.png, pair_gate_plate.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, p], 8)
        write_png(sys.argv[1] + '/pair_gate_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
