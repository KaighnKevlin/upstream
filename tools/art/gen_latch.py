"""Latch: a riveted iron box with brass trim, the lever's slot and pivot boss,
an empty lamp bezel (the code lights it), a wire eye on top, and the SET and
RESET posts: steel studs on arms out of the box's feet. The brass lever is
its own sprite and swings about the pivot.

    python3 tools/art/gen_latch.py [preview_dir]

Writes latch_box.png (56x34, the node origin at (28, 14): the box x -14..14,
y -12..10, the pivot at (-7, 0), the lamp at (8, -6), the posts at (+-22, 14))
and latch_lever.png (21x9, the pivot at (4, 4), the handle pointing +x to
its knob at x 13; the code turns it -0.75..0.75 rad).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = [STEEL[0], STEEL[1], STEEL[1], STEEL[2], STEEL[2], STEEL[3], STEEL[4]]


def box():
    fig = Figure()
    # the post arms and studs, under the box
    for s in (-1, 1):
        fig.capsule((s * 11, 7), (s * 21, 13.4), 0.9, STEEL, z=0)
        fig.disc((s * 22, 14), 4.4, STEEL, z=0.2)
        fig.disc((s * 22, 14), 2.6, IRON, z=0.3)
        fig.sphere((s * 22, 14), 1.4, BRONZE, z=0.4)
    # the iron box: brass-bound, corner rivets
    fig.box((-14, -12, 14, 10), IRON, z=1, bevel=1.6, grit=0.04)
    for y in (-11.3, 9.3):
        fig.box((-14, y - 0.7, 14, y + 0.7), BRONZE, z=1.1, bevel=0.4)
    for x in (-12.4, 12.4):
        for y in (-9.3, 6.8):
            fig.sphere((x, y), 0.7, BRONZE, z=1.2)
    # the lever's slot and pivot boss
    fig.box((-8.3, -9, -5.7, 9), DARK, z=1.3, bevel=0.5, grit=0.02)
    fig.disc((-7, 0), 2.6, STEEL, z=1.4)
    # the lamp's bezel (the code lights the glass inside it)
    fig.disc((8, -6), 3.4, BRONZE, z=1.4)
    fig.disc((8, -6), 2.3, DARK, z=1.5)
    # a brass name plate under the lamp
    fig.box((3.5, 1, 12, 5.5), BRONZE, z=1.4, bevel=0.6)
    fig.capsule((5.3, 3.2), (10.2, 3.2), 0.3, DARK, z=1.5)
    # the wire eye on top
    fig.disc((0, -12.6), 1.5, BRONZE, z=1.6)
    fig.sphere((0, -12.6), 0.6, DARK, z=1.7)
    return fig.render(56, 34, (28, 14))


def lever():
    fig = Figure()
    fig.capsule((0, 0), (12, 0), 1.1, BRONZE, z=0)
    fig.sphere((13, 0), 2.6, BRONZE, z=0.2)            # the knob
    fig.disc((0, 0), 2.0, STEEL, z=0.3)                # the pivot pin
    fig.sphere((-0.3, -0.3), 0.7, STEEL, z=0.4)
    return fig.render(21, 9, (4, 4))


def main():
    b, l = box(), lever()
    write_png(SPR + 'latch_box.png', 56, 34, b)
    write_png(SPR + 'latch_lever.png', 21, 9, l)
    print('wrote latch_box.png, latch_lever.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, l], 8)
        write_png(sys.argv[1] + '/latch_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
