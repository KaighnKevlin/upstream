"""Helix: a steel tube coil wound round a steel post, a brass cap and foot,
brass collars where the coil is braced to the post, a funnel lip at the
top mouth and a spout at the bottom. In two layers per turn count, so
pieces riding the coil show between them: the post and the coil's far
strands (behind the riders) and its near strands (in front).

    python3 tools/art/gen_helix.py [preview_dir]

Writes helix_back_<n>.png and helix_front_<n>.png for n = 2, 3, 4 turns,
all 44 px wide with the node origin (the top mouth, on the post) at
(22, 12); drawn for side = +1 (pieces arriving heading right), the code
flips them for side = -1. The coil is x = sin(th) * 14, y = 26 * th / 2pi;
the near strands are where cos(th) >= 0. Heights: 26 * n + 24.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

R, PITCH = 14.0, 26.0
W, O = 44, (22, 12)
TUBE = 1.6


def _coil(th):
    return (math.sin(th) * R, PITCH * th / (2 * math.pi))


def _strands(fig, turns, front, mat, z):
    n = turns * 32
    for i in range(n):
        a, b = 2 * math.pi * turns * i / n, 2 * math.pi * turns * (i + 1) / n
        if (math.cos((a + b) / 2) >= 0) != front:
            continue
        fig.capsule(_coil(a), _coil(b), TUBE, mat, z=z)


def back(turns):
    d = PITCH * turns
    fig = Figure()
    # the post, a brass cap over the mouth, a brass foot plate under the spout
    fig.box((-1.6, -8, 1.6, d + 6), STEEL, z=0, bevel=0.9)
    fig.box((-7, -11, 7, -8), BRONZE, z=0.3, bevel=0.7)
    fig.sphere((0, -9.5), 0.7, STEEL, z=0.4)
    fig.box((-R - 5, d + 5.5, R + 5, d + 9), BRONZE, z=0.3, bevel=0.8)
    for x in (-R - 2, R + 2):
        fig.sphere((x, d + 7.2), 0.6, STEEL, z=0.4)
    # brass collars where the coil crosses the post (every half turn)
    for k in range(1, 2 * turns):
        y = PITCH * k / 2
        fig.box((-3, y - 1.4, 3, y + 1.4), BRONZE, z=0.35, bevel=0.6)
    # the far strands, in the post's shadow
    _strands(fig, turns, False, STEEL[1:4], 0.2)
    # the mouths: a funnel lip in at the top, a spout trough out at the bottom
    fig.capsule((-7, -2.5), (2, 0.5), 1.3, BRONZE, z=0.5)
    fig.box((-1, d - 1.6, R + 4, d + 1.4), STEEL, z=0.5, bevel=0.7)
    fig.box((R + 2.4, d - 3.2, R + 4.4, d + 1.4), BRONZE, z=0.55, bevel=0.5)
    return fig.render(W, int(d + 24), O)


def front(turns):
    fig = Figure()
    _strands(fig, turns, True, STEEL, 1)
    return fig.render(W, int(PITCH * turns + 24), O)


def main():
    shown = []
    for n in (2, 3, 4):
        b, f = back(n), front(n)
        h = int(PITCH * n + 24)
        write_png(SPR + 'helix_back_%d.png' % n, W, h, b)
        write_png(SPR + 'helix_front_%d.png' % n, W, h, f)
        shown.append([[(f[y][x] if f[y][x][3] else b[y][x]) for x in range(W)] for y in range(h)])
    print('wrote helix_back_2..4.png, helix_front_2..4.png')
    if len(sys.argv) > 1:
        big = side_by_side(shown, 4)
        write_png(sys.argv[1] + '/helix_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
