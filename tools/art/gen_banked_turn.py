"""Banked turn: a steel half-pipe bent through a U, seen from the side:
the rolled outer rim the marbles ride on, the shaded far wall of the pipe
inside it, riveted flanges at both mouths, and a brass bracket out to the
wall. Drawn turning out toward +x (mirrored in code for side -1).

    python3 tools/art/gen_banked_turn.py [preview_dir]

Writes assets/sprites/banked_turn.png (50x68, the piece's origin, the top
mouth, at (6, 12)): the bend is centred on (0, 22); the rim runs at r 29.5
from straight up round through +x to straight down, the bracket along
y 22 out to x 40.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

C = (0.0, 22.0)
RR = 29.5


def _at(th, r):
    return (C[0] + math.sin(th) * r, C[1] - math.cos(th) * r)


def turn():
    fig = Figure()
    n = 24
    for i in range(n):
        t0, t1 = math.pi * i / n, math.pi * (i + 1) / n
        # the far wall of the pipe, a dark band inside the rim
        fig.poly([_at(t0, 22.5), _at(t1, 22.5), _at(t1, 28.6), _at(t0, 28.6)], STEEL, z=0, shade=0.22)
        fig.capsule(_at(t0, 23), _at(t1, 23), 0.45, STEEL[:4], z=0.1)       # its inner edge
        fig.capsule(_at(t0, RR), _at(t1, RR), 1.5, STEEL, z=1, grit=0.03)  # the rolled rim
    for k in range(1, 6):
        fig.sphere(_at(math.pi * k / 6, RR), 0.55, BRONZE, z=1.2)           # rivets
    # the bracket to the wall, under the rim
    fig.box((C[0] + RR, C[1] - 1.6, C[0] + RR + 10.5, C[1] + 1.6), BRONZE, z=0.5, bevel=0.6)
    fig.box((C[0] + RR + 9, C[1] - 4, C[0] + RR + 11, C[1] + 4), BRONZE, z=0.6, bevel=0.5)
    for y in (-2.5, 2.5):
        fig.sphere((C[0] + RR + 10, C[1] + y), 0.55, STEEL, z=0.7)
    # flanges at the mouths
    for th in (0.0, math.pi):
        a, b = _at(th, 21.5), _at(th, RR + 1.6)
        fig.box((min(a[0], b[0]) - 1.1, min(a[1], b[1]), max(a[0], b[0]) + 1.1, max(a[1], b[1])), STEEL, z=1.3, bevel=0.5)
    return fig.render(50, 68, (6, 12))


def main():
    t = turn()
    write_png(SPR + 'banked_turn.png', 50, 68, t)
    print('wrote banked_turn.png')
    if len(sys.argv) > 1:
        big = side_by_side([t], 6)
        write_png(sys.argv[1] + '/banked_turn_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
