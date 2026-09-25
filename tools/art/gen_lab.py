"""Research lab: a brass apparatus under a glass bell jar. Flasks dropped in
its funnel are poured into the jar, where the tincture bubbles and glows as
research runs.

    python3 tools/art/gen_lab.py [preview_dir]

Writes assets/sprites/lab.png: 4 frames of 48x58, feet at the bottom centre
(24, 57). Funnel mouth x -9..9 at y -56, on the left shoulder of the jar.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 48, 58, (24, 57)
N = 4
GLASS = [(41, 38, 31), (74, 96, 104), (112, 150, 158), (160, 196, 200), (205, 228, 230)]
# the jar: dark, tinted see-through glass (the night shows through)
JAR = [(41, 38, 31), (44, 52, 58), (52, 66, 72), (66, 86, 92), (96, 126, 132)]
RED = [(60, 18, 20), (120, 30, 32), (180, 52, 44), (230, 92, 64), (255, 160, 110)]
EXTRA = ['2c343a', '344248', '42565c', '607e84', '4a6068', '70969e', 'a0c4c8', 'cde4e6', '3c1214', '781e20', 'b4342c', 'e65c40', 'ffa06e']


def build(i):
    fig = Figure()
    # base: a brass plinth on claw feet
    for x in (-14, 14):
        fig.ellipsoid((x, -1.5), (3.5, 1.6), BRONZE, z=0)
    fig.box((-16, -12, 16, -3), BRONZE, z=1, bevel=2.0)
    fig.box((-13, -10, 13, -5), DARK, z=1.1, bevel=1.0)
    fig.gear((-7, -7.5), 2.2, 7, i * 25, STEEL, z=1.2)
    fig.gear((7, -7.5), 2.2, 7, -i * 25, STEEL, z=1.2)
    # the bell jar: glass dome over a pool of tincture
    fig.ellipsoid((0, -28), (12, 16), JAR, z=2, grit=0.01)
    fig.ellipsoid((0, -19), (10.5, 6.5), RED, z=2.2, emissive=True)
    for k in range(3):   # bubbles rising, offset per frame
        y = -20 - ((i * 4 + k * 6) % 16)
        x = (-5, 1, 5)[k]
        fig.sphere((x, y), 0.9, [(255, 190, 150)] * 2, z=2.3, emissive=True)
    fig.ellipsoid((-5, -34), (1.5, 5), [(225, 240, 240)] * 2, z=2.4, emissive=True)   # glass highlight
    fig.ellipsoid((0, -43.5), (4, 1.6), BRONZE, z=2.5)                              # top boss
    fig.capsule((0, -45), (0, -49), 0.9, STEEL, z=2.5)
    fig.sphere((0, -50), 1.6, GLOW, z=2.6, emissive=True)                          # indicator lamp
    # funnel on the left shoulder, piped into the jar
    fig.poly([(-19, -56), (-3, -56), (-8, -48), (-14, -48)], STEEL, z=3, shade=0.7)
    fig.poly([(-17, -55), (-5, -55), (-9, -49), (-13, -49)], DARK, z=3.05, shade=0.3)
    fig.capsule((-19.5, -56), (-2.5, -56), 0.9, BRONZE, z=3.1)
    fig.capsule((-11, -48), (-8, -40), 1.1, STEEL, z=2.9)
    return fig.render(FW, FH, O, extra=EXTRA)


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'lab.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote lab.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/lab_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
