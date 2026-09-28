"""Tipping bucket: an open brass cup (back wall, floor, pouring lip; the
inside left clear so the marbles in it show) with steel rim bands and the
steel pivot boss at its back corner, and the post it pivots on.

    python3 tools/art/gen_tipping_bucket.py [preview_dir]

Writes (drawn pouring right; the code mirrors both for side -1):
- tipping_bucket.png  38x34, the pivot (the cup's bottom back corner) at
  (4, 28): the cup's floor runs x 0..30 on the pivot's row, its walls up to
  y -24. The code rotates it about the pivot by the tip angle.
- tipping_bucket_post.png  14x20, the pivot at (7, 2); the foot on the row
  +14 below it.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def cup():
    fig = Figure()
    fig.box((-1.8, -24, 1.4, 1.8), BRONZE, z=1, bevel=0.8)               # back wall
    fig.box((28.6, -24, 31.8, 1.8), BRONZE, z=1, bevel=0.8)              # pouring lip
    fig.box((-1.8, -1, 31.8, 2.2), BRONZE, z=1.1, bevel=0.8)             # floor
    for x0, x1 in ((-2.4, 2.0), (28.0, 32.4)):
        fig.box((x0, -25.5, x1, -22.5), STEEL, z=1.3, bevel=0.6)         # rim bands
        fig.box((x0, -12.5, x1, -10.5), STEEL, z=1.3, bevel=0.5)
    for x in (8, 15, 22):
        fig.sphere((x, 0.6), 0.55, STEEL, z=1.2)                        # floor rivets
    fig.disc((0, 0), 3.0, STEEL, z=2)                                    # pivot boss
    fig.sphere((0, 0), 1.2, BRONZE, z=2.1)
    return fig.render(38, 34, (4, 28))


def post():
    fig = Figure()
    fig.box((-1.5, 0, 1.5, 13), BRONZE, z=0, bevel=0.7)
    fig.box((-2.1, 5.2, 2.1, 6.8), STEEL, z=0.1, bevel=0.4)
    fig.box((-5.5, 12.5, 5.5, 15), STEEL, z=0.2, bevel=0.6)
    for x in (-3.8, 3.8):
        fig.sphere((x, 13.7), 0.5, BRONZE, z=0.3)
    return fig.render(14, 20, (7, 2))


def main():
    c, p = cup(), post()
    write_png(SPR + 'tipping_bucket.png', 38, 34, c)
    write_png(SPR + 'tipping_bucket_post.png', 14, 20, p)
    print('wrote tipping_bucket.png, tipping_bucket_post.png')
    if len(sys.argv) > 1:
        big = side_by_side([c, p], 8)
        write_png(sys.argv[1] + '/tipping_bucket_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
