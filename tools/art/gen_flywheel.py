"""Flywheel: a heavy cast-iron wheel (a thick rim, five spokes, a brass
hub, a brass balance weight on the rim so the spin reads) and the riveted
A-frame it turns on.

    python3 tools/art/gen_flywheel.py [preview_dir]

Writes flywheel_disc.png (44x44, the axle at the centre (22, 22), rim
radius 20; the code rotates it about its centre) and flywheel_frame.png
(40x40, the axle at (20, 6); the legs run to (+-14, 30) and the foot plate
is on the row +30).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def disc():
    fig = Figure()
    fig.disc((0, 0), 20.2, STEEL[:7], z=0)                                # the rim's face
    fig.disc((0, 0), 16.0, STEEL[:5], z=0.1)                              # its inner bevel, in shadow
    fig.disc((0, 0), 14.6, STEEL[:3], z=0.2)                              # the recess between the spokes
    for k in range(5):
        a = math.radians(k * 72 - 90)
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * 3, s * 3), (c * 15, s * 15), 1.6, STEEL, z=0.3)  # spokes
    for k in range(10):
        a = math.radians(k * 36 + 18)
        fig.sphere((math.cos(a) * 18.1, math.sin(a) * 18.1), 0.55, STEEL[2:], z=0.4)   # rim bolts
    a = math.radians(-90 + 36)
    fig.box((math.cos(a) * 17.9 - 2.4, math.sin(a) * 17.9 - 1.3, math.cos(a) * 17.9 + 2.4, math.sin(a) * 17.9 + 1.3),
            BRONZE, z=0.5, bevel=0.6, tilt=math.degrees(a) + 90)          # the balance weight
    fig.disc((0, 0), 5.0, BRONZE, z=0.6)                                  # hub
    fig.disc((0, 0), 2.2, STEEL, z=0.7)
    fig.sphere((-0.5, -0.5), 0.8, BRONZE, z=0.8)
    return fig.render(44, 44, (22, 22))


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 2, 0), (s * 14, 29), 1.8, BRONZE, z=0)           # legs
        fig.box((s * 14 - 3, 27.5, s * 14 + 3, 29.5), STEEL, z=0.2, bevel=0.5)   # feet
    fig.capsule((-9, 18), (9, 18), 0.9, DARK, z=-0.1)                     # cross brace
    fig.box((-18.5, 28.5, 18.5, 31.5), STEEL, z=0.1, bevel=0.7)          # foot plate
    for x in (-15, -5, 5, 15):
        fig.sphere((x, 30), 0.6, BRONZE, z=0.3)
    fig.box((-4.5, -4.5, 4.5, 4.5), BRONZE, z=0.4, bevel=1.2)            # bearing block
    return fig.render(40, 40, (20, 6))


def main():
    d, f = disc(), frame()
    write_png(SPR + 'flywheel_disc.png', 44, 44, d)
    write_png(SPR + 'flywheel_frame.png', 40, 40, f)
    print('wrote flywheel_disc.png, flywheel_frame.png')
    if len(sys.argv) > 1:
        W, H = 44, 58
        img = [[(0, 0, 0, 0)] * W for _ in range(H)]
        for y in range(40):
            for x in range(40):
                if f[y][x][3]: img[y + 16][x + 2] = f[y][x]
        for y in range(44):
            for x in range(44):
                if d[y][x][3]: img[y][x] = d[y][x]
        big = side_by_side([d, f, img], 6)
        write_png(sys.argv[1] + '/flywheel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
