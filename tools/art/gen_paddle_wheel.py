"""Paddle wheel: a small mill wheel, eight flat oak paddles on iron arms
round a brass hub (open between them, for the stream to fall through), and
the narrow trestle its axle sits on.

    python3 tools/art/gen_paddle_wheel.py [preview_dir]

Writes assets/sprites/paddle_wheel.png (48x48, the axle at the centre
(24, 24); paddle k runs radially out to r 20 at k*45 degrees, the code
rotates it) and paddle_wheel_frame.png (28x42, the axle at (14, 4); the
feet at (+-10, 36) from it).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
R = 20.0


def wheel():
    fig = Figure()
    # a thin brass ring ties the arms together inside the paddles
    segs = 40
    for k in range(segs):
        a0, a1 = k / segs * math.tau, (k + 1) / segs * math.tau
        r = R - 9
        fig.capsule((math.cos(a0) * r, math.sin(a0) * r), (math.cos(a1) * r, math.sin(a1) * r), 0.6, BRONZE, z=1)
    for k in range(8):
        a = math.radians(k * 45)
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * 3, s * 3), (c * (R - 7), s * (R - 7)), 0.8, STEEL, z=0)     # iron arm
        # the paddle: an oak board along the radius, a brass-shod tip
        cx, cy = c * (R - 4), s * (R - 4)
        fig.box((cx - 4.4, cy - 2.2, cx + 4.4, cy + 2.2), OAK, z=2, bevel=0.8, tilt=k * 45)
        fig.box((c * (R - 0.6) - 0.9, s * (R - 0.6) - 2.4, c * (R - 0.6) + 0.9, s * (R - 0.6) + 2.4), BRONZE, z=2.1, bevel=0.4, tilt=k * 45)
        fig.sphere((c * (R - 5), s * (R - 5)), 0.55, STEEL, z=2.2)                   # its bolt
    fig.disc((0, 0), 4.2, BRONZE, z=3)
    fig.sphere((0, 0), 1.6, STEEL, z=3.1)
    return fig.render(48, 48, (24, 24), extra=OAK_EXTRA)


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1, 0), (s * 10, 35), 1.4, OAK, z=1)
        fig.box((s * 10 - 2.6, 35, s * 10 + 2.6, 37.6), BRONZE, z=1.2, bevel=0.5)
    fig.capsule((-6, 22), (6, 22), 0.9, OAK, z=0.9)
    fig.ellipsoid((0, 0), (3.6, 3), BRONZE, z=2)
    fig.disc((0, 0), 1.6, DARK, z=2.1)
    return fig.render(28, 42, (14, 4), extra=OAK_EXTRA)


def main():
    w, f = wheel(), frame()
    write_png(SPR + 'paddle_wheel.png', 48, 48, w)
    write_png(SPR + 'paddle_wheel_frame.png', 28, 42, f)
    print('wrote paddle_wheel.png, paddle_wheel_frame.png')
    if len(sys.argv) > 1:
        big = side_by_side([w, f], 8)
        write_png(sys.argv[1] + '/paddle_wheel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
