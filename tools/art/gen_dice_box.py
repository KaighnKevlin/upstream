"""Dice box: a riveted steel box under a brass hopper, a dark window for
the die, and brass spout bezels (the code lights the lamps in them); the
down spout is its own sprite (shown only in 3-way mode); the die is three
small ivory faces (1, 2, 3 pips) the code turns as it tumbles.

    python3 tools/art/gen_dice_box.py [preview_dir]

Writes:
- dice_box.png        36x38, the node origin at (18, 24): the hopper lip at
  y -22, the box x -12..12, y -11..8, the window (12x12) centred on (0, -3),
  side spouts at (+-14, 4).
- dice_box_down.png   10x10, the down spout, centred (5, 5) on (0, 12).
- dice_face_1..3.png  9x9, the die centred at (4, 4) (its face 7x7).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]
RED_EXTRA = ['8a2418', 'c83a26']
RED = [(138, 36, 24), (200, 58, 38)]


def spout(fig, c, z):
    fig.disc(c, 3.6, BRONZE, z=z)
    fig.disc(c, 2.4, DARK, z=z + 0.1)


def body():
    fig = Figure()
    # side spouts, under the box's edge
    for s in (-1, 1):
        fig.capsule((s * 10, 4), (s * 13, 4), 2.2, STEEL, z=0)
        spout(fig, (s * 14, 4), 0.2)
    # the hopper: brass plates to a steel throat
    fig.poly([(-13, -22), (13, -22), (6, -10), (-6, -10)], BRONZE, z=0.5, shade=0.6)
    fig.poly([(-10.5, -21), (10.5, -21), (4.8, -11.5), (-4.8, -11.5)], DARK, z=0.6, shade=0.35)
    fig.box((-14, -23.5, 14, -20.5), BRONZE, z=0.7, bevel=0.8)
    for x in (-10, 0, 10):
        fig.sphere((x, -22), 0.55, STEEL, z=0.8)
    # the box
    fig.box((-12, -11, 12, 8), STEEL, z=1, bevel=1.4, grit=0.05)
    fig.box((-12, -11, 12, -9), [STEEL[5], STEEL[6], STEEL[7]], z=1.05, bevel=0.5)   # a lit top edge
    fig.box((-12, 6.5, 12, 8.2), BRONZE, z=1.1, bevel=0.5)                           # a brass foot band
    for p in ((-9.5, -7), (9.5, -7), (-9.5, 3.5), (9.5, 3.5)):
        fig.sphere(p, 0.75, BRONZE, z=1.2)
    # the window: a brass frame round a dark well
    fig.box((-6.5, -9.5, 6.5, 3.5), BRONZE, z=1.3, bevel=0.8)
    fig.box((-5, -8, 5, 2), DARK, z=1.4, bevel=0.6, grit=0.02)
    return fig.render(36, 38, (18, 24))


def down():
    fig = Figure()
    fig.capsule((0, -4), (0, -1), 2.2, STEEL, z=0)
    spout(fig, (0, 0), 0.2)
    return fig.render(10, 10, (5, 5))


PIPS = {1: [(0, 0)], 2: [(-2, -2), (2, 2)], 3: [(-2, -2), (0, 0), (2, 2)]}


def face(n):
    fig = Figure()
    fig.box((-3.5, -3.5, 3.5, 3.5), IVORY, z=0, bevel=1.0, grit=0.03)
    for p in PIPS[n]:
        fig.box((p[0] - 0.55, p[1] - 0.55, p[0] + 0.55, p[1] + 0.55), RED, z=0.2, bevel=0.1, grit=0.0)   # one crisp pixel
    return fig.render(9, 9, (4.5, 4.5), extra=IVORY_EXTRA + RED_EXTRA)


def main():
    b, d = body(), down()
    fs = [face(n) for n in (1, 2, 3)]
    write_png(SPR + 'dice_box.png', 36, 38, b)
    write_png(SPR + 'dice_box_down.png', 10, 10, d)
    for n, f in zip((1, 2, 3), fs):
        write_png(SPR + 'dice_face_%d.png' % n, 9, 9, f)
    print('wrote dice_box.png, dice_box_down.png, dice_face_1..3.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, d] + fs, 6)
        write_png(sys.argv[1] + '/dice_box_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
