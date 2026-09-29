"""Fuse cord: a length of tarred safety fuse that tiles along any run, the
grey ash it leaves once burnt, a tin lighting cap with a red striker head
at its start and a brass detonator cap crimped onto its end.

    python3 tools/art/gen_fuse_cord.py [preview_dir]

Writes (all drawn along the cord's direction, +x toward the end; the code
rotates them to the cord's tangent and flips them on leftward runs):
- fuse_cord.png      12x4 tile, repeats along x: the cord's centre line on
  row 2 (rows 0..3), black-brown tar with a twist every 4 px.
- fuse_cord_ash.png  12x4 tile, same run: crumbled grey ash, broken up.
- fuse_cap_start.png 10x8, the cord's start at (6, 4): a tin ferrule
  crimped over the cord (x -3..+3) and the red striker bulb behind it.
- fuse_cap_end.png   12x8, the cord's end at (2, 4): a brass detonator
  cylinder (x -1..+9) with a crimp band where the cord goes in and a dark
  charge hole in its far end.
"""
import sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

TAR_EXTRA = ['140f0c', '241a14', '3a2a1e', '54402c', '6e5838']
TAR = [_hex(h) for h in TAR_EXTRA]
ASH_EXTRA = ['3c3a38', '5e5b56', '837e76', 'a8a298']
ASH = [_hex(h) for h in ASH_EXTRA]
RED_EXTRA = ['4a1410', '8a2418', 'c83c24', 'f07a4a']
RED = [_hex(h) for h in RED_EXTRA]
EXTRA = TAR_EXTRA + ASH_EXTRA + RED_EXTRA


def cord():
    fig = Figure()
    # the cord, run past the tile's ends so it tiles seamlessly
    fig.box((-6, -1.6, 18, 1.6), TAR, z=0, bevel=1.4, grit=0.05)
    # the twist: a lit strand slanting across every 4 px
    for x in range(-4, 20, 4):
        fig.capsule((x - 0.8, 1.2), (x + 0.8, -1.2), 0.45, TAR[1:], z=0.1, grit=0.0)
    return fig.render(12, 4, (0, 2), outline=False, extra=EXTRA)


def ash():
    fig = Figure()
    # crumbled lumps with gaps between: 3 lumps in the 12 px tile
    for x, r, y in ((1.5, 1.4, 0.3), (5.5, 1.1, 0.5), (9.5, 1.3, 0.2)):
        fig.ellipsoid((x, y), (r * 1.3, r), ASH, z=0, grit=0.12)
    fig.box((-1, 0.8, 13, 1.6), ASH[:2], z=-0.1, bevel=0.4, grit=0.1)   # the dusty trail
    return fig.render(12, 4, (0, 2), outline=False, extra=EXTRA)


def cap_start():
    fig = Figure()
    fig.box((-3, -2.2, 3.5, 2.2), STEEL[1:7], z=0, bevel=1.0)            # the tin ferrule
    for x in (-1.4, 1.8):
        fig.box((x - 0.35, -2.4, x + 0.35, 2.4), STEEL[:4], z=0.1, bevel=0.3)   # crimps
    fig.sphere((-4.6, 0), 1.9, RED, z=0.2)                                 # the striker head
    return fig.render(10, 8, (6, 4), extra=EXTRA)


def cap_end():
    fig = Figure()
    fig.box((-1, -2.5, 9, 2.5), BRONZE[1:], z=0, bevel=1.3)               # the brass cylinder
    fig.box((0.6, -2.8, 1.8, 2.8), BRONZE[:5], z=0.1, bevel=0.4)          # the crimp band
    fig.box((7.8, -2.4, 9.3, 2.4), BRONZE[2:], z=0.1, bevel=0.6)          # the rolled lip
    fig.sphere((9.0, 0), 0.9, DARK, z=0.2)                                 # the charge hole
    return fig.render(12, 8, (2, 4), extra=EXTRA)


def main():
    parts = {'fuse_cord': cord(), 'fuse_cord_ash': ash(),
             'fuse_cap_start': cap_start(), 'fuse_cap_end': cap_end()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        tile = lambda t: [sum((row for _ in range(4)), []) for row in t]
        big = side_by_side([parts['fuse_cap_start'], tile(parts['fuse_cord']), parts['fuse_cap_end'],
                            tile(parts['fuse_cord_ash'])], 8)
        write_png(sys.argv[1] + '/fuse_cord_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
