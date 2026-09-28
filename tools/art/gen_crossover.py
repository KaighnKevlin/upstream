"""Crossover: two steel rails crossing in an X like a railway diamond,
each a running bar on a brass web, end-capped, with a riveted brass boss
clamping them where they cross.

    python3 tools/art/gen_crossover.py [preview_dir]

Writes assets/sprites/crossover.png (78x54, the piece's origin, the
crossing point of the marbles' paths, at (39, 20)). The rails run under
those paths, 7 px down: (-34, -15) -> (34, 29) and (34, -15) -> (-34, 29),
their top face on the line; the boss is centred on (0, 7).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def crossover():
    fig = Figure()
    ang = math.degrees(math.atan2(44, 68))
    half = math.hypot(68, 44) / 2
    for s, z in ((1, 0), (-1, 0.5)):
        t = ang * s
        n = (-math.sin(math.radians(t)), math.cos(math.radians(t)))     # the rail's "down"
        cx, cy = 0 + n[0] * 1.2, 7 + n[1] * 1.2
        fig.box((cx - half, cy - 1.4, cx + half, cy + 1.4), STEEL, z=z + 0.2, bevel=0.7, grit=0.03, tilt=t)
        wx, wy = cx + n[0] * 2.4, cy + n[1] * 2.4
        fig.box((wx - half + 2, wy - 1.1, wx + half - 2, wy + 1.1), BRONZE, z=z, bevel=0.5, tilt=t)
        for e in (-1, 1):                                                 # end caps
            d = (math.cos(math.radians(t)) * e * (half - 1), math.sin(math.radians(t)) * e * (half - 1))
            fig.box((cx + d[0] - 1.2, cy + d[1] - 2, cx + d[0] + 1.2, cy + d[1] + 2.6), STEEL, z=z + 0.3, bevel=0.5, tilt=t)
    fig.disc((0, 8), 5.5, BRONZE, z=2)
    fig.disc((0, 8), 2.4, STEEL, z=2.1)
    for k in range(4):
        a = math.radians(k * 90 + 45)
        fig.sphere((math.cos(a) * 3.9, 8 + math.sin(a) * 3.9), 0.6, STEEL, z=2.2)
    return fig.render(78, 54, (39, 20))


def main():
    c = crossover()
    write_png(SPR + 'crossover.png', 78, 54, c)
    print('wrote crossover.png')
    if len(sys.argv) > 1:
        big = side_by_side([c], 6)
        write_png(sys.argv[1] + '/crossover_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
