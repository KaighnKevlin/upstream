"""Tally wheel: a brass star-wheel (eight arms with rounded tips on a
steel hub) and the steel hanger it turns on, with the pull-wire's eye.

    python3 tools/art/gen_tally.py [preview_dir]

Writes tally_wheel.png (22x22, the axle at the centre (11, 11), arms to
radius 9; the code turns it a notch per piece) and tally_bracket.png
(16x16, the axle at (8, 13): the hanger runs up to y -10, the wire's eye
is at (6, -6)).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def wheel():
    fig = Figure()
    for k in range(8):
        a = math.radians(k * 45)
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * 2, s * 2), (c * 7.6, s * 7.6), 1.25, BRONZE, z=0)
        fig.sphere((c * 8.0, s * 8.0), 1.2, BRONZE, z=0.1)             # rounded tips
    fig.disc((0, 0), 3.4, BRONZE, z=0.2)
    fig.disc((0, 0), 2.0, STEEL, z=0.3)
    fig.sphere((-0.3, -0.3), 0.7, BRONZE, z=0.4)
    return fig.render(22, 22, (11, 11))


def bracket():
    fig = Figure()
    fig.box((-4, -12, 4, -9.2), STEEL, z=0, bevel=0.6)                  # the clamp plate
    for x in (-2.6, 2.6):
        fig.sphere((x, -10.6), 0.5, BRONZE, z=0.1)
    fig.box((-1.1, -9.6, 1.1, 0.5), STEEL, z=0.2, bevel=0.5)            # the hanger
    fig.capsule((0.8, -6.3), (4.8, -6.1), 0.5, STEEL, z=0.15)
    fig.disc((6, -6), 1.4, BRONZE, z=0.3)                                # the wire's eye
    fig.sphere((6, -6), 0.55, DARK, z=0.4)
    return fig.render(16, 16, (8, 13))


def main():
    w, b = wheel(), bracket()
    write_png(SPR + 'tally_wheel.png', 22, 22, w)
    write_png(SPR + 'tally_bracket.png', 16, 16, b)
    print('wrote tally_wheel.png, tally_bracket.png')
    if len(sys.argv) > 1:
        big = side_by_side([w, b], 8)
        write_png(sys.argv[1] + '/tally_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
