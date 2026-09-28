"""Ball-bearing mat: a shallow riveted steel tray with brass-capped end walls.

    python3 tools/art/gen_bearing_mat.py [preview_dir]

Writes assets/sprites/bearing_mat.png (100x16, the node origin, the middle
of the tray's floor line, at (50, 12)). The floor's top is on row 0 and
runs x -45..45; the end walls stand at x +-45 up to y -10.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 100, 16, (50, 12)


def body():
    fig = Figure()
    fig.box((-45, -1, 45, 2.2), STEEL, z=0, bevel=0.7, grit=0.04)            # the floor plate
    fig.capsule((-43, 0.1), (43, 0.1), 0.35, STEEL[1:3], z=0.05)              # a worn groove
    fig.box((-44, 1.8, 44, 3.2), BRONZE, z=0.1, bevel=0.4)                    # skirt
    for x in range(-39, 42, 9):
        fig.sphere((x, 1.1), 0.5, BRONZE, z=0.2)
    for s in (-1, 1):
        fig.box((s * 45 - 1.5, -9, s * 45 + 1.5, 2.5), STEEL, z=0.3, bevel=0.6)   # end walls
        fig.box((s * 45 - 2.2, -11, s * 45 + 2.2, -8.5), BRONZE, z=0.4, bevel=0.5)
        fig.capsule((s * 45, -5), (s * 40, 0), 0.6, STEEL, z=0.25)          # gussets, inboard
        fig.sphere((s * 45, -3.5), 0.5, BRONZE, z=0.45)
    return fig.render(W, H, O)


def main():
    b = body()
    write_png(SPR + 'bearing_mat.png', W, H, b)
    print('wrote bearing_mat.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 6)
        write_png(sys.argv[1] + '/bearing_mat_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
