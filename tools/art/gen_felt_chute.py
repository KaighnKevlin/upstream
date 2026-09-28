"""Felt chute: a steel trough lined with green baize, tacked down with
brass pins, as a strip that tiles along any length, and its end cap.

    python3 tools/art/gen_felt_chute.py [preview_dir]

Writes (drawn along the rail, rotated in code; +y is down, off the rail):
- felt_chute.png  16x10 tile, repeats along x. The rail line is row 3:
  the baize is rows 1-4, the steel trough below it with a tie per tile.
- felt_cap.png    6x12, the rail line's end at (3, 4).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

TILE_W, TILE_H, LINE = 16, 10, 3
FELT_EXTRA = ['1e3a26', '2f5b3c', '3f7a4e', '58975f']
FELT = [(30, 58, 38), (47, 91, 60), (63, 122, 78), (88, 151, 95)]


def tile():
    fig = Figure()
    fig.box((-4, -1.6, 20, 1.6), FELT, z=1, bevel=1.0, grit=0.1)            # the baize
    fig.box((-4, 1, 20, 4.6), STEEL, z=0, bevel=0.8, grit=0.04)              # the trough
    fig.box((-4, -2.2, 20, -1.2), STEEL, z=0.9, bevel=0.3)                   # the trough's lips
    for x in (4, 12):
        fig.sphere((x, 0), 0.5, BRONZE, z=1.2)                               # tacks
    fig.box((6.8, 4, 9.2, 6.5), STEEL, z=0.1, bevel=0.5)                     # a tie under it
    return fig.render(TILE_W, TILE_H, (0, LINE), extra=FELT_EXTRA)


def cap():
    fig = Figure()
    fig.box((-1.8, -2.8, 1.8, 5.5), BRONZE, z=0, bevel=0.7)
    fig.sphere((0, 0), 0.6, STEEL, z=0.1)
    fig.sphere((0, 3.5), 0.6, STEEL, z=0.1)
    return fig.render(6, 12, (3, 4))


def main():
    t, c = tile(), cap()
    write_png(SPR + 'felt_chute.png', TILE_W, TILE_H, t)
    write_png(SPR + 'felt_cap.png', 6, 12, c)
    print('wrote felt_chute.png, felt_cap.png')
    if len(sys.argv) > 1:
        tt = [sum((row for _ in range(4)), []) for row in t]
        big = side_by_side([tt, c], 8)
        write_png(sys.argv[1] + '/felt_chute_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
