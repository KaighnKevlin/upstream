"""Relay hub: a riveted brass junction box with a steel input terminal on
its left, three empty lamp bezels (the code lights them) each wired across
a steel bus bar to a steel wire hook on the right edge.

    python3 tools/art/gen_relay_hub.py [preview_dir]

Writes relay_hub.png (30x24, the node origin at (17, 12): the box x -9..9,
y -10..10, the input terminal at (-13, 0), the lamps at (-3, -6 / 0 / 6),
the hooks at (9, -6 / 0 / 6)).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

HOOKS_Y = (-6, 0, 6)


def body():
    fig = Figure()
    # the input terminal
    fig.capsule((-13, 0), (-8, 0), 0.9, STEEL, z=0)
    fig.disc((-13, 0), 2.6, STEEL, z=0.1)
    fig.sphere((-13, 0), 1.0, BRONZE, z=0.2)
    # the box: brass, a darker inset panel, corner rivets
    fig.box((-9, -10, 9, 10), BRONZE, z=1, bevel=1.3, grit=0.05)
    fig.poly([(-7.4, -8.4), (5.6, -8.4), (5.6, 8.4), (-7.4, 8.4)], STEEL, z=1.05, shade=0.3, grit=0.03)
    for x in (-7.9, 7.9):
        for y in (-8.9, 8.9):
            fig.sphere((x, y), 0.6, STEEL, z=1.1)
    for y in HOOKS_Y:
        fig.capsule((-1, y), (8, y), 0.55, STEEL, z=1.2)          # bus to its hook
        fig.disc((-3, y), 2.6, BRONZE, z=1.3)                     # lamp bezel
        fig.disc((-3, y), 1.8, DARK, z=1.35)
        # the hook, standing proud of the right edge
        fig.capsule((8, y), (10.2, y - 0.4), 0.8, STEEL, z=1.4)
        fig.sphere((10.4, y - 0.6), 1.1, STEEL, z=1.45)
    return fig.render(30, 24, (17, 12))


def main():
    b = body()
    write_png(SPR + 'relay_hub.png', 30, 24, b)
    print('wrote relay_hub.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/relay_hub_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
