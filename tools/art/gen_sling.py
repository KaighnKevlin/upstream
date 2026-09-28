"""Sling: an iron A-frame post, the brass arm with its cup that the code
whirls round the hub, and the hub itself.

    python3 tools/art/gen_sling.py [preview_dir]

Writes (all measured from the hub, the node origin):
- sling_post.png  20x32, the hub at (10, 1): two iron legs from (0, 4) down
  to (+-6, 30), a brass cross-brace, feet, and the bearing block at the top.
- sling_arm.png   30x14, the hub at (2, 7): a steel rod along +x to the
  cup, a brass half-ring round (22, 0) open away from the hub; the code
  rotates it to the arm angle.
- sling_hub.png   12x12, centre (6, 6): the 10 px hub, steel with a brass cap.
"""
import math
import sys
from clockwork import *
from clockwork import _shade
from pixtools import write_png
from titan_lib import SPR, side_by_side


def half_ring(fig, c, r0, r1, mat, z=0):
    """A rounded band round c on the side facing -x (toward the hub)."""
    cx, cy = c
    mid, half = (r0 + r1) / 2, (r1 - r0) / 2

    def fn(x, y):
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy)
        if d < r0 or d > r1 or dx > 0.6:
            return None
        k = (d - mid) / half
        ux, uy = dx / (d or 1), dy / (d or 1)
        nx, ny = ux * k * 0.8, uy * k * 0.8
        return _shade((nx, ny, math.sqrt(max(0.05, 1 - nx * nx - ny * ny))), mat, 0.05, int(x * 3), int(y * 3))
    fig.prims.append((z, fn, (cx - r1, cy - r1, cx + r1, cy + r1)))


def post():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((0, 4), (s * 6, 29), 1.3, STEEL, z=0)                # the legs
        fig.box((s * 6 - 2.2, 28.4, s * 6 + 2.2, 30.4), DARK, z=0.3, bevel=0.5)   # feet
    fig.capsule((-3.8, 20), (3.8, 20), 0.8, BRONZE, z=0.2)              # the cross-brace
    for s in (-1, 1):
        fig.sphere((s * 4, 20), 0.6, STEEL, z=0.25)
    fig.box((-2.6, 1.4, 2.6, 6.4), STEEL, z=0.4, bevel=0.8)             # the bearing block
    return fig.render(20, 32, (10, 1))


def arm():
    fig = Figure()
    fig.capsule((0, 0), (17.5, 0), 1.1, STEEL, z=0)                      # the rod
    fig.box((14.5, -1.6, 17.6, 1.6), BRONZE, z=0.1, bevel=0.6)           # its collar at the cup
    half_ring(fig, (22, 0), 3.6, 5.4, BRONZE, z=0.2)                     # the cup
    return fig.render(30, 14, (2, 7))


def hub():
    fig = Figure()
    fig.disc((0, 0), 5.0, STEEL, z=0)
    fig.sphere((0, 0), 3.2, BRONZE, z=0.1)
    fig.sphere((-0.9, -0.9), 0.8, [BRONZE[5], BRONZE[6], BRONZE[7]], z=0.2)
    return fig.render(12, 12, (6, 6))


def main():
    p, a, h = post(), arm(), hub()
    write_png(SPR + 'sling_post.png', 20, 32, p)
    write_png(SPR + 'sling_arm.png', 30, 14, a)
    write_png(SPR + 'sling_hub.png', 12, 12, h)
    print('wrote sling_post.png, sling_arm.png, sling_hub.png')
    if len(sys.argv) > 1:
        big = side_by_side([p, a, h], 8)
        write_png(sys.argv[1] + '/sling_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
