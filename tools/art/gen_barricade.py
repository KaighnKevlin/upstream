"""Pop-up barricade: a riveted iron slab with hazard stripes along its top,
braced by bronze ribs, that rises out of a slot in the ground.

    python3 tools/art/gen_barricade.py [preview_dir]

barricade.png: 18x50, the slab's bottom at (9, 49) (it slides up and down
by the game). barricade_slot.png: 26x6, the slot's frame flush with the
ground, centred at (13, 3).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

HAZARD = [(160, 120, 30), (210, 165, 50), (240, 200, 90)]


def slab():
    fig = Figure()
    fig.box((-8, -49, 8, 0), STEEL, z=0, bevel=1.0, grit=0.08)
    for y in (-40, -26, -12):
        fig.box((-8, y - 1, 8, y + 1), BRONZE, z=0.2, bevel=0.4)
        for x in (-5.5, 0, 5.5):
            fig.sphere((x, y), 0.6, DARK, z=0.3)
    for k in range(4):                                           # hazard stripes on the top edge
        x0 = -8 + k * 4
        fig.poly([(x0, -49), (x0 + 2, -49), (x0 + 5, -45), (x0 + 3, -45)], HAZARD, z=0.4, shade=0.2)
    fig.box((-8, -45.5, 8, -44.5), DARK, z=0.45, bevel=0.2)
    return fig.render(18, 50, (9, 49), extra=['a0781e', 'd2a532', 'f0c85a'])


def slot():
    fig = Figure()
    fig.box((-12.5, -3, 12.5, 3), DARK, z=0, bevel=0.8)
    fig.box((-9, -1.5, 9, 1.5), [(20, 18, 16)] * 2, z=0.1, bevel=0.2)
    for x in (-11, 11):
        fig.sphere((x, 0), 0.8, BRONZE, z=0.2)
    return fig.render(26, 6, (13, 3), extra=['141210'])


def main():
    write_png(SPR + 'barricade.png', 18, 50, slab())
    write_png(SPR + 'barricade_slot.png', 26, 6, slot())
    print('wrote barricade.png, barricade_slot.png')
    if len(sys.argv) > 1:
        big = side_by_side([slab()], 8)
        write_png(sys.argv[1] + '/barricade_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
