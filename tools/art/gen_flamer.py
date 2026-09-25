"""Flame turret: a squat iron furnace on brass feet, an ore funnel on top
feeding the firebox, a glowing grate, a chimney, and a nozzle that swivels.

    python3 tools/art/gen_flamer.py [preview_dir]

Writes assets/sprites/flamer.png: 3 frames of 44x48 (the firebox glow
flickers), feet at the bottom centre (22, 47); the nozzle pivot is at
(6, -20) from the feet; the funnel mouth spans x -9..5 at y -46.
And flamer_nozzle.png (22x10, pivot at (4, 5), pointing right).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 44, 48, (22, 47)
IRON = [(41, 38, 31), (53, 60, 66), (58, 73, 74), (80, 92, 96), (95, 124, 131), (112, 144, 146)]
FIRE = [(90, 30, 12), (170, 60, 20), (230, 110, 40), (255, 180, 80), (255, 236, 170)]
EXTRA = ['353c42', '3a494a', '505c60', '5f7c83', '709092', '5a1e0c', 'aa3c14', 'e66e28', 'ffb450', 'ffecaa']


def build(i):
    fig = Figure()
    for x in (-11, 11):
        fig.ellipsoid((x, -1.5), (3.5, 1.5), BRONZE, z=0)
    # the furnace: a rounded iron box
    fig.box((-14, -34, 12, -3), IRON, z=1, bevel=3.0, grit=0.06)
    fig.box((-15, -35, 13, -32), BRONZE, z=1.2, bevel=1.0)
    for (x, y) in ((-12, -30), (10, -30), (-12, -6), (10, -6)):
        fig.sphere((x, y), 0.7, BRONZE, z=1.3)
    # firebox grate, glowing, flickering by frame
    fig.box((-10, -18, 2, -7), DARK, z=1.4, bevel=1.0)
    heat = (0.7, 1.0, 0.85)[i]
    fig.ellipsoid((-4, -11), (5.5 * heat, 3.0), FIRE, z=1.5, emissive=True)
    for x in (-8, -5, -2, 1):
        fig.capsule((x, -17), (x, -8), 0.5, DARK, z=1.6)
    # chimney at the back with a brass cap
    fig.capsule((-11, -34), (-11, -44), 2.2, IRON, z=0.8)
    fig.ellipsoid((-11, -45), (3.2, 1.2), BRONZE, z=0.9)
    # ore funnel on top
    fig.poly([(-9, -46), (5, -46), (1, -35), (-5, -35)], STEEL, z=2, shade=0.7)
    fig.poly([(-7.5, -45.5), (3.5, -45.5), (0, -36), (-4, -36)], DARK, z=2.05, shade=0.3)
    fig.capsule((-9.5, -46), (5.5, -46), 0.8, BRONZE, z=2.1)
    # nozzle mount on the front
    fig.disc((6, -20), 4.0, BRONZE, z=2.2)
    fig.disc((6, -20), 2.0, DARK, z=2.3)
    return fig.render(FW, FH, O, extra=EXTRA)


def nozzle():
    fig = Figure()
    fig.capsule((0, 0), (13, 0), 2.2, IRON, z=0)
    fig.capsule((13, 0), (16, 0), 3.0, BRONZE, z=0.1)        # flared tip
    fig.capsule((4, -2.2), (10, -2.2), 0.6, BRONZE, z=0.2)   # pilot line
    fig.sphere((16.5, 0), 1.2, FIRE, z=0.3, emissive=True)  # pilot flame
    return fig.render(22, 10, (4, 5), extra=EXTRA)


def main():
    frames = [build(i) for i in range(3)]
    write_png(SPR + 'flamer.png', FW * 3, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    write_png(SPR + 'flamer_nozzle.png', 22, 10, nozzle())
    print('wrote flamer.png, flamer_nozzle.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames + [nozzle()], 6)
        write_png(sys.argv[1] + '/flamer_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
