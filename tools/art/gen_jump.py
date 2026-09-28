"""Jump: a brass kicker lip on an oak post, and across the gap a steel
landing ramp on two oak posts with an oak backboard in iron straps.

    python3 tools/art/gen_jump.py [preview_dir]

Writes (drawn for a jump to the right; the code mirrors them for a jump
to the left):
- jump_kick.png  22x40, the node (the kicker's foot) at (4, 8): the lip
  runs to (13.7, -2.8), the post 30 px down.
- jump_land.png  54x78, the landing ramp's near end at (4, 30): the ramp
  runs to (42.1, 12.6), posts 30 px down from both ends, the backboard
  from (42.1, -1.4) up to (46.1, -27.4).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:5]
KICK, KA, LAND, SLOPE = 14.0, -0.2, 44.0, 0.3


def kick():
    fig = Figure()
    k = (math.cos(KA) * KICK, math.sin(KA) * KICK)
    fig.capsule((0, 1), (0, 30), 1.2, OAK, z=0)
    fig.box((-2.5, 28.5, 2.5, 31), IRON, z=0.1, bevel=0.5)
    fig.capsule((0, 0), k, 1.5, BRONZE, z=0.3)
    fig.capsule((1, 2.2), (k[0] - 1, k[1] + 2.4), 0.8, BRONZE[:5], z=0.2)   # the lip's brace
    fig.sphere((0, 0.6), 1.0, STEEL, z=0.4)
    return fig.render(22, 40, (4, 8), extra=OAK_EXTRA)


def land():
    fig = Figure()
    L = math.hypot(1, SLOPE)
    e = (LAND / L, LAND * SLOPE / L)
    for p in ((0, 0), e):
        fig.capsule((p[0], p[1] + 1), (p[0], p[1] + 30), 1.2, OAK, z=0)
        fig.box((p[0] - 2.5, p[1] + 28.5, p[0] + 2.5, p[1] + 31), IRON, z=0.1, bevel=0.5)
    fig.capsule((0, 0), e, 1.4, STEEL, z=0.3)
    for t in (0.2, 0.5, 0.8):
        fig.sphere((e[0] * t, e[1] * t + 1.2), 0.5, BRONZE, z=0.35)
    # the backboard: an oak plank in iron straps
    top = (e[0] + 4, e[1] - 40)
    fig.capsule((e[0] + 0.3, e[1] - 12), top, 1.8, OAK, z=0.2)
    for t in (0.2, 0.8):
        x = e[0] + 0.3 + (top[0] - e[0] - 0.3) * t
        y = e[1] - 12 + (top[1] - e[1] + 12) * t
        fig.box((x - 2.4, y - 0.8, x + 2.4, y + 0.8), IRON, z=0.3, bevel=0.4)
    fig.capsule((e[0], e[1]), (e[0] + 0.3, e[1] - 12), 0.9, IRON, z=0.15)   # its stay
    return fig.render(54, 78, (4, 30), extra=OAK_EXTRA)


def main():
    k, l = kick(), land()
    write_png(SPR + 'jump_kick.png', 22, 40, k)
    write_png(SPR + 'jump_land.png', 54, 78, l)
    print('wrote jump_kick.png, jump_land.png')
    if len(sys.argv) > 1:
        big = side_by_side([k, l], 4)
        write_png(sys.argv[1] + '/jump_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
