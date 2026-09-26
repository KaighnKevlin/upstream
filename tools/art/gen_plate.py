"""Pressure plate: a riveted brass plate in a steel frame, sunk flush with
the ground, with a little signal lamp on one end.

    python3 tools/art/gen_plate.py [preview_dir]

Writes assets/sprites/plate.png: 2 frames of 26x8, feet at (13, 7):
0 = up (lamp dark), 1 = pressed (plate down, lamp lit).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 26, 8, (13, 7)
LAMP = [(120, 60, 20), (230, 140, 40), (255, 210, 110), (255, 245, 200)]


def build(pressed):
    fig = Figure()
    fig.box((-12.5, -4, 12.5, 0), DARK, z=0, bevel=0.6)                   # frame
    d = 1.5 if pressed else 0.0
    fig.box((-9.5, -5.5 + d, 8.5, -2.5 + d), BRONZE, z=0.5, bevel=0.6)     # the plate
    for x in (-7.5, -2.5, 2.5, 6.5):
        fig.sphere((x, -4.2 + d), 0.5, STEEL, z=0.6)
    fig.sphere((10.8, -4.5), 1.3, LAMP if pressed else DARK, z=0.7, emissive=pressed)
    return fig.render(W, H, O, extra=['783c14', 'e68c28', 'ffd26e', 'fff5c8'])


def main():
    frames = [build(False), build(True)]
    write_png(SPR + 'plate.png', W * 2, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote plate.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 10)
        write_png(sys.argv[1] + '/plate_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
