"""Clockwork bridge engine: a siege cart on two spoked wheels, a boiler and
crank at the back, and a folded truss bridge stacked on its bed. At a ditch
it swings the bridge out across the gap; after that it rolls on empty.

    python3 tools/art/gen_bridger.py [preview_dir]

Writes assets/sprites/bridger.png: 8 frames of 60x40, facing right, the
wheels' contact point at the bottom centre (28, 39):
  0-3  rolling, loaded (folded bridge on the bed)
  4-7  rolling, empty
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 60, 40, (28, 39)
N = 4
WOOD = [(41, 38, 31), (75, 54, 43), (99, 76, 54), (134, 97, 60), (168, 143, 103)]
EXTRA = ['4b362b', '634c36', '86613c', 'a88f67']


def wheel(fig, c, r, ang, z, far):
    mat = DARK if far else BRONZE
    fig.disc(c, r, DARK, z=z)
    fig.disc(c, r - 1.2, STEEL if not far else DARK, z=z + 0.05)
    fig.disc(c, r - 2.4, DARK, z=z + 0.1)
    for k in range(6):
        a = math.radians(ang + k * 60)
        fig.capsule(c, (c[0] + math.cos(a) * (r - 1.6), c[1] + math.sin(a) * (r - 1.6)), 0.6, mat, z=z + 0.2)
    fig.sphere(c, 1.5, mat, z=z + 0.3)


def build(i):
    loaded = i < N
    ang = (i % N) * 15
    fig = Figure()
    wheel(fig, (-11, -7), 7, ang + 20, 0, True)                  # far wheels
    wheel(fig, (13, -7), 7, ang, 0, True)
    # chassis and bed
    fig.box((-20, -16, 22, -11), WOOD, z=1, bevel=1.0, grit=0.1)
    fig.capsule((-20, -11), (22, -11), 0.9, BRONZE, z=1.1)
    fig.capsule((22, -16), (26, -14), 1.0, STEEL, z=1.1)         # tow nose
    # boiler and crank at the back
    fig.ellipsoid((-15, -22), (5, 7), STEEL, z=1.5)
    fig.ellipsoid((-15, -28.5), (3.2, 1.2), BRONZE, z=1.6)
    fig.capsule((-15, -29), (-15, -33), 0.9, DARK, z=1.55)
    fig.disc((-15, -21), 2.4, DARK, z=1.7)
    fig.gear((-15, -21), 2.1, 7, (i % N) * 25, BRONZE, z=1.8)
    fig.sphere((-11, -26), 1.0, GLOW, z=1.9, emissive=True)
    # the boom: a brass arm hinged at the front of the bed
    fig.capsule((19, -16), (19, -24), 1.1, BRONZE, z=2.0)
    fig.sphere((19, -24), 1.6, STEEL, z=2.1)
    if loaded:
        # the folded bridge: stacked planks, a truss on its side
        for k in range(3):
            y = -18 - k * 3.2
            fig.box((-9, y - 2.4, 20, y), WOOD, z=2.2 + k * 0.05, bevel=0.6, grit=0.12)
        for x in range(-7, 20, 6):
            fig.capsule((x, -26.5), (x + 3, -18), 0.45, BRONZE, z=2.4)
        fig.capsule((-9, -26.5), (20, -26.5), 0.6, BRONZE, z=2.45)
    else:
        fig.capsule((19, -24), (4, -20), 0.9, STEEL, z=2.2)       # the boom folded back
    # near wheels
    wheel(fig, (-9, -7), 7, ang, 3, False)
    wheel(fig, (15, -7), 7, ang + 30, 3, False)
    return fig.render(FW, FH, O, extra=EXTRA)


def main():
    frames = [build(i) for i in range(2 * N)]
    write_png(SPR + 'bridger.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote bridger.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/bridger_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
