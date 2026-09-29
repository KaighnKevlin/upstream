"""Panning box: a short slatted riffle box set on a flume's floor. Grit the
current carries through it is caught behind the riffles and washed; the
code draws the caught grit glinting in the pockets and the water swirling.

    python3 tools/art/gen_panning_box.py [preview_dir]

Writes (measured from the node origin, the middle of the box on the flume's
floor line y 0; drawn for a rightward current, the code flips them for
leftward):
- panning_box.png      44x16, the origin at (22, 11): a dark canvas bed
  (y -3..-0.5, x -19..19) on two iron shoes, a low wet-oak back board
  (y -8..-1) behind it, the tall head board at x -20 (up to y -9) and the
  low tail board at x 20 (up to y -5: the outlet the nuggets float over),
  iron-banded at the corners.
- panning_riffles.png  44x16, same origin: four oak riffle slats standing
  on the bed at x -11, -3, 5 and 13 (y -7..-2), leaning upstream, each with
  an iron cap strip; the pockets behind them are where the grit collects.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
WET_EXTRA = ['3a2c22', '523a28', '6a4c31']
WET = [(42, 34, 28), (58, 44, 34), (82, 58, 40), (106, 76, 49), (122, 84, 51)]
# the canvas bed the grit settles on: a dull sacking brown-grey
CANVAS_EXTRA = ['3b3530', '554c42', '6e6254']
CANVAS = [(41, 38, 31), (59, 53, 48), (85, 76, 66), (110, 98, 84)]
IRON = STEEL[:6]
EXTRA = OAK_EXTRA + WET_EXTRA + CANVAS_EXTRA
RIFFLES = (-11, -3, 5, 13)
ORIGIN = (22, 11)


def box():
    fig = Figure()
    fig.box((-19.5, -8.2, 19.5, -1.0), WET[:4], z=0, bevel=0.6, grit=0.12)       # the back board
    for x in (-10, 2, 12):
        fig.capsule((x, -6), (x + 5, -6), 0.28, WET[:2], z=0.05)                 # grain
    fig.box((-19.5, -3.0, 19.5, -0.4), CANVAS, z=0.2, bevel=0.5, grit=0.15)      # the canvas bed
    for s, top in ((-1, -9.4), (1, -5.4)):                                        # head / tail boards
        fig.box((s * 20 - 1.4, top, s * 20 + 1.4, 1.2), OAK, z=0.4, bevel=0.6, grit=0.1)
        fig.box((s * 20 - 1.8, -1.6, s * 20 + 1.8, 0.2), IRON, z=0.5, bevel=0.4)  # corner band
        fig.sphere((s * 20, -0.7), 0.5, BRONZE, z=0.6)
        fig.box((s * 16 - 2.4, -0.2, s * 16 + 2.4, 1.6), IRON, z=0.3, bevel=0.5)  # the shoe
    return fig.render(44, 16, ORIGIN, extra=EXTRA)


def riffles():
    fig = Figure()
    for x in RIFFLES:
        fig.box((x - 0.9, -7.0, x + 0.9, -2.2), OAK, z=0, bevel=0.5, tilt=-14, grit=0.1)
        fig.box((x - 1.3, -7.6, x + 0.3, -6.4), IRON, z=0.1, bevel=0.3, tilt=-14)  # its iron cap
    return fig.render(44, 16, ORIGIN, extra=EXTRA)


def main():
    b, r = box(), riffles()
    write_png(SPR + 'panning_box.png', 44, 16, b)
    write_png(SPR + 'panning_riffles.png', 44, 16, r)
    print('wrote panning_box.png, panning_riffles.png')
    if len(sys.argv) > 1:
        both = [row[:] for row in b]
        for y in range(16):
            for x in range(44):
                if r[y][x][3]:
                    both[y][x] = r[y][x]
        big = side_by_side([b, r, both], 6)
        write_png(sys.argv[1] + '/panning_box_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
