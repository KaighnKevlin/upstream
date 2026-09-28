"""Hammer: a bell-crank (a steel paddle arm, an oak handle down to a brass
hammer head, a pivot boss) and its fixed frame (the wall bracket it hangs
from and the little steel ledge the struck piece waits on).

    python3 tools/art/gen_hammer.py [preview_dir]

Writes (drawn for side = +1, the struck piece flying right; the code
mirrors them for side = -1):
- hammer_crank.png  44x42, the pivot at (34, 8). The paddle arm runs to
  (-24, 0) and ends in a plate x -32..-19; the handle runs down to the head
  centred on (0, 26), 12 wide and 10 tall. The code rotates it about the
  pivot.
- hammer_frame.png  44x64, the pivot at (9, 20). The bracket runs up to a
  wall plate on row -16; the ledge's top is on row +28.5, x 16..31, with a
  leg under it at x 23.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]

CRANK_W, CRANK_H, CRANK_O = 44, 42, (34, 8)
FRAME_W, FRAME_H, FRAME_O = 44, 64, (9, 20)


def crank():
    fig = Figure()
    # the paddle arm: a steel bar out to the plate
    fig.box((-22, -1.4, 0, 1.4), STEEL, z=0, bevel=0.6)
    fig.box((-32, -2.6, -19, 2.4), BRONZE, z=0.2, bevel=0.8)              # the paddle plate
    fig.box((-32, -2.9, -19, -1.6), STEEL, z=0.3, bevel=0.4)              # its wear strip
    for x in (-29.5, -21.5):
        fig.sphere((x, 0.6), 0.55, STEEL, z=0.35)
    # the handle: oak, bound in steel where it meets the head
    fig.box((-1.6, 0, 1.6, 21), OAK, z=0.1, bevel=0.7)
    fig.box((-2.2, 18.5, 2.2, 21.5), STEEL, z=0.25, bevel=0.5)
    # the head: a brass block with steel striking faces on both ends
    fig.box((-5, 21, 5, 31), BRONZE, z=0.4, bevel=1.4)
    for x0, x1 in ((-6.2, -4), (4, 6.2)):
        fig.box((x0, 21.6, x1, 30.4), STEEL, z=0.5, bevel=0.6)
    fig.sphere((0, 26), 0.9, STEEL, z=0.55)
    # the pivot boss
    fig.disc((0, 0), 3.8, BRONZE, z=0.6)
    fig.sphere((0, 0), 1.6, STEEL, z=0.7)
    return fig.render(CRANK_W, CRANK_H, CRANK_O, extra=OAK_EXTRA)


def frame():
    fig = Figure()
    # the wall bracket: a steel strap up from the pivot to a riveted plate
    fig.box((-1.5, -16, 1.5, 1), STEEL, z=0, bevel=0.6)
    fig.box((-7, -18.5, 7, -14.5), BRONZE, z=0.1, bevel=0.6)
    for x in (-4.5, 4.5):
        fig.sphere((x, -16.5), 0.6, STEEL, z=0.2)
    fig.capsule((-5, -14.5), (-1, -9), 0.7, STEEL, z=0.05)               # gussets
    fig.capsule((5, -14.5), (1, -9), 0.7, STEEL, z=0.05)
    # the ledge: a steel shelf on a brass leg, a lip at the outer end
    fig.box((15.5, 28.5, 31.5, 31.5), STEEL, z=0.2, bevel=0.6)
    fig.box((29.5, 25.5, 31.8, 30), STEEL, z=0.25, bevel=0.5)
    fig.box((21.8, 31, 24.2, 41), BRONZE, z=0.1, bevel=0.6)
    fig.box((19.5, 40, 26.5, 42.5), BRONZE, z=0.15, bevel=0.5)
    fig.capsule((23, 38), (17, 31.5), 0.6, BRONZE, z=0.05)                # brace
    for x in (18.5, 27.5):
        fig.sphere((x, 30), 0.5, BRONZE, z=0.3)
    return fig.render(FRAME_W, FRAME_H, FRAME_O)


def main():
    c, f = crank(), frame()
    write_png(SPR + 'hammer_crank.png', CRANK_W, CRANK_H, c)
    write_png(SPR + 'hammer_frame.png', FRAME_W, FRAME_H, f)
    print('wrote hammer_crank.png, hammer_frame.png')
    if len(sys.argv) > 1:
        # composed at rest
        comp = [row[:] for row in f]
        dx, dy = FRAME_O[0] - CRANK_O[0], FRAME_O[1] - CRANK_O[1]
        for y in range(CRANK_H):
            for x in range(CRANK_W):
                X, Y = x + dx, y + dy
                if c[y][x][3] and 0 <= X < FRAME_W and 0 <= Y < FRAME_H:
                    comp[Y][X] = c[y][x]
        big = side_by_side([c, f, comp], 6)
        write_png(sys.argv[1] + '/hammer_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
