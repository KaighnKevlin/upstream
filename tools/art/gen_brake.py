"""Brake rail: a steel rail over a brass brush-holder channel that tiles
along any length, the bristle tuft the code stands along it (closer
together for a lower limit), and the end cap.

    python3 tools/art/gen_brake.py [preview_dir]

Writes (drawn along the rail, rotated in code; +y is down, off the rail):
- brake_rail.png   8x12 tile, repeats along x. The rail line is row 3.
- brake_tuft.png   5x9, its root on the rail line at (1, 7): stiff
  bristles standing 6 px up off the rail, leaning a touch downstream.
- brake_cap.png    6x14, the rail line's end at (3, 4).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

TILE_W, TILE_H, LINE = 8, 12, 3
BRISTLE_EXTRA = ['46301f', '7a5433', '946a42']
BRISTLE = [(42, 34, 28), (70, 48, 31), (122, 84, 51), (148, 106, 66), (199, 168, 119)]


def tile():
    fig = Figure()
    fig.box((-4, -1, 12, 1.6), STEEL, z=1, bevel=0.6, grit=0.04)            # running surface
    fig.box((-4, 1.4, 12, 6.2), BRONZE, z=0, bevel=0.9, grit=0.05)          # brush holder
    fig.capsule((-4, 2.2), (12, 2.2), 0.45, DARK, z=0.1)                    # the slot the tufts sit in
    fig.sphere((4, 4.3), 0.55, STEEL, z=0.2)                                # rivet, period 8
    fig.capsule((-4, 6), (12, 6), 0.45, DARK, z=0.1)
    return fig.render(TILE_W, TILE_H, (0, LINE))


def tuft():
    fig = Figure()
    for i, dx in enumerate((-0.8, 0, 0.8)):
        fig.capsule((dx, 0), (dx + 1.1, -6 + abs(dx) * 0.6), 0.42, BRISTLE, z=i % 2, grit=0.1)
    fig.box((-1.3, -0.8, 1.3, 0.8), DARK, z=2, bevel=0.3)                   # the ferrule
    return fig.render(5, 9, (1, 7), extra=BRISTLE_EXTRA)


def cap():
    fig = Figure()
    fig.box((-1.8, -2.5, 1.8, 7.5), BRONZE, z=0, bevel=0.7)
    fig.sphere((0, 0), 0.6, STEEL, z=0.1)
    fig.sphere((0, 4.5), 0.6, STEEL, z=0.1)
    return fig.render(6, 14, (3, 4))


def main():
    t, f, c = tile(), tuft(), cap()
    write_png(SPR + 'brake_rail.png', TILE_W, TILE_H, t)
    write_png(SPR + 'brake_tuft.png', 5, 9, f)
    write_png(SPR + 'brake_cap.png', 6, 14, c)
    print('wrote brake_rail.png, brake_tuft.png, brake_cap.png')
    if len(sys.argv) > 1:
        tt = [sum((row for _ in range(6)), []) for row in t]
        big = side_by_side([tt, f, c], 8)
        write_png(sys.argv[1] + '/brake_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
