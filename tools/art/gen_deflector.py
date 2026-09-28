"""Deflector: a leaf-sprung steel plate (three leaves, like a cart spring)
clamped at its middle to a brass pivot, and the post it stands on.

    python3 tools/art/gen_deflector.py [preview_dir]

Writes assets/sprites/deflector_plate.png (50x10, the pivot at (25, 4); the
top leaf's face, where ore strikes, runs x -22..22 on the pivot's row, so
the code rotates the sprite by the plate's angle about that point) and
deflector_post.png (16x32, the pivot at (8, 2); the foot on the row +26).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def plate():
    fig = Figure()
    fig.box((-22, -0.6, 22, 1.6), STEEL, z=2, bevel=0.7, grit=0.03)       # the striking leaf
    fig.box((-15, 1.4, 15, 2.9), STEEL, z=1, bevel=0.6, grit=0.03)
    fig.box((-8, 2.7, 8, 4.1), STEEL, z=0, bevel=0.6, grit=0.03)
    for x in (-22, 22):
        fig.box((x - 1.5, -1.0, x + 1.5, 2.2), BRONZE, z=2.2, bevel=0.6)  # end clips
    for x in (-15, 15):
        fig.sphere((x, 2.1), 0.5, BRONZE, z=1.2)
    fig.box((-3.2, -1.2, 3.2, 4.6), BRONZE, z=3, bevel=1.0)               # centre clamp
    fig.sphere((0, 1.7), 1.1, STEEL, z=3.1)                              # pivot bolt
    return fig.render(50, 10, (25, 4))


def post():
    fig = Figure()
    fig.box((-1.6, 2, 1.6, 25), BRONZE, z=0, bevel=0.8)
    for y in (9, 17):
        fig.box((-2.2, y - 0.8, 2.2, y + 0.8), STEEL, z=0.1, bevel=0.4)
    fig.box((-7, 24.5, 7, 27), STEEL, z=0.2, bevel=0.6)
    for x in (-5, 5):
        fig.sphere((x, 25.7), 0.55, BRONZE, z=0.3)
    fig.ellipsoid((0, 2.5), (3, 2.5), BRONZE, z=0.3)                     # the fork the clamp turns in
    return fig.render(16, 32, (8, 2))


def main():
    p, s = plate(), post()
    write_png(SPR + 'deflector_plate.png', 50, 10, p)
    write_png(SPR + 'deflector_post.png', 16, 32, s)
    print('wrote deflector_plate.png, deflector_post.png')
    if len(sys.argv) > 1:
        big = side_by_side([p, s], 8)
        write_png(sys.argv[1] + '/deflector_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
