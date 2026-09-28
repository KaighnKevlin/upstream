"""Flipper: a pinball paddle (a tapered red body with a lit top edge, a
brass pivot cap) and its stand (a brass pedestal under the pivot, a steel
foot, and the stop post behind the pivot that pieces settle against).

    python3 tools/art/gen_flipper.py [preview_dir]

Writes (drawn for side = +1, the free end to the right; the code mirrors
both for side -1):
- flipper_paddle.png  52x14, the pivot at (6, 7); the paddle runs 40 px
  along +x on the pivot's row. The code rotates it about the pivot.
- flipper_base.png    20x38, the pivot at (10, 14): the stop post at
  x -3, y -12..0, the pedestal y 4..20 and its foot below.
"""
import math, sys
import clockwork
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

RED_EXTRA = ['4a1a16', '7a2620', 'a8382c', 'cc5a44', 'e88a6c']
RED = [(74, 26, 22), (122, 38, 32), (168, 56, 44), (204, 90, 68), (232, 138, 108)]


def paddle():
    fig = Figure()

    def body(x, y):                                                       # the tapered body, rounded tip
        r = 4.6 - 2.0 * min(max(x, 0.0), 40.0) / 40
        dx = x - 40 if x > 40 else (x if x < 0 else 0.0)
        d = (dx * dx + y * y) / (r * r)
        if d > 1: return None
        nz = math.sqrt(1 - d)
        return clockwork._shade((dx / r, y / r, nz), RED, 0.05, int(x * 3), int(y * 3))
    fig.prims.append((0, body, (-5, -5, 43, 5)))
    fig.capsule((3, -2.5), (38, -1.3), 0.45, RED[3:], z=0.2, grit=0)     # a lit edge along the top
    fig.disc((0, 0), 4.0, BRONZE, z=0.5)                                 # pivot cap
    fig.sphere((0, 0), 1.4, STEEL, z=0.6)
    return fig.render(52, 14, (6, 7), extra=RED_EXTRA)


def base():
    fig = Figure()
    fig.box((-1.5, 3, 1.5, 20), BRONZE, z=0, bevel=0.7)                  # pedestal
    fig.box((-6, 19, 6, 22), STEEL, z=0.1, bevel=0.6)                    # foot
    for x in (-4, 4):
        fig.sphere((x, 20.5), 0.55, BRONZE, z=0.2)
    fig.box((-4.2, -12.5, -1.8, 4.5), STEEL, z=0.3, bevel=0.6)          # the stop post
    fig.box((-4.6, -13.5, -1.4, -11.8), BRONZE, z=0.4, bevel=0.5)
    fig.box((-4.6, 3.2, 1.8, 5.4), STEEL, z=0.35, bevel=0.5)            # the collar tying it to the pedestal
    return fig.render(20, 38, (10, 14))


def main():
    p, b = paddle(), base()
    write_png(SPR + 'flipper_paddle.png', 52, 14, p)
    write_png(SPR + 'flipper_base.png', 20, 38, b)
    print('wrote flipper_paddle.png, flipper_base.png')
    if len(sys.argv) > 1:
        big = side_by_side([p, b], 8)
        write_png(sys.argv[1] + '/flipper_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
