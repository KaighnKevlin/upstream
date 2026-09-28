"""Delay relay: a small brass carriage clock on a steel bracket: a bevelled
brass case round an ivory face, a winding key on top, and a red
hand as its own sprite (the code turns it; it also draws the
tick marks for the setting and the wound part of the dial).

    python3 tools/art/gen_delay_relay.py [preview_dir]

Writes delay_clock.png (28x38, the node origin at (14, 19): the case radius
11.5, the face radius 8, the bracket's foot on y 17, the key's bow at
(0, -15)) and delay_hand.png (12x5, the arbor at (3, 2.5), mid-row, pointing +x to
radius 7).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]
RED_EXTRA = ['8a2418', 'c83a26', 'e8604a']
RED = [(138, 36, 24), (200, 58, 38), (232, 96, 74)]


def clock():
    fig = Figure()
    # the bracket: a steel stem to a foot bolted down
    fig.box((-1.3, 9, 1.3, 16.5), STEEL, z=0, bevel=0.5)
    fig.box((-7, 15.6, 7, 18), STEEL, z=0.1, bevel=0.7)
    for x in (-5, 5):
        fig.sphere((x, 16.8), 0.6, BRONZE, z=0.2)
    # the winding key on top: a stem and a two-lobed bow
    fig.box((-0.9, -13, 0.9, -10), STEEL, z=0, bevel=0.4)
    for x in (-1.6, 1.6):
        fig.sphere((x, -15), 1.6, BRONZE, z=0.1)
    fig.sphere((0, -15), 0.6, DARK, z=0.2)
    # the case and bezel
    fig.disc((0, 0), 11.5, BRONZE, z=1)
    fig.disc((0, 0), 9.6, BRONZE, z=1.1)
    fig.disc((0, 0), 9.0, DARK, z=1.17)
    for k in range(4):
        a = math.radians(45 + k * 90)
        fig.sphere((math.cos(a) * 10.6, math.sin(a) * 10.6), 0.55, STEEL, z=1.15)
    fig.disc((0, 0), 8.2, IVORY, z=1.2)
    return fig.render(28, 38, (14, 19), extra=IVORY_EXTRA)


def hand():
    fig = Figure()
    fig.capsule((-1.6, 0), (6.8, 0), 0.55, RED, z=0)
    fig.poly([(4.8, -1.1), (7.6, 0), (4.8, 1.1)], RED, z=0.1, shade=0.7)
    fig.sphere((0, 0), 1.1, BRONZE, z=0.3)
    return fig.render(12, 5, (3, 2.5), outline=False, extra=RED_EXTRA)


def main():
    c, h = clock(), hand()
    write_png(SPR + 'delay_clock.png', 28, 38, c)
    write_png(SPR + 'delay_hand.png', 12, 5, h)
    print('wrote delay_clock.png, delay_hand.png')
    if len(sys.argv) > 1:
        big = side_by_side([c, h], 8)
        write_png(sys.argv[1] + '/delay_relay_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
