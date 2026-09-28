"""Booster rail: a steel roller channel that tiles along any length, the
knurled drive roller the code moves along it, and the end cap.

    python3 tools/art/gen_booster.py [preview_dir]

Writes (drawn along the rail, rotated in code; +y is down, off the rail):
- booster_rail.png    10x12 tile, repeats along x. The rail line is row 3:
  the roller slot is rows 2-4, the channel below it to a brass flange.
- booster_roller.png  7x7, its axle at (3, 3). The code centres it 1.5 px
  above the rail line and turns it as it drives.
- booster_cap.png     6x14, the rail line's end at (3, 4).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

TILE_W, TILE_H, LINE = 10, 12, 3


def tile():
    fig = Figure()
    fig.box((-4, 0, 14, 6.5), STEEL, z=0, bevel=1.0, grit=0.04)            # the channel
    fig.poly([(-4, -0.4), (14, -0.4), (14, 1.2), (-4, 1.2)], DARK, z=0.1, shade=0.1, grit=0)   # roller slot
    fig.capsule((-4, 3.4), (14, 3.4), 0.45, STEEL[4:], z=0.15)              # a bright bead
    fig.sphere((5, 3.4), 0.6, BRONZE, z=0.2)                               # rivet, period 10
    fig.box((-4, 5.8, 14, 7.8), BRONZE, z=0.3, bevel=0.5)                   # flange
    return fig.render(TILE_W, TILE_H, (0, LINE))


def roller():
    fig = Figure()
    fig.disc((0, 0), 2.7, STEEL, z=0)
    fig.box((-2.4, -0.45, 2.4, 0.45), DARK, z=0.1, bevel=0.2, grit=0)       # a notch: shows it turn
    fig.sphere((0, 0), 1.0, BRONZE, z=0.2)
    return fig.render(7, 7, (3, 3))


def cap():
    fig = Figure()
    fig.box((-1.8, -2.5, 1.8, 8), BRONZE, z=0, bevel=0.7)
    fig.sphere((0, 0), 0.6, STEEL, z=0.1)
    fig.sphere((0, 5), 0.6, STEEL, z=0.1)
    return fig.render(6, 14, (3, 4))


def main():
    t, r, c = tile(), roller(), cap()
    write_png(SPR + 'booster_rail.png', TILE_W, TILE_H, t)
    write_png(SPR + 'booster_roller.png', 7, 7, r)
    write_png(SPR + 'booster_cap.png', 6, 14, c)
    print('wrote booster_rail.png, booster_roller.png, booster_cap.png')
    if len(sys.argv) > 1:
        tt = [sum((row for _ in range(5)), []) for row in t]
        big = side_by_side([tt, r, c], 8)
        write_png(sys.argv[1] + '/booster_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
