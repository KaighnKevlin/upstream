"""Sprites for the older Marble Works lifts: the stair lift, the ferris
lift and the Archimedes screw.

    python3 tools/art/gen_lifts.py [preview_dir]

Stair lift (the code tiles/poses these per step):
- stair_block.png  18x8, a brass step block, its centre at (9, 4) (the
  block is 16x6 about it); drawn tilted by TILT about that centre.
- stair_post.png   4x8 tile, repeats in y: the steel stem under a block.
- stair_base.png   16x6 tile, repeats in x: the iron base rail, its
  centre line on row 2.
Ferris lift:
- ferris_stand.png 64x86, the hub at (32, 6): oak A-frame legs to
  (+-26, 78), a cross brace and foot plates.
- ferris_rim.png   124x124, the hub at (62, 62): the brass rim, radius 56
  (round, so it stays put and crisp).
- ferris_spokes.png 124x124, the hub at (62, 62): 8 spokes starting along
  +x (the code turns it by the wheel's angle) and the steel hub.
- ferris_cup.png   18x14, the hanging pin at (9, 10): an open brass cup
  (walls from (+-7, -8) to (+-6, 2), a floor on row 2) that stays level.
Archimedes screw (tiled along the tube, turned to its slope; local x runs
from the mouth up the tube, local y across it):
- screw_wall.png   16x4 tile, a brass tube wall; its centre on row 2.
- screw_flight.png 10x20 tile, one flight of the helix: a steel blade from
  (0, 8) to (4, -8) about row 10; the code scrolls it as the screw turns.
- screw_collar.png 8x26, a steel-banded brass collar across the tube, its
  centre at (4, 13); drawn at the mouth and the top.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:5]


def stair_block():
    fig = Figure()
    fig.box((-8, -3, 8, 3), BRONZE, z=0, bevel=1.0)
    fig.box((-8, -3.2, 8, -1.6), BRONZE[2:], z=0.1, bevel=0.5)      # a bright top edge (the tread)
    for x in (-5, 5):
        fig.sphere((x, 1), 0.55, STEEL, z=0.2)
    return fig.render(18, 8, (9, 4))


def stair_post():
    fig = Figure()
    fig.box((-1.1, -6, 1.1, 14), IRON, z=0, bevel=0.6, grit=0.02)
    return fig.render(4, 8, (2, 0), outline=False)


def stair_base():
    fig = Figure()
    fig.box((-4, -1.8, 20, 1.8), IRON, z=0, bevel=0.6, grit=0.03)
    fig.sphere((8, 0), 0.6, BRONZE, z=0.1)
    return fig.render(16, 6, (0, 2))


def ferris_stand():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((0, 0), (s * 26, 77), 1.8, OAK, z=0)
        fig.box((s * 26 - 4, 76, s * 26 + 4, 79.5), IRON, z=0.1, bevel=0.6)
    fig.capsule((-14, 42), (14, 42), 1.0, OAK, z=-0.1)
    fig.disc((0, 0), 4, IRON, z=0.2)
    return fig.render(64, 86, (32, 6), extra=OAK_EXTRA)


def ferris_rim():
    # the rim doesn't turn (it's round): a static sprite stays crisp
    fig = Figure()
    R = 56
    n = 80
    pts = [(math.cos(2 * math.pi * k / n) * R, math.sin(2 * math.pi * k / n) * R) for k in range(n + 1)]
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 1.6, BRONZE, z=0.3)
    inner = [(x * 0.9, y * 0.9) for x, y in pts]
    for p, q in zip(inner, inner[1:]):
        fig.capsule(p, q, 0.5, BRONZE[:5], z=0.1)
    return fig.render(124, 124, (62, 62))


def ferris_spokes():
    fig = Figure()
    R = 56
    for k in range(8):
        a = 2 * math.pi * k / 8
        fig.capsule((math.cos(a) * 6, math.sin(a) * 6), (math.cos(a) * (R - 1), math.sin(a) * (R - 1)), 0.9, BRONZE, z=0.2)
    fig.disc((0, 0), 7, BRONZE, z=0.5)
    fig.disc((0, 0), 4.2, STEEL, z=0.6)
    fig.sphere((0, 0), 1.6, DARK, z=0.7)
    return fig.render(124, 124, (62, 62))


def ferris_cup():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 7, -8), (s * 6, 2), 0.9, BRONZE, z=0)
    fig.capsule((-6, 2), (6, 2), 1.0, BRONZE, z=0.1)
    fig.capsule((-6.6, -3), (6.6, -3), 0.35, STEEL, z=-0.1)       # a thin hoop behind the load
    fig.capsule((0, 2), (0, 0), 0.6, STEEL, z=0.2)                # the hanger to the pin
    fig.sphere((0, 0), 1.0, STEEL, z=0.3)
    return fig.render(18, 14, (9, 10))


def screw_wall():
    fig = Figure()
    fig.box((-4, -1.1, 20, 1.1), BRONZE, z=0, bevel=0.5, grit=0.03)
    fig.sphere((8, 0), 0.5, STEEL, z=0.1)
    return fig.render(16, 4, (0, 2), outline=False)


def screw_flight():
    fig = Figure()
    for dx in (-10, 0, 10):          # neighbours too, so the tile wraps cleanly
        fig.capsule((dx + 0, 8), (dx + 4, -8), 0.55, STEEL[2:], z=0)
    return fig.render(10, 20, (0, 10), outline=False)


def screw_collar():
    fig = Figure()
    fig.box((-2.6, -11.5, 2.6, 11.5), BRONZE, z=0, bevel=0.9)
    fig.box((-2.8, -12, 2.8, -10), STEEL, z=0.1, bevel=0.5)
    fig.box((-2.8, 10, 2.8, 12), STEEL, z=0.1, bevel=0.5)
    fig.sphere((0, 0), 0.6, STEEL, z=0.2)
    return fig.render(8, 26, (4, 13))


def main():
    out = {
        'stair_block': stair_block(), 'stair_post': stair_post(), 'stair_base': stair_base(),
        'ferris_stand': ferris_stand(), 'ferris_rim': ferris_rim(), 'ferris_spokes': ferris_spokes(), 'ferris_cup': ferris_cup(),
        'screw_wall': screw_wall(), 'screw_flight': screw_flight(), 'screw_collar': screw_collar(),
    }
    for k, img in out.items():
        write_png(SPR + k + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(k + '.png' for k in out))
    if len(sys.argv) > 1:
        big = side_by_side(list(out.values()), 3)
        write_png(sys.argv[1] + '/lifts_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
