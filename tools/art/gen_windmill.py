"""Windmill: a tall lattice-girder tower on a brass foot with a gearbox
head; the sails are drawn by the game (they spin), from windmill_sail.png.

    python3 tools/art/gen_windmill.py [preview_dir]

windmill.png: 32x72, feet at (16, 71); the hub is at (0, -64) from the feet.
windmill_sail.png: 40x40, centred on the hub: four canvas sails on spars.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

CANVAS = [(120, 105, 85), (170, 150, 120), (205, 190, 160), (230, 220, 195)]


def tower():
    fig = Figure()
    fig.box((-9, -5, 9, 0), DARK, z=0, bevel=0.8)
    fig.box((-7, -8, 7, -4), BRONZE, z=0.1, bevel=0.6)
    for s in (-1, 1):
        fig.capsule((s * 6, -6), (s * 2.2, -60), 0.9, STEEL, z=0.2)
    for k in range(6):
        y0 = -8 - k * 9
        y1 = y0 - 9
        w0 = 6 - (6 - 2.2) * (k * 9) / 52
        w1 = 6 - (6 - 2.2) * ((k + 1) * 9) / 52
        fig.capsule((-w0, y0), (w1, y1), 0.45, STEEL, z=0.15)
        fig.capsule((w0, y0), (-w1, y1), 0.45, STEEL, z=0.15)
    fig.box((-5, -69, 6, -59), BRONZE, z=0.5, bevel=1.0)   # gearbox head
    fig.poly([(-5, -64), (-10, -62), (-5, -60)], BRONZE, z=0.45)  # tail vane
    return fig.render(32, 72, (16, 71))


def sail():
    fig = Figure()
    for k in range(4):
        a = k * math.pi / 2
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        fig.capsule((0, 0), (d[0] * 18, d[1] * 18), 0.6, DARK, z=0.2)
        p = [(d[0] * 5 + n[0] * 1, d[1] * 5 + n[1] * 1), (d[0] * 18 + n[0] * 1, d[1] * 18 + n[1] * 1),
             (d[0] * 17 + n[0] * 6, d[1] * 17 + n[1] * 6), (d[0] * 6 + n[0] * 5, d[1] * 6 + n[1] * 5)]
        fig.poly(p, CANVAS, z=0.1, shade=0.3)
    fig.disc((0, 0), 2.6, BRONZE, z=0.5)
    fig.sphere((0, 0), 1.2, STEEL, z=0.6)
    return fig.render(40, 40, (20, 20), extra=['786955', 'aa9678', 'cdbea0', 'e6dcc3'])


def main():
    write_png(SPR + 'windmill.png', 32, 72, tower())
    write_png(SPR + 'windmill_sail.png', 40, 40, sail())
    print('wrote windmill.png, windmill_sail.png')
    if len(sys.argv) > 1:
        big = side_by_side([tower(), sail()], 6)
        write_png(sys.argv[1] + '/windmill_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
