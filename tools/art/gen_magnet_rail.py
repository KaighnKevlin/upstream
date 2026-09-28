"""Magnet rail: an overhead iron bar that tiles along any length, wound with
a copper coil every 24 px, a bolted end cap at each end, and the hanger up
to the ceiling.

    python3 tools/art/gen_magnet_rail.py [preview_dir]

Writes (bar and caps are drawn along the bar's direction, rotated in code
and flipped on leftward runs so the field side stays down; hangers upright):
- magrail_bar.png     24x12 tile, repeats along x: the bar's centre line on
  row 6 (iron, rows 3..8), one coil winding at x 7..14 (so coils fall 10 px
  into every 24, as the old _draw had them), reaching rows 1..10.
- magrail_cap.png     8x12, the bar end at (4, 6): an iron end block with
  two rivets, capping the tile's cut ends.
- magrail_hanger.png  9x20, the hang point on the bar at (4, 18): a steel
  rod up 16 px to a ceiling plate, a clamp round the bar at the foot.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = [STEEL[0], STEEL[1], STEEL[2], STEEL[3], STEEL[4], STEEL[5]]


def bar():
    fig = Figure()
    # the iron bar, run past the tile's ends so it tiles seamlessly: a
    # rounded bar lit along its top, shadowed underneath
    fig.box((-6, -3, 30, 3), IRON, z=0, bevel=2.2, grit=0.0)
    fig.box((-6, 2, 30, 3), DARK, z=0.05, bevel=0.3, grit=0.0)
    # the coil: three copper turns, each lit on its own, between dark collars
    fig.box((7, -4, 8, 4), DARK[2:], z=1, bevel=0.4, grit=0.0)
    fig.box((14, -4, 15, 4), DARK[2:], z=1, bevel=0.4, grit=0.0)
    for i in range(3):
        x = 8 + i * 2
        fig.box((x, -5, x + 2, 5), COPPER, z=1.1, bevel=0.9, grit=0.02)
    return fig.render(24, 12, (0, 6), outline=False, extra=COPPER_EXTRA)


def cap():
    fig = Figure()
    # an iron end block wider than the bar, a bronze rivet top and bottom
    fig.box((-2.5, -4.5, 2.5, 4.5), IRON, z=0, bevel=1.1, grit=0.03)
    for y in (-2.6, 2.6):
        fig.sphere((0, y), 0.8, BRONZE, z=0.2)
    return fig.render(8, 12, (4, 6))


def hanger():
    fig = Figure()
    fig.capsule((0, -16), (0, 0), 0.9, STEEL, z=0)                       # the rod
    fig.box((-3.5, -18, 3.5, -15.5), IRON, z=0.1, bevel=0.6)              # the ceiling plate
    for x in (-2.2, 2.2):
        fig.sphere((x, -16.8), 0.55, BRONZE, z=0.2)
    fig.box((-2, -6, 2, -3), STEEL, z=0.1, bevel=0.6)                     # the clamp over the bar
    fig.sphere((0, -4.5), 0.6, BRONZE, z=0.2)
    return fig.render(9, 20, (4.5, 18))


def main():
    parts = {'magrail_bar': bar(), 'magrail_cap': cap(), 'magrail_hanger': hanger()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        t = parts['magrail_bar']
        tt = [sum((row for _ in range(4)), []) for row in t]
        big = side_by_side([tt, parts['magrail_cap'], parts['magrail_hanger']], 6)
        write_png(sys.argv[1] + '/magnet_rail_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
