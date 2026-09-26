"""Cave crawler: a small clockwork spider that hangs from cave ceilings and
drops on whoever walks beneath. A round brass body, a glowing red eye
cluster, eight thin steel legs.

    python3 tools/art/gen_crawler.py [preview_dir]

Writes assets/sprites/crawler.png: 5 frames of 26x18, facing right, feet at
(13, 17): 0-3 scuttle (legs in alternating sets), 4 curled (hanging /
falling, legs drawn in).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 26, 18, (13, 17)
RED = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]


def build(i):
    fig = Figure()
    curled = i == 4
    ph = i / 4 * math.tau
    for k in range(4):
        for side in (-1, 1):
            base = (k * 1.4 - 2.4, -6.5)
            if curled:
                tip = (base[0] + side * 3, -4)
                knee = (base[0] + side * 4, -8)
            else:
                lift = max(0.0, math.sin(ph + k * 1.6 + (0 if side > 0 else math.pi))) * 2.5
                spread = 5.5 + abs(k - 1.5) * 1.6
                knee = (base[0] + side * spread * 0.6, -11 - lift * 0.3)
                tip = (base[0] + side * spread, -0.8 - lift)
            mat = STEEL if side > 0 else DARK
            z = 1 if side > 0 else 0
            fig.capsule(base, knee, 0.55, mat, z=z)
            fig.capsule(knee, tip, 0.45, mat, z=z + 0.01)
    fig.ellipsoid((-1.5, -8), (4.2, 3.4), BRONZE, z=0.5, grit=0.06)
    fig.ellipsoid((3.2, -8), (2.4, 2.1), BRONZE, z=0.6)
    fig.gear((-2, -8.5), 1.6, 6, i * 20, STEEL, z=0.65)
    for (x, y) in ((4.6, -9.0), (4.0, -7.4), (5.3, -7.8)):
        fig.sphere((x, y), 0.75, RED, z=1.5, emissive=True)
    return fig.render(FW, FH, O, extra=['460e0c', 'a01e18', 'e64632', 'ffa082'])


def main():
    frames = [build(i) for i in range(5)]
    write_png(SPR + 'crawler.png', FW * 5, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote crawler.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/crawler_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
