"""Bowl feeder: a shallow iron bowl on a sprung, buzzing base, cut away so
the pile inside and the spiral ledge up its back wall show, drawn in two
layers so the pieces the code carries sit between them.

    python3 tools/art/gen_bowl_feeder.py [preview_dir]

Writes (all measured from the node origin, the floor under the base's
middle; drawn for side = +1, the exit on the right; the code flips both
sprites for side = -1):
- bowl_feeder_back.png   50x50, origin (25, 64): the bowl's inside (x -23..23,
  y -64..-15): the dark back wall, the far half of the rim, the reject hole
  low on the left (-19, -19) and the brass spiral ledge, a zig-zag of six
  runs from (16, -20) up to (16, -57) and out over the rim to (23, -58)
  (LEDGE below, the code's path; pieces ride on its top edge).
- bowl_feeder_front.png  80x68, origin (40, 66): drawn over the pieces: the
  bowl's near edge (a thin wall outline and the near half of the rim), the
  exit lip (x 20..36, sloping down from y -59 to -54), the reject spout at
  the bottom left, and the base: an iron drive block with a brass coil
  between two leaf springs, on a riveted foot plate (y -3..0).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]
# the ledge's path, as the code has it (bowl_feeder.gd LEDGE)
LEDGE = [(16, -20), (-16, -26.2), (16, -32.3), (-16, -38.5), (16, -44.7), (-16, -50.8), (16, -57), (23, -58)]
# the bowl's profile, left rim to right rim, round the bottom
PROFILE = [(-23, -60), (-22.5, -44), (-21, -30), (-18, -20), (-12, -16), (12, -16), (18, -20), (21, -30), (22.5, -44), (23, -60)]


def back():
    fig = Figure()
    fig.poly(PROFILE, DARK, z=0, shade=0.55, grit=0.06)
    # faint bands where the bowl was spun
    for y in (-52, -41, -30):
        fig.capsule((-20, y), (20, y), 0.35, DARK, z=0.1)
    # the far half of the rim
    for i in range(12):
        a0, a1 = math.pi + i * math.pi / 12, math.pi + (i + 1) * math.pi / 12
        fig.capsule((23 * math.cos(a0), -60 + 3 * math.sin(a0)), (23 * math.cos(a1), -60 + 3 * math.sin(a1)), 0.8, IRON, z=0.2)
    # the reject hole
    fig.ellipsoid((-18.5, -19.5), (2.2, 2.6), [OUTLINE, OUTLINE, DARK[2]], z=0.3)
    # the ledge: a brass strip under the path, a darker lip beneath
    for a, b in zip(LEDGE, LEDGE[1:]):
        fig.capsule((a[0], a[1] + 2.2), (b[0], b[1] + 2.2), 0.9, DARK, z=0.4)
        fig.capsule((a[0], a[1] + 1.1), (b[0], b[1] + 1.1), 1.0, BRONZE, z=0.5)
    return fig.render(50, 50, (25, 64))


def front():
    fig = Figure()
    # the near wall, a thin outline round the cutaway
    for a, b in zip(PROFILE, PROFILE[1:]):
        fig.capsule(a, b, 1.1, STEEL, z=0.2)
    # the near half of the rim, brass-bound
    for i in range(12):
        a0, a1 = i * math.pi / 12, (i + 1) * math.pi / 12
        fig.capsule((23 * math.cos(a0), -60 + 3 * math.sin(a0)), (23 * math.cos(a1), -60 + 3 * math.sin(a1)), 1.0, BRONZE, z=0.3)
    # the exit lip, sloping off the rim
    fig.capsule((20, -58.5), (36, -53.5), 1.5, STEEL, z=0.4)
    fig.capsule((21, -58.8), (35, -54.4), 0.5, BRONZE, z=0.45)
    fig.capsule((35.5, -56), (35.5, -52.5), 0.8, STEEL, z=0.42)
    # the reject spout, low on the left
    fig.box((-27, -21.5, -20, -17.5), IRON, z=0.4, bevel=0.8)
    fig.sphere((-21.5, -19.5), 0.6, BRONZE, z=0.45)
    # the base: leaf springs up to the bowl, a brass drive coil between
    for s in (-1, 1):
        fig.box((s * 11 - 1.2, -17, s * 11 + 1.2, -9), STEEL, z=0.1, bevel=0.6, tilt=s * -14)
    fig.box((-14, -11, 14, -3), IRON, z=0.2, bevel=1.0)
    fig.ellipsoid((0, -11), (5.5, 3.5), BRONZE, z=0.3)
    for x in (-3, 0, 3):
        fig.capsule((x, -13.6), (x, -8.6), 0.4, DARK, z=0.35)
    fig.box((-17, -3.2, 17, 0), DARK + STEEL[3:6], z=0.3, bevel=0.8)
    for x in (-14, 14):
        fig.sphere((x, -1.6), 0.7, BRONZE, z=0.35)
    return fig.render(80, 68, (40, 66))


def marble(mat, extra=()):
    fig = Figure()
    fig.sphere((0, 0), 6.0, mat, z=0)
    return fig.render(13, 13, (6.5, 6.5), extra=extra)


def main():
    b, f = back(), front()
    write_png(SPR + 'bowl_feeder_back.png', 50, 50, b)
    write_png(SPR + 'bowl_feeder_front.png', 80, 68, f)
    print('wrote bowl_feeder_back.png, bowl_feeder_front.png')
    if len(sys.argv) > 1:
        # assembled as the game draws it: a few on the ledge, a pile below
        comp = [[(0, 0, 0, 0)] * 80 for _ in range(68)]
        for y in range(50):
            for x in range(50):
                if b[y][x][3]:
                    comp[y + 2][x + 15] = b[y][x]
        cu, fe = marble(COPPER, COPPER_EXTRA), marble(IRON)
        at = [(-9, -22.5, cu), (-2, -22.5, fe), (5, -22.5, cu), (-5, -28, cu), (0, -30.7, fe), (-8, -46.5, cu), (10, -63.5, fe)]
        for cx, cy, m in at:
            ox, oy = int(cx - 6.5) + 40, int(cy - 6.5) + 66
            for y in range(13):
                for x in range(13):
                    if m[y][x][3]:
                        comp[y + oy][x + ox] = m[y][x]
        for y in range(68):
            for x in range(80):
                if f[y][x][3]:
                    comp[y][x] = f[y][x]
        big = side_by_side([b, f, comp], 6)
        write_png(sys.argv[1] + '/bowl_feeder_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
