"""Ground listener: a brass ear trumpet on a steel plate bolted to the rock:
its bell flared flat on the stone, the horn curling up and over to an
earpiece, and a round ivory-faced dial where the horn leaves the bell (the
code draws the range marks, the needle, the arrow and the rings).

    python3 tools/art/gen_ground_listener.py [preview_dir]

Writes ground_listener.png (32x25, the node origin at (14, 23): the plate
x -12..12, y -3..0, bolts at (+-9, -1.5); the bell y -9..-2; the horn an
arc about (6, -14) radius 6 from (0, -9) over to (12, -14), the earpiece
at (13, -12); the dial's centre (0, -14) radius 6.5).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]


def body():
    fig = Figure()
    # the plate, bolted to the rock
    fig.box((-12.5, -3.2, 12.5, 0.2), STEEL, z=0, bevel=0.8)
    for x in (-9.5, 9.5):
        fig.sphere((x, -1.5), 1.0, BRONZE, z=0.1)
    # the bell, flared down onto the stone (lit from the left: a brighter
    # left flank, a darker right one)
    fig.poly([(-9.5, -2.5), (0, -2.5), (0, -9.3), (-4, -9.3)], BRONZE, z=1, shade=0.72)
    fig.poly([(0, -2.5), (9.5, -2.5), (4, -9.3), (0, -9.3)], BRONZE, z=1, shade=0.5)
    fig.box((-10, -3.8, 10, -2.2), BRONZE, z=1.1, bevel=0.6)          # its rolled lip
    # the horn, curling up and over to the earpiece, flaring a little
    pts = [(0, -9)]
    for i in range(1, 9):
        a = math.pi * (1 - i / 8)
        pts.append((6 + math.cos(a) * 6, -14 - math.sin(a) * 6))
    for k, (p, q) in enumerate(zip(pts, pts[1:])):
        fig.capsule(p, q, 1.5 - k * 0.07, BRONZE, z=0.5)
    fig.capsule((12, -14), (13, -12.5), 1.0, BRONZE, z=0.6)
    fig.disc((13, -12), 2.4, BRONZE, z=0.7)                            # the earpiece
    fig.disc((13, -12), 1.2, DARK, z=0.8)
    # the dial: a plain face, the code draws everything on it
    fig.disc((0, -14), 6.6, STEEL, z=2)
    fig.disc((0, -14), 5.3, IVORY, z=2.1)
    return fig.render(32, 25, (14, 23), extra=IVORY_EXTRA)


def main():
    b = body()
    write_png(SPR + 'ground_listener.png', 32, 25, b)
    print('wrote ground_listener.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/ground_listener_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
