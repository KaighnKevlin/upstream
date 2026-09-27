"""Cinder bat: a little clockwork bat from the hot depths. A soot-black
round body with a glowing ember chest, two tiny horn ears, and membrane
wings of riveted brass ribs with ember-lit webbing.

    python3 tools/art/gen_cinderbat.py [preview_dir]

Writes assets/sprites/cinderbat.png: 4 frames of 24x16, centred at
(12, 8): 0-2 flapping (up, mid, down), 3 folded (roosting, hanging).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 24, 16, (12, 8)
EMBER = [(120, 30, 10), (200, 70, 20), (250, 140, 40), (255, 210, 120)]
SOOT = [(29, 26, 24), (41, 38, 31), (60, 55, 50), (82, 74, 66)]


def build(i):
    fig = Figure()
    folded = i == 3
    lift = [-5.0, -1.0, 3.5][i] if not folded else 0.0
    for side in (-1, 1):
        if folded:
            fig.ellipsoid((side * 3.0, 1.0), (2.2, 4.5), SOOT, z=0.5)
            fig.capsule((side * 3.0, -3.0), (side * 3.4, 4.5), 0.45, BRONZE, z=0.6)
            continue
        tip = (side * 11.0, lift)
        elbow = (side * 6.0, lift * 0.5 - 2.0)
        # webbing: a fan of triangles between the ribs
        fig.poly([(side * 2.5, -1.0), elbow, tip, (side * 8.5, lift * 0.6 + 2.5), (side * 4.0, 2.0)], EMBER, z=0.3, shade=0.3)
        fig.capsule((side * 2.5, -1.0), elbow, 0.55, BRONZE, z=0.6)
        fig.capsule(elbow, tip, 0.45, BRONZE, z=0.6)
        fig.capsule(elbow, (side * 8.5, lift * 0.6 + 2.5), 0.35, BRONZE, z=0.6)
    fig.sphere((0, 0.5), 3.6, SOOT, z=1, grit=0.1)
    fig.sphere((0, 1.8), 1.6, EMBER, z=1.2, emissive=True)               # ember chest
    for side in (-1, 1):
        fig.poly([(side * 1.2, -2.6), (side * 2.4, -5.8), (side * 2.8, -2.2)], SOOT, z=1.1)   # horn ears
        fig.sphere((side * 1.2, -0.6), 0.55, [(255, 190, 90)] * 2, z=1.3, emissive=True)      # eyes
    return fig.render(W, H, O, extra=['781e0a', 'c84614', 'fa8c28', 'ffd278', '1d1a18', '29261f', '3c3732', '524a42', 'ffbe5a'])


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'cinderbat.png', W * 4, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote cinderbat.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/cinderbat_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
