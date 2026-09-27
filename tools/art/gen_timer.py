"""Clockwork timer: a brass clock face on an iron post, a bell on top that
rings when it trips its machines.

    python3 tools/art/gen_timer.py [preview_dir]

Writes assets/sprites/timer.png: 1 frame of 20x34, feet at (10, 33).
The face's centre is at about (0, -21) from the feet (the hand is drawn
by the game, sweeping round).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 20, 34, (10, 33)
FACE = [(200, 190, 160), (225, 215, 185), (240, 232, 205), (250, 246, 230)]


def build():
    fig = Figure()
    fig.box((-1.2, -14, 1.2, 0), DARK, z=0, bevel=0.4)            # post
    fig.box((-4, -1.5, 4, 0), DARK, z=0.1, bevel=0.3)             # foot
    fig.disc((0, -21), 7.2, BRONZE, z=1)                          # case
    fig.disc((0, -21), 5.8, FACE, z=1.1)
    for k in range(12):
        a = k / 12 * math.tau
        r1 = 4.6 if k % 3 else 3.9
        fig.capsule((math.sin(a) * r1, -21 - math.cos(a) * r1), (math.sin(a) * 5.3, -21 - math.cos(a) * 5.3), 0.3, DARK, z=1.2)
    fig.sphere((0, -21), 0.8, BRONZE, z=1.3)
    fig.ellipsoid((0, -30), (3.2, 2.4), BRONZE, z=1.4, grit=0.04)  # the bell
    fig.box((-3.5, -28.4, 3.5, -27.6), BRONZE, z=1.45, bevel=0.2)
    fig.sphere((0, -32.5), 0.7, STEEL, z=1.5)
    return fig.render(W, H, O, extra=['c8be a0'.replace(' ', ''), 'e1d7b9', 'f0e8cd', 'faf6e6'])


def main():
    f = build()
    write_png(SPR + 'timer.png', W, H, f)
    print('wrote timer.png')
    if len(sys.argv) > 1:
        big = side_by_side([f], 8)
        write_png(sys.argv[1] + '/timer_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
