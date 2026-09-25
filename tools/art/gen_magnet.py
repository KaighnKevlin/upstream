"""Electromagnet: a brass-capped iron drum wound with copper, hanging on a
short chain from a riveted bracket. Its face glows blue while it's on.

    python3 tools/art/gen_magnet.py [preview_dir]

Writes assets/sprites/magnet.png: 2 frames of 36x40 (off, on), the pull
point (the centre of the face) at the frame's (18, 34); the bracket at the
top is at (18, 2).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 36, 40, (18, 34)


def build(on):
    fig = Figure()
    # bracket and chain
    fig.box((-8, -34, 8, -30), BRONZE, z=0, bevel=1.0)
    for x in (-5, 5):
        fig.sphere((x, -32), 0.6, STEEL, z=0.1)
    for k in range(3):
        y = -29 + k * 3.2
        fig.ellipsoid((0, y), (1.0 if k % 2 else 1.6, 1.6), DARK, z=0.2)
    # drum: iron core, copper windings, brass caps
    fig.box((-11, -20, 11, -4), STEEL, z=1, bevel=2.5, grit=0.05)
    for k in range(5):
        y = -17 + k * 3
        fig.ellipsoid((0, y), (11.5, 1.3), COPPER, z=1.2 + k * 0.01, grit=0.04)
    fig.box((-12.5, -22, 12.5, -19), BRONZE, z=1.5, bevel=1.0)
    fig.box((-12.5, -5, 12.5, -2), BRONZE, z=1.5, bevel=1.0)
    for x in (-10, 10):
        fig.sphere((x, -20.5), 0.6, STEEL, z=1.6)
    # the pole face
    fig.box((-10, -2, 10, 1), DARK, z=1.7, bevel=0.5)
    if on:
        fig.ellipsoid((0, -0.4), (9, 1.4), GLOW, z=1.8, emissive=True)
        fig.sphere((-8, -12), 0.9, GLOW, z=1.9, emissive=True)
    else:
        fig.box((-9, -1.5, 9, 0.8), STEEL, z=1.8)
    return fig.render(FW, FH, O, extra=COPPER_EXTRA)


def main():
    frames = [build(False), build(True)]
    write_png(SPR + 'magnet.png', FW * 2, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote magnet.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/magnet_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
