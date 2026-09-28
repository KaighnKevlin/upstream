"""Teeter launcher: an oak beam with steel end caps on a brass pivot boss,
the riveted steel fulcrum it rocks on, and the brass cup that rides each
end (it hangs from a pin, so it stays upright while the beam tilts).

    python3 tools/art/gen_teeter.py [preview_dir]

Writes:
- teeter_beam.png     68x10, the pivot at (34, 5); the beam's centre line
  is on the pivot's row and runs +-30 px (the code rotates it about there).
- teeter_fulcrum.png  22x20, the pivot at (11, 3); the foot on row 19
  (+16 from the pivot).
- teeter_cup.png      22x14, the beam end at (11, 11): the cup's floor
  sits on that point, the walls flare up to +-8 at 9 px above it.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def beam():
    fig = Figure()
    fig.box((-30, -2.2, 30, 2.2), OAK, z=0, bevel=0.9)
    fig.capsule((-27, 1.4), (27, 1.4), 0.4, DARK, z=0.05)            # the lower edge in shadow
    for x in (-30, 30):
        fig.box((x - 2, -2.8, x + 2, 2.8), STEEL, z=0.2, bevel=0.6)   # end caps
        fig.sphere((x, 0), 0.8, BRONZE, z=0.3)                        # the cup pins
    for x in (-18, -10, 10, 18):
        fig.sphere((x, -0.4), 0.6, STEEL, z=0.3)                      # rivets
    fig.disc((0, 0), 4, BRONZE, z=0.5)                                 # the pivot boss
    fig.sphere((0, 0), 1.6, STEEL, z=0.6)
    return fig.render(68, 10, (34, 5), extra=OAK_EXTRA)


def fulcrum():
    fig = Figure()
    fig.poly([(0, -1), (7.5, 15), (-7.5, 15)], STEEL, z=0, shade=0.35)
    fig.poly([(0, 2), (5, 13), (-5, 13)], DARK, z=0.1, shade=0.6)     # the web, recessed
    for s in (-1, 1):
        fig.capsule((0, 0), (s * 7.5, 15), 1.1, STEEL, z=0.2)         # the legs
    fig.box((-10, 14, 10, 17), BRONZE, z=0.3, bevel=0.6)               # foot plate
    for x in (-7, 7):
        fig.sphere((x, 15.5), 0.6, STEEL, z=0.4)
    fig.disc((0, 0.5), 3, BRONZE, z=0.4)                               # the bearing
    return fig.render(22, 20, (11, 3))


def cup():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 6.2, -0.4), (s * 8, -8.6), 1.1, BRONZE, z=0.1)   # walls
        fig.sphere((s * 8, -8.8), 1.1, STEEL, z=0.2)                     # rolled lip
    fig.box((-7, -1.4, 7, 1.3), BRONZE, z=0.2, bevel=0.7)                 # floor
    return fig.render(22, 14, (11, 11))


def main():
    b, f, c = beam(), fulcrum(), cup()
    write_png(SPR + 'teeter_beam.png', 68, 10, b)
    write_png(SPR + 'teeter_fulcrum.png', 22, 20, f)
    write_png(SPR + 'teeter_cup.png', 22, 14, c)
    print('wrote teeter_beam.png, teeter_fulcrum.png, teeter_cup.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, f, c], 8)
        write_png(sys.argv[1] + '/teeter_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
