"""Iron plating: riveted steel armour plates that tile along any length, and
the rounded end cap with the brass bolt that holds each end to the rock.

    python3 tools/art/gen_iron_plating.py [preview_dir]

Writes (drawn along the plate's direction, rotated in code):
- plating_tile.png  24x8 tile, repeats along x: one plate, the seam on
  column 0 with a rivet either side of it (x 3 and 21), the face lit from
  above (the top edge on row 0, the plate's centre line on row 4).
- plating_end.png   8x8, the end at its centre (4, 4): a rounded cap over
  the plate's end and the brass bolt through it; the code flips it for the
  far end.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def tile():
    fig = Figure()
    # run the plate past both edges so the tile's sides have no outline
    fig.poly([(-4, -4), (28, -4), (28, 4), (-4, 4)], DARK, z=-1, shade=0.0, grit=0.0)   # the dark rim
    fig.box((-4, -3, 28, 3), STEEL, z=0, bevel=1.2, grit=0.05)
    fig.capsule((-4, -2.4), (28, -2.4), 0.3, [STEEL[6], STEEL[7]], z=0.1)   # a lit top edge
    fig.box((-0.5, -3, 0.5, 3), DARK, z=0.2, bevel=0.2, grit=0.0)      # the seam
    fig.poly([(-4, 2), (28, 2), (28, 3), (-4, 3)], STEEL, z=0.1, shade=0.2, grit=0.02)   # its shadowed lower edge
    for x in (3, 21):
        fig.sphere((x, 0.5), 1.3, STEEL, z=0.3)
    return fig.render(24, 8, (0, 4), outline=False)


def end():
    fig = Figure()
    fig.box((-3.2, -3, 8, 3), STEEL, z=0, bevel=2.0, grit=0.04)
    fig.disc((0, 0), 2.4, DARK, z=0.2)
    fig.sphere((0, 0), 1.7, BRONZE, z=0.3)
    return fig.render(8, 8, (4, 4))


def main():
    t, e = tile(), end()
    write_png(SPR + 'plating_tile.png', 24, 8, t)
    write_png(SPR + 'plating_end.png', 8, 8, e)
    print('wrote plating_tile.png, plating_end.png')
    if len(sys.argv) > 1:
        tt = [sum((row for _ in range(3)), []) for row in t]
        big = side_by_side([tt, e], 8)
        write_png(sys.argv[1] + '/iron_plating_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
