"""Catapult: catches ore in its bucket and flings it where it's aimed.

    python3 tools/art/gen_catapult.py [preview_dir]

catapult_base.png 36x30, origin (18, 12) = the arm's pivot; the frame's feet
                  stand 16px below it.
catapult_arm.png  38x12, pointing +x, pivot at (4, 6); the bucket (open to
                  -y in arm space) sits at the far end, around x=26..32.
"""
import sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c', '8d7051')]


def base():
    fig = Figure()
    fig.capsule((0, 0), (-10, 16), 1.6, BRONZE, z=0)                # A-frame legs
    fig.capsule((0, 0), (10, 16), 1.6, BRONZE, z=0)
    fig.capsule((-6, 10), (6, 10), 1.0, STEEL, z=0.5)               # cross-tie
    fig.box((-13, 15, -7, 18), DARK, z=0.6, bevel=0.6)              # feet
    fig.box((7, 15, 13, 18), DARK, z=0.6, bevel=0.6)
    fig.disc((0, 0), 5.5, DARK, z=1)                                # spring drum
    fig.gear((0, 0), 4.8, 10, 0, STEEL, z=1.1, hub_mat=BRONZE)
    fig.sphere((0, 0), 1.4, GLOW, z=1.3, emissive=True)
    return fig.render(36, 30, (18, 12))


def arm():
    fig = Figure()
    fig.capsule((0, 0), (24, 0), 1.7, WOOD, z=0, grit=0.12)          # beam
    for x in (7, 16):
        fig.ellipsoid((x, 0), (0.8, 2.2), BRONZE, z=0.5)               # bands
    fig.sphere((0, 0), 2.6, BRONZE, z=1)                               # hub
    # bucket: a brass cup, open toward -y
    fig.capsule((24, -4), (24, 2), 1.2, BRONZE, z=1)
    fig.capsule((31, -4), (31, 2), 1.2, BRONZE, z=1)
    fig.capsule((24, 2.5), (31, 2.5), 1.3, BRONZE, z=1)
    fig.box((25, -3, 30, 1.8), DARK, z=0.8, bevel=0.3, grit=0.0)       # inside of the cup
    return fig.render(38, 12, (4, 6))


def main():
    b, a = base(), arm()
    write_png(SPR + 'catapult_base.png', 36, 30, b)
    write_png(SPR + 'catapult_arm.png', 38, 12, a)
    print('wrote catapult_base.png, catapult_arm.png')
    if len(sys.argv) > 1:
        comp = [row[:] for row in b]
        for y, row in enumerate(a):
            for x, p in enumerate(row):
                X, Y = 18 - 4 + x, 12 - 6 + y
                if p[3] and 0 <= X < 36 and 0 <= Y < 30:
                    comp[Y][X] = p
        big = side_by_side([b, a, comp], 8)
        write_png(sys.argv[1] + '/catapult_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
