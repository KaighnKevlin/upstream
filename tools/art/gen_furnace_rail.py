"""Furnace rail: a cast-iron grate over a riveted firebox with vents, as a
strip that tiles along any length, and the brass end cap for both ends.

    python3 tools/art/gen_furnace_rail.py [preview_dir]

Writes (drawn along the rail, rotated in code; +y is down, off the rail):
- furnace_rail.png  16x14 tile, repeats along x. The rail line (where ore
  rolls) is row 3: the grate is rows 2-5 with slits at x 2 + 4k, the
  firebox below it with vents at x 2..6 and 10..14 on rows 7-10 (the code
  lights the slits and vents with the fire's glow).
- furnace_cap.png   6x16, the rail line's end at (3, 4): a bracket closing
  each end of the strip.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

TILE_W, TILE_H, LINE = 16, 14, 3


def tile():
    fig = Figure()
    # run the parts past both edges so the tile's sides have no outline
    fig.box((-4, -1, 20, 2), STEEL, z=1, bevel=0.7, grit=0.04)              # the grate's bars
    for x in range(-2, 20, 4):
        fig.box((x - 0.5, -0.6, x + 0.5, 1.6), DARK, z=1.1, bevel=0.2, grit=0)  # slits
    fig.poly([(-4, 2), (20, 2), (20, 9.5), (-4, 9.5)], STEEL, z=0, shade=0.2, grit=0.06)   # the firebox
    fig.capsule((-4, 2.6), (20, 2.6), 0.5, STEEL, z=0.1)                    # its top edge
    for x0 in (2, 10):
        fig.poly([(x0, 4), (x0 + 4, 4), (x0 + 4, 7.2), (x0, 7.2)], DARK, z=0.2, shade=0.0, grit=0)   # vents
    for x in (0, 8):
        fig.sphere((x, 5.5), 0.55, BRONZE, z=0.3)                           # rivets between vents
    fig.box((-4, 8.8, 20, 10.6), BRONZE, z=0.4, bevel=0.5)                   # the foot flange
    return fig.render(TILE_W, TILE_H, (0, LINE))


def cap():
    fig = Figure()
    fig.box((-1.8, -2, 1.8, 10.8), BRONZE, z=0, bevel=0.7)
    fig.sphere((0, 0.5), 0.6, STEEL, z=0.1)
    fig.sphere((0, 6.5), 0.6, STEEL, z=0.1)
    return fig.render(6, 16, (3, 4))


def main():
    t, c = tile(), cap()
    write_png(SPR + 'furnace_rail.png', TILE_W, TILE_H, t)
    write_png(SPR + 'furnace_cap.png', 6, 16, c)
    print('wrote furnace_rail.png, furnace_cap.png')
    if len(sys.argv) > 1:
        tt = [sum((row for _ in range(4)), []) for row in t]
        big = side_by_side([tt, c], 8)
        write_png(sys.argv[1] + '/furnace_rail_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
