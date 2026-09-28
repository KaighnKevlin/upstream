"""Gauss cannon: a short steel rail on brass stands, the red-painted magnet
block (steel pole face toward the balls) at its near end, and the row of
four polished steel balls. Drawn with the magnet at the left, firing to +x
(mirrored in code for side -1). Same reds as the magnet drum.

    python3 tools/art/gen_gauss.py [preview_dir]

Writes assets/sprites/gauss.png (80x22, the piece's origin at (40, 16)):
the rail's top face on row 14 (y -2.5), running x -36..36; the magnet
block x -26..-18, y -14..0; the balls (r 4.5) centred on y -7 at
x -14, -5, 4, 13.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

RED_EXTRA = ['4a1a16', '7a2620', 'a8382c', 'cc5a44', 'e88a6c']
RED = [(74, 26, 22), (122, 38, 32), (168, 56, 44), (204, 90, 68), (232, 138, 108)]


def gauss():
    fig = Figure()
    # the rail: a steel bar with a brass web and a stand at each end
    fig.box((-36, -2.5, 36, 0.5), STEEL, z=1, bevel=0.7, grit=0.03)
    fig.box((-35, 0.5, 35, 2.4), BRONZE, z=0.9, bevel=0.6)
    for x in (-24, -8, 8, 24):
        fig.sphere((x, 1.4), 0.55, STEEL, z=1.1)
    for x in (-32, 32):
        fig.poly([(x - 2, 2), (x + 2, 2), (x + 3.5, 5.5), (x - 3.5, 5.5)], BRONZE, z=0.8, shade=0.5)
    fig.box((-37, -4, -35, 0.5), STEEL, z=1.2, bevel=0.5)               # an end stop behind the magnet
    # the magnet block: painted body, steel pole plate toward the balls
    fig.box((-26, -14, -21, 0), RED, z=2, bevel=0.9)
    fig.box((-21.4, -14, -18, 0), STEEL, z=2.1, bevel=0.7)
    fig.capsule((-26, -11), (-21.5, -11), 0.35, RED[:2], z=2.2)         # coil wrap lines
    fig.capsule((-26, -7), (-21.5, -7), 0.35, RED[:2], z=2.2)
    fig.capsule((-26, -3), (-21.5, -3), 0.35, RED[:2], z=2.2)
    fig.box((-27, -15, -17, -13.4), BRONZE, z=2.3, bevel=0.5)           # the clamp cap
    fig.sphere((-22, -14.2), 0.6, STEEL, z=2.4)
    # the balls
    for k in range(4):
        fig.sphere((-14 + k * 9, -7), 4.4, STEEL, z=3, grit=0.02)
    return fig.render(80, 22, (40, 16), extra=RED_EXTRA)


def main():
    g = gauss()
    write_png(SPR + 'gauss.png', 80, 22, g)
    print('wrote gauss.png')
    if len(sys.argv) > 1:
        big = side_by_side([g], 8)
        write_png(sys.argv[1] + '/gauss_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
