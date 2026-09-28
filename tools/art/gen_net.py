"""Catch net: an oak post with brass bands, a steel cap and foot, and the
two brass eyes the net is tied to; and the brass hoop the net sags to,
seen a little from above. The net's cords are drawn in code (they sag and
wobble).

    python3 tools/art/gen_net.py [preview_dir]

Writes assets/sprites/catch_net_post.png (12x60, the post's axis at x 6;
the net's front eye (y 0 in the piece) at (8, 29), so the left post is
drawn at (-44 - 6, -29) and the right one mirrored) and catch_net_ring.png
(24x13, the hoop's centre at (12, 6), radius 9 x 3.5).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def post():
    fig = Figure()
    fig.box((-2.2, -26, 2.2, 26), OAK, z=0, bevel=1.2, grit=0.1)
    for y in (-17, 13):
        fig.box((-2.8, y - 1.1, 2.8, y + 1.1), BRONZE, z=0.2, bevel=0.5)
    fig.box((-3, -28.5, 3, -25.5), STEEL, z=0.3, bevel=0.8)              # cap
    fig.box((-4.5, 25, 4.5, 28), STEEL, z=0.3, bevel=0.7)                 # foot
    # eyes the net's front and back cords tie to (on the inner side, +x)
    for y in (0, -8):
        fig.ellipsoid((2.9, y), (1.3, 1.3), BRONZE, z=0.4)
        fig.sphere((2.9, y), 0.5, DARK, z=0.5)
    return fig.render(12, 60, (6, 29), extra=OAK_EXTRA)


def ring():
    fig = Figure()
    # a brass hoop: capsules round an ellipse, the back half behind
    n = 20
    for k in range(n):
        a0, a1 = k / n * math.tau, (k + 1) / n * math.tau
        p0 = (math.cos(a0) * 9, math.sin(a0) * 3.5)
        p1 = (math.cos(a1) * 9, math.sin(a1) * 3.5)
        back = math.sin((a0 + a1) / 2) < 0
        fig.capsule(p0, p1, 1.1, BRONZE, z=0 if back else 1)
    for x in (-9, 9):
        fig.sphere((x, 0), 0.9, STEEL, z=2)                                 # the cord lashings
    return fig.render(24, 13, (12, 6))


def main():
    p, r = post(), ring()
    write_png(SPR + 'catch_net_post.png', 12, 60, p)
    write_png(SPR + 'catch_net_ring.png', 24, 13, r)
    print('wrote catch_net_post.png, catch_net_ring.png')
    if len(sys.argv) > 1:
        big = side_by_side([p, r], 8)
        write_png(sys.argv[1] + '/net_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
