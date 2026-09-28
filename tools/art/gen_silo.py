"""Silo: a tall riveted brass bin with a hopper funnel on top, a sight-glass
down its front (the code draws the fill level in it) and a steel slide
gate in a housing at the bottom.

    python3 tools/art/gen_silo.py [preview_dir]

Writes assets/sprites/silo.png (42x88, the node origin at (21, 77): the bin
runs x -10..10, y -60..6, the funnel lips out to (+-18, -74), the gate
housing y 5..11) and silo_front.png (same size and origin: the bands and
rivets that cross the sight-glass plus a glint, drawn over the fill). The
sight-glass is x -5..5, y -55..1.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 42, 88, (21, 77)
BANDS = (-40, -21)


def body():
    fig = Figure()
    # the hopper: brass plates to a steel throat
    fig.poly([(-19, -75), (19, -75), (9, -60), (-9, -60)], BRONZE, z=0, shade=0.62)
    fig.poly([(-16, -74), (16, -74), (7, -62), (-7, -62)], DARK, z=0.1, shade=0.35)
    fig.box((-20, -77, 20, -73.5), BRONZE, z=0.2, bevel=0.8)
    for x in (-16, 0, 16):
        fig.sphere((x, -75.3), 0.6, STEEL, z=0.3)
    # the bin: a brass drum, rounded sides
    fig.box((-10.5, -61, 10.5, 6), BRONZE, z=1, bevel=3.5, grit=0.05)
    fig.box((-11.5, -62, 11.5, -59), BRONZE, z=1.2, bevel=0.8)          # top ring
    for x in (-8.5, 8.5):
        for y in range(-54, 4, 6):
            fig.sphere((x, y), 0.5, BRONZE, z=1.3)                        # seam rivets
    # the sight-glass (dark; the fill is drawn over it)
    fig.box((-6, -56, 6, 2), STEEL, z=1.4, bevel=0.6)
    fig.box((-5, -55, 5, 1), DARK, z=1.5, bevel=0.3, grit=0.02)
    # gate housing and the steel slide
    fig.box((-8, 4, 8, 10.5), STEEL, z=2, bevel=1.0)
    fig.box((-4, 8.5, 4, 10.5), DARK, z=2.1, bevel=0.3)
    fig.sphere((6, 7), 0.6, BRONZE, z=2.2)
    fig.sphere((-6, 7), 0.6, BRONZE, z=2.2)
    return fig.render(W, H, O)


def front():
    fig = Figure()
    for y in BANDS:
        fig.box((-11, y - 1.3, 11, y + 1.3), BRONZE, z=0, bevel=0.6)
        for x in (-8, 8):
            fig.sphere((x, y), 0.55, STEEL, z=0.1)
    img = fig.render(W, H, O)
    # a glint down the left of the glass (no outline)
    g = Figure()
    g.poly([(-4.2, -53), (-3.2, -53), (-3.2, -44), (-4.2, -44)], STEEL, z=0, shade=0.95, grit=0)
    g.poly([(-4.2, -17), (-3.2, -17), (-3.2, -13), (-4.2, -13)], STEEL, z=0, shade=0.95, grit=0)
    gl = g.render(W, H, O, outline=False)
    return [[gl[y][x] if gl[y][x][3] else img[y][x] for x in range(W)] for y in range(H)]


def main():
    b, f = body(), front()
    write_png(SPR + 'silo.png', W, H, b)
    write_png(SPR + 'silo_front.png', W, H, f)
    print('wrote silo.png, silo_front.png')
    if len(sys.argv) > 1:
        comp = [[f[y][x] if f[y][x][3] else b[y][x] for x in range(W)] for y in range(H)]
        big = side_by_side([b, f, comp], 5)
        write_png(sys.argv[1] + '/silo_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
