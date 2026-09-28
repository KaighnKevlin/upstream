"""Trebuchet: an oak A-frame on a sill, the throwing arm that swings on
its brass axle, the counterweight box that hangs from the arm's short end,
and the leather sling pouch. Drawn throwing toward +x (mirrored in code).

    python3 tools/art/gen_trebuchet.py [preview_dir]

Writes:
- trebuchet_frame.png  52x52, the piece's origin at (26, 42): the axle at
  (0, -34) from it, the legs stand at (+-18, 8) on a sill along y 8.
- trebuchet_arm.png    80x10, the axle at (32, 5); drawn level: the long
  (sling) end runs to +42, the short (box) end to -30. The code rotates it.
- trebuchet_box.png    24x22, its hanging pin at (12, 7); the box is
  22 x 18 (y -7..11 from the pin), open at the top.
- trebuchet_sling.png  26x12, the pouch's centre (where the shot sits)
  at (13, 3).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((0, -34), (s * 18, 7), 1.9, OAK, z=0)             # the legs
        fig.box((s * 18 - 3, 6, s * 18 + 3, 9), BRONZE, z=0.3, bevel=0.6)   # shoes
        fig.sphere((s * 18, 7.4), 0.6, STEEL, z=0.4)
    fig.box((-24, 7, 24, 10.5), OAK, z=0.2, bevel=0.8)                # the sill
    fig.capsule((-9.5, -12), (9.5, -12), 1.1, OAK, z=0.1)            # cross brace
    for x in (-9.5, 9.5):
        fig.sphere((x, -12), 0.7, BRONZE, z=0.2)
    fig.disc((0, -34), 3.4, BRONZE, z=0.5)                            # axle bearing
    fig.disc((0, -34), 1.5, DARK, z=0.6)
    return fig.render(52, 52, (26, 42), extra=OAK_EXTRA)


def arm():
    fig = Figure()
    # tapers from the axle out to the sling end
    fig.poly([(-30, -2.4), (0, -2.8), (42, -1.2), (42, 1.2), (0, 2.8), (-30, 2.4)], OAK, z=0, shade=0.55)
    fig.capsule((-30, 1.9), (42, 0.9), 0.5, OAK[:2], z=0.05)          # the shaded underside
    fig.capsule((-30, -1.9), (0, -2.3), 0.4, OAK[3:], z=0.05)         # a lit top edge
    fig.capsule((0, -2.3), (42, -0.8), 0.4, OAK[3:], z=0.05)
    for x in (-12, 12, 26):
        fig.box((x - 1, -3, x + 1, 3), BRONZE, z=0.2, bevel=0.5)      # iron bands (brass here)
    fig.box((-31.5, -2.6, -27, 2.6), STEEL, z=0.3, bevel=0.6)          # the box's hanging iron
    fig.sphere((-30, 0), 0.9, BRONZE, z=0.4)
    fig.sphere((42, 0), 1.3, STEEL, z=0.3)                             # the sling's release hook
    fig.disc((0, 0), 3.8, BRONZE, z=0.5)                               # the axle boss
    fig.sphere((0, 0), 1.5, STEEL, z=0.6)
    return fig.render(80, 10, (32, 5), extra=OAK_EXTRA)


def box():
    fig = Figure()
    fig.box((-10, -6, 10, 10), DARK, z=0, bevel=0.5)                   # the inside, in shadow
    for s in (-1, 1):
        fig.box((s * 10 - 1.6, -7, s * 10 + 1.6, 11), OAK, z=0.2, bevel=0.6)   # corner posts
    fig.box((-11, 7.5, 11, 11), OAK, z=0.3, bevel=0.7)                 # the floor planks
    for y in (-2.5, 5):
        fig.box((-11, y - 0.9, 11, y + 0.9), BRONZE, z=0.35, bevel=0.4)   # bands
    for s in (-1, 1):
        fig.disc((s * 10, 0), 1.9, STEEL, z=0.5)                       # the hanging pins
        fig.sphere((s * 10, 0), 0.7, BRONZE, z=0.6)
    return fig.render(24, 22, (12, 7), extra=OAK_EXTRA)


def sling():
    fig = Figure()
    # a leather pouch hung from two ropes, sagging under the shot
    pts = [(math.cos(math.radians(a)) * 10.5, 1 + math.sin(math.radians(a)) * 6.5) for a in range(10, 171, 16)]
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 1.4, BRONZE, z=0)
    for s in (-1, 1):
        fig.capsule((s * 10.5, 2), (s * 11.5, -2), 0.6, BRONZE[2:], z=0.1)   # the rope ends
    return fig.render(26, 12, (13, 3))


def main():
    f, a, b, s = frame(), arm(), box(), sling()
    write_png(SPR + 'trebuchet_frame.png', 52, 52, f)
    write_png(SPR + 'trebuchet_arm.png', 80, 10, a)
    write_png(SPR + 'trebuchet_box.png', 24, 22, b)
    write_png(SPR + 'trebuchet_sling.png', 26, 12, s)
    print('wrote trebuchet_frame.png, trebuchet_arm.png, trebuchet_box.png, trebuchet_sling.png')
    if len(sys.argv) > 1:
        big = side_by_side([f, a, b, s], 8)
        write_png(sys.argv[1] + '/trebuchet_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
