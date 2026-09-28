"""Flume: a level wooden water trough on trestles. The trough floor and its
legs tile along any length; the head wall and the iron weir (raised and
lowered) are separate sprites. The code draws the water over the floor.

    python3 tools/art/gen_flume.py [preview_dir]

Writes (measured from the node origin, the head of the trough on the floor
line y 0; drawn for a rightward run, the code flips them for leftward):
- flume_trough.png  48x18 tile, repeats along x, the floor line at row 2
  (tile y -2..15): a planked oak floor (y -1..3, a plank seam every 16 px),
  a cross-beam under it and an A-frame trestle at x 10 splaying to x 6 and
  14 at y 14, on a little foot plank.
- flume_wall.png    8x25, the floor line under the wall at (4, 20): the
  oak back wall post from y -19 to y 3, iron-banded, a cap board on top.
- flume_weir.png    2 frames of 10x17 (hframes 2), the weir foot at (4, 12)
  in each: an iron guide post up to the brass knob at (0, -8); frame 0 the
  riveted weir plate raised to y -5, frame 1 dropped to y -1 (flushing).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
# wet oak for the trough floor: darker, the water has soaked it
WET_EXTRA = ['3a2c22', '523a28', '6a4c31']
WET = [(42, 34, 28), (58, 44, 34), (82, 58, 40), (106, 76, 49), (122, 84, 51)]
IRON = STEEL[:6]
EXTRA = OAK_EXTRA + WET_EXTRA


def trough():
    fig = Figure()
    # the trestle: two splayed legs under the floor, a foot plank across them
    fig.capsule((9.5, 2.5), (5.8, 13.6), 1.05, OAK, z=0, grit=0.1)
    fig.capsule((10.5, 2.5), (14.2, 13.6), 1.05, OAK, z=0.05, grit=0.1)
    fig.box((7.4, 7.2, 12.6, 8.6), OAK[:4], z=0.1, bevel=0.5)          # a brace
    fig.box((3.6, 13.2, 16.4, 15.2), OAK, z=0.1, bevel=0.6)             # the foot plank
    fig.sphere((10, 3.4), 0.7, IRON, z=0.3)                             # the bolt at the head
    # the cross-beam the floor sits on, over the leg
    fig.box((6.5, 2.2, 13.5, 4.8), OAK, z=0.2, bevel=0.6)
    # the floor: a dark lip, then planks butted end to end
    fig.box((-4, -1.9, 52, -0.9), DARK[:3], z=0.5, bevel=0.3, grit=0.0)
    for x0 in (-16, 0, 16, 32, 48):
        fig.box((x0 + 0.5, -1, x0 + 16.2, 3), WET, z=0.6, bevel=0.7, grit=0.12)
        fig.capsule((x0 + 3, 1), (x0 + 9, 1), 0.28, WET[:2], z=0.65)    # grain
        fig.sphere((x0 + 2, 0.9), 0.5, IRON, z=0.7)                     # nail heads
        fig.sphere((x0 + 14.6, 0.9), 0.5, IRON, z=0.7)
        fig.box((x0 + 16.1, -1, x0 + 16.9, 3), DARK[:2], z=0.62, bevel=0.1, grit=0.0)   # the seam
    fig.box((-4, 2.6, 52, 3.8), DARK[:3], z=0.55, bevel=0.3, grit=0.0)  # the floor's underside
    return fig.render(48, 18, (0, 2), outline=False, extra=EXTRA)


def wall():
    fig = Figure()
    fig.box((-2.4, -18.6, 2.4, 3.2), OAK, z=0, bevel=0.9, grit=0.12)
    fig.capsule((-0.6, -15), (-0.6, -8), 0.3, OAK[:2], z=0.05)          # grain
    fig.capsule((0.8, -5), (0.8, 0), 0.3, OAK[:2], z=0.05)
    fig.box((-3.4, -19.6, 3.4, -17.6), OAK, z=0.1, bevel=0.6)           # the cap board
    for y in (-12.5, -1.5):                                             # iron bands
        fig.box((-2.8, y - 0.9, 2.8, y + 0.9), IRON, z=0.2, bevel=0.4)
        fig.sphere((0, y), 0.5, BRONZE, z=0.3)
    return fig.render(8, 25, (4, 20), extra=EXTRA)


def weir(down):
    fig = Figure()
    top = -1.2 if down else -5.2
    fig.box((-2.2, 1.2, 2.2, 3.2), IRON, z=0, bevel=0.5)               # the sill on the floor
    fig.capsule((1.7, 2), (1.7, -7), 0.55, DARK[2:] + IRON[3:4], z=0.1)  # the guide post
    fig.box((-1.9, top, 1.6, 2.2), IRON, z=0.3, bevel=0.6)              # the plate
    if not down:
        fig.sphere((-0.1, -3.3), 0.5, BRONZE, z=0.4)                     # its rivets
        fig.sphere((-0.1, 0.3), 0.5, BRONZE, z=0.4)
    else:
        fig.sphere((-0.1, 0.5), 0.5, BRONZE, z=0.4)
    fig.sphere((0, -8), 2.1, BRONZE, z=0.5)                              # the brass knob
    fig.sphere((-0.6, -8.6), 0.6, [BRONZE[5], BRONZE[6], BRONZE[7]], z=0.6)
    return fig.render(10, 17, (4, 12))


def main():
    t, w = trough(), wall()
    up, dn = weir(False), weir(True)
    both = [a + b for a, b in zip(up, dn)]
    write_png(SPR + 'flume_trough.png', 48, 18, t)
    write_png(SPR + 'flume_wall.png', 8, 25, w)
    write_png(SPR + 'flume_weir.png', 20, 17, both)
    print('wrote flume_trough.png, flume_wall.png, flume_weir.png')
    if len(sys.argv) > 1:
        # a 3-tile run with the wall at the head and the weir at the end
        W, H = 3 * 48 + 12, 36
        img = [[(0, 0, 0, 0)] * W for _ in range(H)]

        def paste(src, ox, oy):
            for y in range(len(src)):
                for x in range(len(src[0])):
                    if src[y][x][3] and 0 <= y + oy < H and 0 <= x + ox < W:
                        img[y + oy][x + ox] = src[y][x]
        for k in range(3):
            paste(t, 4 + 48 * k, 18)
        paste(w, 0, 0)
        paste(up, 4 + 144 - 4, 8)
        big = side_by_side([img, t, w, up, dn], 6)
        write_png(sys.argv[1] + '/flume_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
