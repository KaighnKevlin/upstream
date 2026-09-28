"""Plunger: a pinball-style spring launcher. A brass-railed barrel with a
dark bore you see the spring through, a steel collar at the mouth; the
coil spring (the code squashes it as it's drawn back), the brass piston
head that rides on it, and the rod and red knob under the barrel.

    python3 tools/art/gen_plunger.py [preview_dir]

Writes (node coords: the barrel's foot at y 0-4, its mouth at y -30):
- plunger_barrel.png  24x40, the node origin at (12, 33): the bore
  x -6..6, y -28..1.
- plunger_spring.png  12x22, its foot (node (0, 0)) at (6, 22); drawn
  full length (22 px), the code scales it in y to the piston.
- plunger_head.png    14x6, the piston's top face (node (0, top - 4)) at
  (7, 1); it sits over the spring's top.
- plunger_knob.png    14x27, the knob's centre at (7, 19); the rod runs 18
  px up from it (into the barrel, which hides it).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

RED_EXTRA = ['4a1a16', '7a2620', 'a8382c', 'cc5a44', 'e88a6c']
RED = [(74, 26, 22), (122, 38, 32), (168, 56, 44), (204, 90, 68), (232, 138, 108)]


def barrel():
    fig = Figure()
    fig.box((-7, -29, 7, 2), DARK, z=0, bevel=0.5, grit=0.03)              # the bore
    fig.box((-5.5, -28, 5.5, 1), STEEL[:4], z=0.05, bevel=3.0, grit=0.03)  # its curved back wall, in shadow
    for s in (-1, 1):
        fig.box((s * 8 - 1.6, -28, s * 8 + 1.6, 2), BRONZE, z=1, bevel=0.8)   # rails
        for y in (-20, -8):
            fig.sphere((s * 8, y), 0.55, STEEL, z=1.1)
    fig.box((-10, -31.5, 10, -27.5), STEEL, z=2, bevel=0.8)                # the mouth collar
    fig.box((-6.5, -30.8, 6.5, -28.2), DARK, z=2.1, bevel=0.3)
    fig.box((-10, 1, 10, 4.5), STEEL, z=2, bevel=0.8)                      # foot cap
    fig.sphere((0, 2.8), 1.1, DARK, z=2.1)                                 # the rod's hole
    for x in (-8, 8):
        fig.sphere((x, 2.8), 0.55, BRONZE, z=2.2)
    return fig.render(24, 40, (12, 33))


def spring():
    fig = Figure()
    n = 7
    for k in range(n):
        y0 = -k * 22 / n - 0.8
        y1 = y0 - 22 / n * 0.5
        fig.capsule((-4.6, y0), (4.6, y1), 0.7, STEEL, z=1)                 # front of each coil
        fig.capsule((4.6, y1), (-4.6, y1 - 22 / n * 0.5), 0.55, STEEL[:5], z=0)   # back, in shadow
    return fig.render(12, 22, (6, 22), outline=False)


def head():
    fig = Figure()
    fig.box((-6, 0, 6, 4), BRONZE, z=0, bevel=0.9)
    fig.box((-3.5, -0.4, 3.5, 1.0), DARK, z=0.1, bevel=0.3)                # the cup the marble sits in
    return fig.render(14, 6, (7, 1))


def knob():
    fig = Figure()
    fig.capsule((0, -18), (0, -4), 1.2, STEEL, z=0)
    fig.box((-2.2, -6.5, 2.2, -4.2), BRONZE, z=0.2, bevel=0.6)             # ferrule
    fig.sphere((0, 0), 5.6, RED, z=0.5)
    fig.sphere((-1.8, -1.8), 1.2, RED[2:], z=0.6)                           # a glint
    return fig.render(14, 27, (7, 19), extra=RED_EXTRA)


def main():
    b, s, h, k = barrel(), spring(), head(), knob()
    write_png(SPR + 'plunger_barrel.png', 24, 40, b)
    write_png(SPR + 'plunger_spring.png', 12, 22, s)
    write_png(SPR + 'plunger_head.png', 14, 6, h)
    write_png(SPR + 'plunger_knob.png', 14, 27, k)
    print('wrote plunger_barrel.png, plunger_spring.png, plunger_head.png, plunger_knob.png')
    if len(sys.argv) > 1:
        # composite at rest: knob, barrel, spring, head
        W, H, O = 24, 52, (12, 33)
        img = [[(0, 0, 0, 0)] * W for _ in range(H)]

        def put(src, at):
            for y, row in enumerate(src):
                for x, px in enumerate(row):
                    X, Y = x + at[0] + O[0], y + at[1] + O[1]
                    if px[3] and 0 <= X < W and 0 <= Y < H:
                        img[Y][X] = px
        put(k, (-7, 12 - 19))
        put(b, (-12, -33))
        put(s, (-6, -22))
        put(h, (-7, -26 - 1))
        big = side_by_side([b, s, h, k, img], 6)
        write_png(sys.argv[1] + '/plunger_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
