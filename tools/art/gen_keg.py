"""Powder keg: a squat oak barrel of blasting powder bound in steel hoops,
a brass fuse cap on top and a red warning band.

    python3 tools/art/gen_keg.py [preview_dir]

Writes assets/sprites/keg.png: 2 frames of 22x26, feet at (11, 25):
0 = resting, 1 = lit (the fuse cap glowing).
"""
import sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c', '8d7051')]
RED = [(70, 14, 12), (130, 26, 20), (180, 40, 30), (220, 70, 50)]
HOT = [(160, 60, 20), (230, 120, 40), (255, 200, 90), (255, 240, 180)]
W, H, O = 22, 26, (11, 25)


def build(lit):
    fig = Figure()
    # the barrel: a fat ellipse clipped by staves (a box over it for the flat ends)
    fig.ellipsoid((0, -11), (9.2, 11.5), WOOD, z=0, grit=0.12)
    for x in (-5.5, -1.8, 1.8, 5.5):                                   # stave seams
        fig.capsule((x * 0.95, -20.5), (x, -1.5), 0.25, DARK, z=0.2)
    for y in (-19.0, -3.0):                                           # steel hoops
        fig.capsule((-8.2, y), (8.2, y), 0.9, STEEL, z=0.4)
    fig.capsule((-9.0, -11), (9.0, -11), 1.5, RED, z=0.35)            # warning band
    fig.poly([(-2.2, -13.3), (2.2, -13.3), (0, -8.8)], DARK, z=0.5)  # hazard mark
    fig.box((-6.5, -23, 6.5, -20.5), WOOD, z=0.3, bevel=0.8)          # lid
    fig.box((-1.6, -25, 1.6, -22), BRONZE, z=0.6, bevel=0.5)          # fuse cap
    if lit:
        fig.sphere((0, -24.5), 1.3, HOT, z=1.0, emissive=True)
    return fig.render(W, H, O, extra=['460e0c', '821a14', 'b4281e', 'dc4632', 'a03c14', 'e67828', 'ffc85a', 'fff0b4'])


def main():
    frames = [build(False), build(True)]
    write_png(SPR + 'keg.png', W * 2, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote keg.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/keg_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
