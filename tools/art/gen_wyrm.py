"""Magma wyrm: a segmented clockwork worm from the depths. Blackened iron
rings joined by bronze collars, molten seams glowing between the plates,
a drill-toothed head with ember eyes and a spiked tail.

    python3 tools/art/gen_wyrm.py [preview_dir]

Writes assets/sprites/wyrm.png: 3 frames of 28x28, each centred at (14, 14)
and facing right (+x = the way it moves): 0 = head, 1 = body ring, 2 = tail.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 28, 28, (14, 14)
IRON = [(29, 26, 24), (41, 38, 31), (58, 56, 60), (79, 76, 80), (104, 102, 106)]
MELT = [(150, 40, 10), (220, 90, 25), (255, 160, 50), (255, 225, 140)]


def head():
    fig = Figure()
    fig.ellipsoid((-2, 0), (9.5, 9.0), IRON, z=0, grit=0.1)
    for s in (-1, 1):                                     # jaw plates
        fig.poly([(3, s * 2.0), (13, s * 6.5), (12, s * 1.0)], IRON, z=0.5)
        for k in range(3):                                # teeth
            x = 5 + k * 2.6
            fig.poly([(x, s * (2.2 + k * 1.1)), (x + 1.3, s * (0.4 + k * 0.9)), (x + 2.2, s * (2.6 + k * 1.1))], STEEL, z=0.6)
    fig.ellipsoid((5, 0), (4.0, 2.0), MELT, z=0.4, emissive=True)          # the furnace throat
    for s in (-1, 1):
        fig.sphere((1.0, s * 5.2), 1.4, MELT, z=0.8, emissive=True)        # eyes
    fig.gear((-6, 0), 3.2, 8, 0, BRONZE, z=0.7)
    for a in range(40, 330, 45):
        r = math.radians(a + 180)
        fig.sphere((-2 + math.cos(r) * 7.8, math.sin(r) * 7.6), 0.6, BRONZE, z=0.3)
    return fig.render(W, H, O, extra=['1d1a18', '29261f', '3a383c', '4f4c50', '68666a', '962808', 'dc5a19', 'ffa032', 'ffe18c'])


def body():
    fig = Figure()
    fig.ellipsoid((0, 0), (7.5, 8.5), IRON, z=0, grit=0.1)
    fig.capsule((-3.5, -8), (-3.5, 8), 1.4, BRONZE, z=0.3)                 # collar
    fig.capsule((2.2, -7.2), (2.2, 7.2), 0.9, MELT, z=0.2)                 # molten seam
    for y in (-5.5, 0, 5.5):
        fig.sphere((-3.5, y), 0.6, STEEL, z=0.4)
    fig.poly([(-1, -8.2), (1.5, -11.5), (3, -8.0)], IRON, z=0.1)          # dorsal spikes
    fig.poly([(-1, 8.2), (1.5, 11.5), (3, 8.0)], IRON, z=0.1)
    return fig.render(W, H, O, extra=['1d1a18', '29261f', '3a383c', '4f4c50', '68666a', '962808', 'dc5a19', 'ffa032', 'ffe18c'])


def tail():
    fig = Figure()
    fig.ellipsoid((2, 0), (5.5, 6.0), IRON, z=0, grit=0.1)
    fig.poly([(-2, -3.5), (-13, 0), (-2, 3.5)], IRON, z=0.2)
    fig.capsule((4.5, -5.5), (4.5, 5.5), 1.0, BRONZE, z=0.3)
    fig.capsule((-2, 0), (-11, 0), 0.5, MELT, z=0.25)
    return fig.render(W, H, O, extra=['1d1a18', '29261f', '3a383c', '4f4c50', '68666a', '962808', 'dc5a19', 'ffa032', 'ffe18c'])


def main():
    frames = [head(), body(), tail()]
    write_png(SPR + 'wyrm.png', W * 3, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote wyrm.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/wyrm_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
