"""Crusher: a squat riveted iron housing with two big toothed rollers turning
into each other on top. Ore dropped between them comes out of the spout as
grit; anything that stands on them gets chewed.

    python3 tools/art/gen_crusher.py [preview_dir]

Writes assets/sprites/crusher.png: 4 frames of 52x40, feet at the bottom
centre (26, 39); the rollers' tops are at y -30 from the feet, spanning
x -20..20; the spout is on the right at (22, -8).
And grit.png: 3 variants of 6x6 (small angular chips).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 52, 40, (26, 39)
N = 4


def build(i):
    fig = Figure()
    for x in (-14, 14):
        fig.ellipsoid((x, -1.5), (3.5, 1.5), BRONZE, z=0)
    # housing
    fig.box((-21, -22, 21, -3), STEEL, z=1, bevel=2.0, grit=0.06)
    fig.box((-22, -23, 22, -20), BRONZE, z=1.1, bevel=0.8)
    for x in (-18, -9, 0, 9, 18):
        fig.sphere((x, -6), 0.6, BRONZE, z=1.2)
    fig.box((-8, -17, 8, -9), DARK, z=1.2, bevel=0.8)                       # inspection hatch
    fig.gear((0, -13), 3.0, 8, i * 22.5, BRONZE, z=1.3)
    # spout on the right
    fig.capsule((18, -10), (24, -7), 2.4, STEEL, z=1.4)
    fig.disc((24.5, -7), 1.6, DARK, z=1.5)
    # the two rollers, turning inward (left clockwise, right anticlockwise)
    for cx, sgn in ((-10, 1), (10, -1)):
        fig.gear((cx, -27), 9.5, 10, sgn * i * 9, STEEL, z=2)
        fig.disc((cx, -27), 6.0, DARK, z=2.1)
        fig.gear((cx, -27), 4.8, 6, -sgn * i * 15, BRONZE, z=2.2)
        fig.sphere((cx, -27), 1.4, STEEL, z=2.3)
    # side cheeks holding the axles
    for x in (-21, 21):
        fig.box((x - 1.5, -32, x + 1.5, -20), BRONZE, z=2.4, bevel=0.7)
    return fig.render(FW, FH, O)


def grit(seed):
    fig = Figure()
    r = [1.6 + ((seed * 7 + k * 3) % 5) * 0.25 for k in range(5)]
    pts = [(math.cos(k / 5 * math.tau + seed) * r[k], math.sin(k / 5 * math.tau + seed) * r[k]) for k in range(5)]
    fig.poly(pts, ROCK, z=0, shade=0.8)
    return fig.render(6, 6, (3, 3))


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'crusher.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    g = [grit(s) for s in (1, 2, 3)]
    write_png(SPR + 'grit.png', 18, 6, [sum((f[y] for f in g), []) for y in range(6)])
    print('wrote crusher.png, grit.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames + g, 5)
        write_png(sys.argv[1] + '/crusher_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
