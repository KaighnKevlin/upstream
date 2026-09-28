"""Balance: an iron post on a footing plate with a brass knife-edge block
on top, the brass beam the code tilts on it, and the shallow brass pan the
code hangs level from each end.

    python3 tools/art/gen_balance.py [preview_dir]

Writes (all measured from the node origin, the ground under the post; the
pivot is PIVOT = (0, -52), the beam's arms ARM = 32, the pans' rims HANG =
28 below the beam's ends):
- balance_post.png  18x58, the origin at (9, 55): a riveted footing plate
  (x -7..7, y -3..1), the iron post up to the brass knife-edge block round
  the pivot at y -52.
- balance_beam.png  74x10, the pivot at (37, 5): the brass beam along +-x
  to its hooks at x +-32, the pivot boss in the middle; the code rotates it.
- balance_pan.png   34x10, the rim's centre at (17, 2): a dish x -15..15
  from the rim (y 0) down to its foot (y 6), a hanger lug at each end.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def post():
    fig = Figure()
    fig.box((-7.4, -3.2, 7.4, 1.0), STEEL, z=0, bevel=0.9)               # the footing plate
    for x in (-5, 5):
        fig.sphere((x, -1.2), 0.8, BRONZE, z=0.1)                        # its rivets
    fig.box((-3.2, -5.6, 3.2, -2.6), STEEL, z=0.2, bevel=0.7)            # the socket
    fig.capsule((0, -4), (0, -48), 1.8, STEEL, z=0.3)                    # the post
    for y in (-18, -34):
        fig.box((-2.4, y - 0.9, 2.4, y + 0.9), DARK, z=0.35, bevel=0.4)  # bands
    fig.poly([(-4.5, -47), (4.5, -47), (2.4, -55), (-2.4, -55)], BRONZE, z=0.4, shade=0.55)   # the knife-edge block
    fig.box((-4.8, -48.2, 4.8, -46.4), BRONZE, z=0.45, bevel=0.5)        # its base
    return fig.render(18, 58, (9, 55))


def beam():
    fig = Figure()
    fig.box((-32, -1.4, 32, 1.4), BRONZE, z=0, bevel=0.7)                # the beam
    fig.poly([(-10, -1.2), (10, -1.2), (0, -3.8)], BRONZE, z=0.05, shade=0.7)   # the crown over the pivot
    for s in (-1, 1):
        fig.sphere((s * 32, 0), 1.9, STEEL, z=0.2)                       # the end hooks
        fig.sphere((s * 20, 0), 0.6, STEEL, z=0.2)                       # rivets
    fig.disc((0, 0), 3.2, STEEL, z=0.3)                                  # the pivot boss
    fig.sphere((0, 0), 1.4, BRONZE, z=0.4)
    return fig.render(74, 10, (37, 5))


def pan():
    fig = Figure()
    fig.poly([(-15, 0), (15, 0), (11, 4.6), (-11, 4.6)], BRONZE, z=0, shade=0.5)       # the dish
    fig.box((-15.6, -0.8, 15.6, 1.0), [BRONZE[4], BRONZE[5], BRONZE[6], BRONZE[7]], z=0.1, bevel=0.4)   # a lit rim
    fig.box((-4, 4.2, 4, 6.4), BRONZE, z=0.05, bevel=0.5)                # the foot
    for s in (-1, 1):
        fig.sphere((s * 14.2, -0.4), 1.1, STEEL, z=0.2)                  # hanger lugs
    return fig.render(34, 10, (17, 2))


def main():
    p, b, q = post(), beam(), pan()
    write_png(SPR + 'balance_post.png', 18, 58, p)
    write_png(SPR + 'balance_beam.png', 74, 10, b)
    write_png(SPR + 'balance_pan.png', 34, 10, q)
    print('wrote balance_post.png, balance_beam.png, balance_pan.png')
    if len(sys.argv) > 1:
        # and together, level, as the game shows them (hangers are the code's)
        both = [[(0, 0, 0, 0)] * 100 for _ in range(60)]
        for img, ox, oy in ((p, 41, 0), (b, 13, -2), (q, 1, 29), (q, 65, 29)):
            for y in range(len(img)):
                for x in range(len(img[0])):
                    if img[y][x][3] and 0 <= y + oy < 60:
                        both[y + oy][x + ox] = img[y][x]
        big = side_by_side([p, b, q, both], 8)
        write_png(sys.argv[1] + '/balance_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
