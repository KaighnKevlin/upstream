"""Sluice gate: an oak drop-board with steel straps, and its frame: two
steel uprights, a crossbar and the brass winch drum its cable winds on.

    python3 tools/art/gen_sluice.py [preview_dir]

Writes:
- sluice_frame.png  22x56, the node origin at (11, 47). The uprights stand
  at x +-5 from y 6 up to the crossbar on row -40; the drum (y -44) is
  where the code runs the cable to.
- sluice_gate.png   10x30, its origin (the board's middle at the node when
  shut) at (5, 23): the board runs x -3..3, y -22..4.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def frame():
    fig = Figure()
    for x in (-5, 5):
        fig.box((x - 1.3, -40, x + 1.3, 6), STEEL, z=0, bevel=0.6)
        fig.box((x - 2.2, 4, x + 2.2, 7), BRONZE, z=0.1, bevel=0.5)          # feet
        for y in (-30, -12):
            fig.sphere((x, y), 0.5, BRONZE, z=0.1)
    fig.box((-8, -42, 8, -38.5), BRONZE, z=0.2, bevel=0.7)                    # crossbar
    fig.disc((0, -44), 3.2, BRONZE, z=0.3)                                   # winch drum
    fig.disc((0, -44), 1.6, DARK, z=0.35)
    fig.sphere((0, -44), 0.7, STEEL, z=0.4)
    return fig.render(22, 56, (11, 47))


def gate():
    fig = Figure()
    fig.box((-3, -22, 3, 4), OAK, z=0, bevel=0.9)
    for y in (-15, -5):
        fig.capsule((-3, y), (3, y), 0.25, OAK[:2], z=0.05)                  # plank joints
    for y in (-20, 2):
        fig.box((-3.4, y - 1, 3.4, y + 1), STEEL, z=0.1, bevel=0.4)          # straps
    fig.sphere((0, -22.5), 1.0, STEEL, z=0.2)                                # the cable eye
    return fig.render(10, 30, (5, 23), extra=OAK_EXTRA)


def main():
    f, g = frame(), gate()
    write_png(SPR + 'sluice_frame.png', 22, 56, f)
    write_png(SPR + 'sluice_gate.png', 10, 30, g)
    print('wrote sluice_frame.png, sluice_gate.png')
    if len(sys.argv) > 1:
        big = side_by_side([f, g], 6)
        write_png(sys.argv[1] + '/sluice_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
