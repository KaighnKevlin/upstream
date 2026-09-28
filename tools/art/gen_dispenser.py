"""Dispenser: a brass magazine tube, banded and capped, with a sight slot
showing the marbles stacked inside, over a steel spout.

    python3 tools/art/gen_dispenser.py [preview_dir]

Writes assets/sprites/dispenser.png (22x50, the piece's origin at
(11, 38)): the tube spans x -8..8, y -34..4, the spout x -5..5, y 4..10
(where a new marble drops out, at y 14).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def dispenser():
    fig = Figure()
    fig.box((-7.5, -33, 7.5, 4), BRONZE, z=0, bevel=2.2)                     # the tube, rounded
    fig.box((-3.6, -30, 3.6, 0), DARK, z=0.1, bevel=0.6)                     # the sight slot
    for k in range(3):
        fig.sphere((0, -24.5 + k * 9.5), 3.3, COPPER, z=0.2)                 # the marbles waiting
    for y in (-31, -15, 2):
        fig.box((-8.3, y - 1.2, 8.3, y + 1.2), STEEL, z=0.3, bevel=0.5)      # bands
        for x in (-6.5, 6.5):
            fig.sphere((x, y), 0.55, BRONZE, z=0.4)
    fig.box((-8.8, -35.5, 8.8, -32.5), BRONZE, z=0.5, bevel=0.8)             # the cap
    fig.sphere((0, -36), 1.2, STEEL, z=0.6)
    fig.poly([(-5, 3), (5, 3), (4, 10), (-4, 10)], STEEL, z=0.2, shade=0.5)  # the spout
    fig.box((-4.6, 8.4, 4.6, 10.4), STEEL, z=0.3, bevel=0.5)
    return fig.render(22, 50, (11, 38), extra=COPPER_EXTRA)


def main():
    d = dispenser()
    write_png(SPR + 'dispenser.png', 22, 50, d)
    print('wrote dispenser.png')
    if len(sys.argv) > 1:
        big = side_by_side([d], 8)
        write_png(sys.argv[1] + '/dispenser_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
