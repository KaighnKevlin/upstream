"""Magnet drum: the magnetic head pulley. A steel drum face-on, its face
painted in alternating red pole segments, a riveted rim and a brass hub,
on a brass A-bracket with a foot plate.

    python3 tools/art/gen_magnet_drum.py [preview_dir]

Writes assets/sprites/magnet_drum.png (26x26, the axle at the centre
(13, 13); drum radius 11, so the code rotates it about its centre by the
drum's phase) and magnet_drum_stand.png (24x31, the axle at (12, 5); the
feet on the row +22 below the axle).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

RED_EXTRA = ['4a1a16', '7a2620', 'a8382c', 'cc5a44', 'e88a6c']
RED = [(74, 26, 22), (122, 38, 32), (168, 56, 44), (204, 90, 68), (232, 138, 108)]
R = 11.0


def _sector(a0, a1, r0, r1, n=6):
    pts = [(math.cos(a0 + (a1 - a0) * k / n) * r1, math.sin(a0 + (a1 - a0) * k / n) * r1) for k in range(n + 1)]
    pts += [(math.cos(a1 - (a1 - a0) * k / n) * r0, math.sin(a1 - (a1 - a0) * k / n) * r0) for k in range(n + 1)]
    return pts


def drum():
    fig = Figure()
    fig.disc((0, 0), R, STEEL, z=0)
    # the pole segments: red and bare steel by turns, lit from the top left
    for k in range(6):
        a0, a1 = math.radians(k * 60 + 2), math.radians(k * 60 + 58)
        mid = (a0 + a1) / 2
        lit = 0.5 - 0.22 * (math.cos(mid) * -0.55 + math.sin(mid) * -0.8)
        if k % 2 == 0:
            fig.poly(_sector(a0, a1, 3.6, 9.2), RED, z=0.1, shade=lit)
        else:
            fig.poly(_sector(a0, a1, 3.6, 9.2), STEEL, z=0.1, shade=lit - 0.05)
    for k in range(6):
        a = math.radians(k * 60)
        fig.sphere((math.cos(a) * 10.1, math.sin(a) * 10.1), 0.6, BRONZE, z=0.3)   # rim rivets on the seams
    fig.disc((0, 0), 3.8, BRONZE, z=0.5)
    fig.disc((0, 0), 1.6, DARK, z=0.6)
    fig.sphere((-0.4, -0.4), 0.6, STEEL, z=0.7)
    return fig.render(26, 26, (13, 13), extra=RED_EXTRA)


def stand():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1.5, 0), (s * 7, 21), 1.5, BRONZE, z=0)
    fig.capsule((-4.5, 13), (4.5, 13), 0.8, DARK, z=-0.1)
    fig.box((-10, 20.5, 10, 23), STEEL, z=0.2, bevel=0.6)
    for x in (-7, 7):
        fig.sphere((x, 21.7), 0.6, BRONZE, z=0.3)
    fig.box((-3.5, -3.5, 3.5, 3.5), BRONZE, z=0.4, bevel=1.0)                # bearing block
    return fig.render(24, 31, (12, 5))


def main():
    d, s = drum(), stand()
    write_png(SPR + 'magnet_drum.png', 26, 26, d)
    write_png(SPR + 'magnet_drum_stand.png', 24, 31, s)
    print('wrote magnet_drum.png, magnet_drum_stand.png')
    if len(sys.argv) > 1:
        big = side_by_side([d, s], 8)
        write_png(sys.argv[1] + '/magnet_drum_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
