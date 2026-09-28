"""Ropeway: the tall oak A-frame at the high end with its brass landing, the
narrower frame at the low end, and the pulley wheel the cable runs over at
the top of each (the code draws the cable and the riders' hooks).

    python3 tools/art/gen_ropeway.py [preview_dir]

Writes:
- ropeway_post_high.png  32x64, its node origin (the landing's middle) at
  (16, 32). The legs stand at (+-8, 30) and meet at the pulley, (0, -26);
  the landing's top is on row +7, x -12..12.
- ropeway_post_low.png   20x64, the same frame +-6 at the foot, origin
  (10, 32) (the code puts it at the cable's low end).
- ropeway_pulley.png     11x11, its axle at (5, 5).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def post(foot, landing):
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * foot, 30), (s * 1.5, -24), 1.3, OAK, z=0)           # legs
        fig.box((s * foot - 2.5, 28.5, s * foot + 2.5, 31.5), STEEL, z=0.1, bevel=0.5)   # shoes
    # braces: a cross-tie and an X between the legs
    fig.capsule((-foot * 0.72, 16), (foot * 0.72, 16), 0.8, OAK, z=0.05)
    fig.capsule((-foot * 0.72, 16), (foot * 0.4, -6), 0.6, OAK[:4], z=0.02)
    fig.capsule((foot * 0.72, 16), (-foot * 0.4, -6), 0.6, OAK[:4], z=0.02)
    fig.capsule((-foot * 0.4, -6), (foot * 0.4, -6), 0.7, OAK, z=0.05)
    # the head: a steel yoke for the pulley
    fig.box((-3, -27, 3, -21), STEEL, z=0.2, bevel=0.8)
    for y in (16, -6):
        for s in (-1, 1):
            fig.sphere((s * foot * (0.72 if y > 0 else 0.4), y), 0.55, BRONZE, z=0.3)
    if landing:
        fig.box((-12.5, 7, 12.5, 9.8), BRONZE, z=0.4, bevel=0.6)             # the landing
        fig.box((-12.5, 9.2, 12.5, 10.6), STEEL, z=0.35, bevel=0.4)
        for s in (-1, 1):
            fig.capsule((s * 11, 10), (s * 5.5, 16), 0.6, STEEL, z=0.3)      # its brackets
    return fig


def pulley():
    fig = Figure()
    fig.disc((0, 0), 4.6, BRONZE, z=0)                                      # the rim
    fig.disc((0, 0), 3.2, DARK, z=0.1)
    fig.capsule((-3, 0), (3, 0), 0.6, BRONZE, z=0.2)                        # spokes
    fig.capsule((0, -3), (0, 3), 0.6, BRONZE, z=0.2)
    fig.sphere((0, 0), 1.2, STEEL, z=0.3)
    return fig.render(11, 11, (5, 5))


def main():
    hi = post(8, True).render(32, 64, (16, 32), extra=OAK_EXTRA)
    lo = post(6, False).render(20, 64, (10, 32), extra=OAK_EXTRA)
    pu = pulley()
    write_png(SPR + 'ropeway_post_high.png', 32, 64, hi)
    write_png(SPR + 'ropeway_post_low.png', 20, 64, lo)
    write_png(SPR + 'ropeway_pulley.png', 11, 11, pu)
    print('wrote ropeway_post_high.png, ropeway_post_low.png, ropeway_pulley.png')
    if len(sys.argv) > 1:
        big = side_by_side([hi, lo, pu], 5)
        write_png(sys.argv[1] + '/ropeway_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
