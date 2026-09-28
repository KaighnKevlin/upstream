"""Speed trap: a riveted brass box with a steel frame, a dark tally slot,
and a steel lens bezel low on its face (the eye; the code paints the lit
lens in it and the beam below it, both of which flash).

    python3 tools/art/gen_speed_trap.py [preview_dir]

Writes:
- speed_trap.png  20x17, the node origin at (10, 17): the box x -9..9,
  y -16..-2, the lens bezel centred on (0, -4).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def body():
    fig = Figure()
    fig.box((-9, -16, 9, -2), STEEL, z=0, bevel=1.2)                     # the frame
    fig.box((-7.4, -14.6, 7.4, -3.4), BRONZE, z=0.1, bevel=0.9)          # the brass face
    fig.box((-9, -16, 9, -14.6), [STEEL[5], STEEL[6], STEEL[7]], z=0.15, bevel=0.4)   # a lit top edge
    for p in ((-7.6, -14.4), (7.6, -14.4), (-7.6, -3.6), (7.6, -3.6)):
        fig.sphere(p, 0.6, STEEL, z=0.3)                                 # rivets
    fig.box((-5, -12.6, 5, -9.4), DARK, z=0.2, bevel=0.5, grit=0.02)    # the tally slot
    for x in (-3, 0, 3):
        fig.box((x - 0.5, -12, x + 0.5, -10), [BRONZE[3], BRONZE[4]], z=0.25, bevel=0.1, grit=0.0)   # its wheels' ticks
    fig.disc((0, -4), 3.4, STEEL, z=0.4)                                 # the lens bezel
    fig.disc((0, -4), 2.2, DARK, z=0.5)
    return fig.render(20, 17, (10, 17))


def main():
    b = body()
    write_png(SPR + 'speed_trap.png', 20, 17, b)
    print('wrote speed_trap.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/speed_trap_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
