"""Burrower: a clockwork mole. A riveted brass barrel body with steel
bands, a wind-up key on its back, a coiled-spring tail, steel digging
claws, a red lamp eye and a fluted steel drill for a nose.

    python3 tools/art/gen_burrower.py [preview_dir]

Writes assets/sprites/burrower.png: 4 frames of 38x24 in a row, facing +x,
the node origin at (19, 13) in each. Across the frames the drill's flutes
screw forward, the claws scratch and the key turns; the code steps them
while it moves (and turns/flips the sprite to its heading).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O, N = 38, 24, (19, 13), 4
RED_EXTRA = ['460e0c', 'a01e18', 'e64632', 'ffa082']
RED = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]
IRON = STEEL[:5]


def frame(k):
    fig = Figure()
    f = k / N
    # the tail: a coiled spring
    for i in range(3):
        cx = -13.5 - i * 2.4
        pts = [(cx + math.cos(a) * 1.3, -0.5 + math.sin(a) * 2.2) for a in [2 * math.pi * j / 8 for j in range(9)]]
        for p, q in zip(pts, pts[1:]):
            fig.capsule(p, q, 0.45, STEEL, z=-1)
    # the claws, scratching: the front pair and the back pair swing in turn
    s = math.sin(2 * math.pi * f) * 2.0
    for (x0, y0), sw in (((3, 4), s), ((-6, 5), -s)):
        fig.capsule((x0, y0), (x0 + 3.5 + sw, y0 + 4.2), 1.0, IRON, z=-0.5)
        fig.capsule((x0 + 3.5 + sw, y0 + 4.2), (x0 + 5.3 + sw, y0 + 4.4), 0.6, STEEL, z=-0.4)
    # the body: a brass barrel with steel hoops and rivets
    fig.ellipsoid((-2, 0), (11, 6.8), BRONZE, z=0)
    for x in (-7, 1):
        h = 6.8 * math.sqrt(max(0.0, 1 - ((x + 2) / 11) ** 2))
        fig.capsule((x, -h + 0.4), (x, h - 0.4), 0.8, STEEL, z=0.2)
    for x, y in ((-10, -2.5), (-10, 2.5), (-3.5, -4.5), (-3.5, 4.5)):
        fig.sphere((x, y), 0.6, STEEL, z=0.3)
    # the wind-up key on its back, turning (seen edge-on half the time)
    kw = abs(math.cos(math.pi * f)) * 3.6 + 0.6
    fig.capsule((-4, -6.5), (-4, -8.8), 0.6, STEEL, z=-0.2)
    fig.ellipsoid((-4, -10.3), (kw, 1.6), BRONZE, z=-0.1)
    # the collar the drill turns in
    fig.box((6, -5.4, 9, 5.4), IRON, z=0.4, bevel=0.8)
    # the drill: a steel cone with flutes that screw forward frame by frame
    fig.poly([(8.5, -4.8), (18, 0), (8.5, 4.8)], STEEL, z=0.5, shade=0.72, grit=0.02)
    fig.poly([(8.5, 0.6), (18, 0), (8.5, 4.8)], STEEL, z=0.52, shade=0.45, grit=0.02)
    for j in range(-1, 4):
        x = 9.0 + j * 3.0 + f * 3.0
        if 8.5 <= x < 16.5:
            h = 4.8 * (18 - x) / 9.5
            fig.capsule((x, -h), (min(x + 1.8, 17.5), h * 0.9), 0.38, IRON[:3], z=0.6)
    # the eye: a red lamp in a brass bezel
    fig.disc((3.5, -2.8), 2.0, BRONZE, z=0.7)
    fig.sphere((3.5, -2.8), 1.3, RED, z=0.8, emissive=True)
    return fig.render(FW, FH, O, extra=RED_EXTRA)


def main():
    frames = [frame(k) for k in range(N)]
    sheet = [sum((fr[y] for fr in frames), []) for y in range(FH)]
    write_png(SPR + 'burrower.png', FW * N, FH, sheet)
    print('wrote burrower.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/burrower_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
