"""Treadwheel: a big oak wheel a man walks inside (two rims joined by
tread rungs, six spokes to a brass hub), and the A-frame that carries its
axle. Kept open, rims and spokes only, so the prospector inside shows.

    python3 tools/art/gen_treadwheel.py [preview_dir]

Writes assets/sprites/treadwheel.png (80x80, the axle at the centre
(40, 40); rims at r 31 and 37, twelve rungs between them, the code rotates
it) and treadwheel_frame.png (50x46, the axle at (25, 4); the feet stand
at (+-20, 40) from it).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
R = 34.0


def _ring(fig, r, w, mat, z, segs=64):
    for k in range(segs):
        a0, a1 = k / segs * math.tau, (k + 1) / segs * math.tau
        fig.capsule((math.cos(a0) * r, math.sin(a0) * r), (math.cos(a1) * r, math.sin(a1) * r), w, mat, z=z)


def wheel():
    fig = Figure()
    # six spokes: three beams through the hub
    for k in range(3):
        a = math.radians(k * 60 + 15)
        d = (math.cos(a) * (R - 3), math.sin(a) * (R - 3))
        fig.capsule((-d[0], -d[1]), d, 1.3, OAK, z=0)
    # the tread: rungs across between the rims
    for k in range(12):
        a = math.radians(k * 30)
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * (R - 3), s * (R - 3)), (c * (R + 3), s * (R + 3)), 1.5, OAK, z=1)
        fig.sphere((c * (R + 3), s * (R + 3)), 0.6, STEEL, z=2.1)          # rung pegs through the outer rim
    _ring(fig, R - 3, 0.9, OAK, 2)                                           # inner rim
    _ring(fig, R + 3, 1.3, OAK, 2)                                           # outer rim
    _ring(fig, R + 3, 0.45, BRONZE[3:], 2.05)                                # its brass tyre
    fig.disc((0, 0), 5.2, BRONZE, z=3)                                       # the hub
    fig.gear((0, 0), 3.6, 8, 0, STEEL, z=3.1)
    fig.sphere((0, 0), 1.5, BRONZE, z=3.2)
    return fig.render(80, 80, (40, 40), extra=OAK_EXTRA)


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1.5, 0), (s * 20, 38.5), 2.0, OAK, z=1)
        fig.box((s * 20 - 3.5, 38.5, s * 20 + 3.5, 41.5), BRONZE, z=1.2, bevel=0.6)   # shoes
        fig.sphere((s * 20, 39.8), 0.6, STEEL, z=1.3)
    fig.capsule((-13, 26), (13, 26), 1.2, OAK, z=0.9)                       # cross brace
    fig.ellipsoid((0, 0), (5, 4), BRONZE, z=2)                              # bearing block
    fig.disc((0, 0), 2.2, DARK, z=2.1)
    return fig.render(50, 46, (25, 4), extra=OAK_EXTRA)


def main():
    w, f = wheel(), frame()
    write_png(SPR + 'treadwheel.png', 80, 80, w)
    write_png(SPR + 'treadwheel_frame.png', 50, 46, f)
    print('wrote treadwheel.png, treadwheel_frame.png')
    if len(sys.argv) > 1:
        big = side_by_side([w, f], 6)
        write_png(sys.argv[1] + '/treadwheel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
