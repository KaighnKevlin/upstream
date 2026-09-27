"""Clockwork sparrow: a little wind-up bird, round brass body, a key in its
back, steel beak, a bright bead eye.

    python3 tools/art/gen_sparrow.py [preview_dir]

Writes assets/sprites/sparrow.png: 5 frames of 14x12, facing right, feet at
(7, 11): 0 standing, 1 pecking (head down), 2-4 flapping (wings up, mid,
down).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 14, 12, (7, 11)
EYE = [(20, 20, 20), (60, 60, 60), (230, 230, 220), (255, 255, 250)]


def build(i):
    fig = Figure()
    fly = i >= 2
    peck = i == 1
    by = -4.5 if not fly else -5.5
    if not fly:
        for x in (-0.8, 0.8):
            fig.capsule((x, by + 2.0), (x, -0.4), 0.3, DARK, z=0)
    fig.ellipsoid((0, by), (3.4, 2.6), BRONZE, z=1, grit=0.05)       # body
    fig.poly([(-2.8, by - 0.5), (-5.8, by - 1.8 if not fly else by + 0.2), (-3.0, by + 0.8)], BRONZE, z=0.9)   # tail
    hx, hy = (3.0, by - 1.0) if peck else (2.6, by - 2.4)
    if peck:
        hx, hy = 3.4, by + 0.6
    fig.sphere((hx, hy), 1.8, BRONZE, z=1.2)
    fig.poly([(hx + 1.4, hy - 0.4), (hx + 3.2, hy + (0.8 if peck else 0.1)), (hx + 1.4, hy + 0.6)], STEEL, z=1.3)
    fig.sphere((hx + 0.6, hy - 0.5), 0.45, EYE, z=1.4, emissive=True)
    fig.capsule((-1.2, by - 2.4), (-1.9, by - 3.9), 0.3, STEEL, z=0.8)   # wind-up key
    if fly:
        lift = [-3.5, -0.5, 2.0][i - 2]
        fig.poly([(-1.2, by - 0.6), (0.8, by - 0.6), (-2.5, by - 0.6 + lift - 1.5)], STEEL, z=1.5)
    else:
        fig.ellipsoid((-0.5, by + 0.2), (2.0, 1.2), STEEL, z=1.1)
    return fig.render(W, H, O, extra=['141414', '3c3c3c', 'e6e6dc', 'fffffa'])


def main():
    frames = [build(i) for i in range(5)]
    write_png(SPR + 'sparrow.png', W * 5, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote sparrow.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 10)
        write_png(sys.argv[1] + '/sparrow_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
