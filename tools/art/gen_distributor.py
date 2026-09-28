"""Rotary distributor: a steel hopper on brass clamps over a riveted brass
housing, with three steel-ringed lamp sockets for its outlets (the code
lights the next one); and the turning brass spout on its pivot cap.

    python3 tools/art/gen_distributor.py [preview_dir]

Writes distributor_body.png (40x50, the node origin at (20, 24): hopper
lips (+-16, -20) -> (+-7, -4), the pivot at (0, -2), lamp sockets at
(-16, 16), (0, 22) and (16, 16)) and distributor_spout.png (12x22, the
pivot at (6, 5); the spout points down, 14 px, and the code turns it).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def body():
    fig = Figure()
    fig.poly([(-16, -20), (16, -20), (7, -4), (-7, -4)], DARK, z=-1, shade=0.35)     # the hopper's back
    for s in (-1, 1):
        fig.capsule((s * 16, -20), (s * 7, -4), 1.5, STEEL, z=1)
        fig.box((s * 16 - 1.8, -22.4, s * 16 + 1.8, -19.2), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((s * 16, -20.8), 0.55, STEEL, z=1.2)
    # the housing the spout turns in, and the arms out to the lamp sockets
    for p in ((-16, 16), (0, 22), (16, 16)):
        fig.capsule((0, -2), p, 1.1, DARK, z=1.5)
        fig.disc(p, 3.6, STEEL, z=1.6)
        fig.disc(p, 2.4, DARK, z=1.7)
    fig.disc((0, -2), 7.5, BRONZE, z=2)
    fig.disc((0, -2), 5.6, DARK, z=2.1)
    for k in range(6):
        import math
        a = math.radians(k * 60 + 30)
        fig.sphere((math.cos(a) * 6.6, -2 + math.sin(a) * 6.6), 0.5, STEEL, z=2.2)
    return fig.render(40, 50, (20, 24))


def spout():
    fig = Figure()
    fig.box((-3.2, 0, 3.2, 14), BRONZE, z=0, bevel=2.6)
    fig.box((-3.8, 11.5, 3.8, 14.5), BRONZE, z=0.1, bevel=1.2)          # the lip
    fig.box((-2, 13.3, 2, 14.5), DARK, z=0.2, bevel=0.3)                 # its mouth
    fig.disc((0, 0), 4.2, STEEL, z=0.5)                                  # pivot cap
    fig.sphere((0, 0), 1.4, BRONZE, z=0.6)
    return fig.render(12, 22, (6, 5))


def main():
    b, s = body(), spout()
    write_png(SPR + 'distributor_body.png', 40, 50, b)
    write_png(SPR + 'distributor_spout.png', 12, 22, s)
    print('wrote distributor_body.png, distributor_spout.png')
    if len(sys.argv) > 1:
        comp = [row[:] for row in b]
        for y in range(22):
            for x in range(12):
                if s[y][x][3]:
                    comp[y - 5 + 22][x - 6 + 20] = s[y][x]
        big = side_by_side([b, s, comp], 8)
        write_png(sys.argv[1] + '/distributor_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
