"""Drawbridge: an oak-planked span on a steel frame, and the fixed parts:
a steel abutment at the near edge, an oak gatehouse post on the far bank
with a brass cap and a chain pulley, a steel ramp off the far bank.

    python3 tools/art/gen_drawbridge.py [preview_dir]

Writes (drawn for side = +1, pieces crossing to the right; the code
mirrors them for side = -1):
- drawbridge_frame.png  72x68, the node origin (the near edge) at (5, 48).
  The hinge is at (48, 3), the post stands at x 53 from y 16 up to its
  top (the chain pulley) at y -40; the ramp runs (48, 5) -> (62, 10).
- drawbridge_span.png   58x11, the hinge at (54, 3); the span runs 48 px
  toward -x from it, its deck (where pieces roll) on the hinge's row and
  its planks below. The code rotates it by the span's angle less 180.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
SPAN = 48
FW, FH, FO = 72, 68, (5, 48)
SW, SH, SO = 58, 11, (54, 3)


def frame():
    fig = Figure()
    # the near abutment: a steel post with a brass cap
    fig.box((-2, 2, 2, 17), STEEL, z=0, bevel=0.8)
    fig.box((-3, 1, 3, 3.4), BRONZE, z=0.1, bevel=0.6)
    fig.sphere((0, 10), 0.6, BRONZE, z=0.2)
    # the ramp off the far bank, on a little strut
    fig.capsule((49, 5), (63, 10), 1.3, STEEL, z=1.0)
    fig.capsule((60, 10), (60, 17), 0.9, STEEL[:5], z=0.9)
    # the gatehouse post: oak, iron bands, a brass cap, a pulley at the top
    x = SPAN + 5
    fig.box((x - 2.6, -38, x + 2.6, 17), OAK, z=0.5, bevel=1.0, grit=0.09)
    for y in (-26, -8, 10):
        fig.box((x - 3, y - 1, x + 3, y + 1), STEEL[:5], z=0.6, bevel=0.5)
    fig.box((x - 4.2, -42.5, x + 4.2, -39), BRONZE, z=0.7, bevel=0.7)
    fig.poly([(x - 3, -42.5), (x + 3, -42.5), (x, -46)], BRONZE, z=0.65, shade=0.7)
    fig.disc((x, -37), 2.6, STEEL, z=0.8)                 # the chain pulley
    fig.sphere((x, -37), 0.9, BRONZE, z=0.9)
    fig.box((x - 4, 15, x + 4, 18), STEEL[:5], z=0.6, bevel=0.6)   # its foot plate
    # the hinge block the span pivots on
    fig.box((SPAN - 3, 3, SPAN + 3, 9), STEEL[:5], z=0.4, bevel=0.7)
    return fig.render(FW, FH, FO, extra=OAK_EXTRA)


def span():
    fig = Figure()
    # the deck: a steel strap along the top edge, oak planking under it
    fig.box((-SPAN - 1, 0.3, 1, 5.6), OAK, z=0, bevel=0.7, grit=0.08)
    for k in range(4, SPAN - 1, 7):
        fig.capsule((-k, 1.2), (-k, 5), 0.35, OAK[:2], z=0.1)       # plank joints
        fig.sphere((-k - 1.6, 3.2), 0.5, STEEL, z=0.2)               # bolts
    fig.box((-SPAN - 1, -1.2, 1, 0.9), STEEL, z=0.3, bevel=0.5)       # the running strap
    fig.box((-SPAN - 1.5, -1.6, -SPAN + 2, 5.8), STEEL[:5], z=0.4, bevel=0.5)   # an iron shoe on the free end
    fig.disc((-SPAN + 0.5, 2.2), 1.3, BRONZE, z=0.5)                  # the chain eye
    fig.disc((0, 2), 3.0, STEEL, z=0.6)                                # the hinge knuckle
    fig.sphere((0, 2), 1.2, BRONZE, z=0.7)
    return fig.render(SW, SH, SO, extra=OAK_EXTRA)


def main():
    f, s = frame(), span()
    write_png(SPR + 'drawbridge_frame.png', FW, FH, f)
    write_png(SPR + 'drawbridge_span.png', SW, SH, s)
    print('wrote drawbridge_frame.png, drawbridge_span.png')
    if len(sys.argv) > 1:
        comp = [row[:] for row in f]
        ox, oy = FO[0] + SPAN - SO[0], FO[1] + 3 - SO[1]
        for y in range(SH):
            for x in range(SW):
                if s[y][x][3] and 0 <= x + ox < FW:
                    comp[y + oy][x + ox] = s[y][x]
        big = side_by_side([comp, s], 4)
        write_png(sys.argv[1] + '/drawbridge_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
