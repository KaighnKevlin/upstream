"""Wrecking ball: the bolted ceiling bracket with its pivot clevis and the
winch bucket hung off one end (gauge housing over it), the brass latch
(closed and open), the chain and heavy iron ball the code swings about the
pivot, and the brass pivot cap.

    python3 tools/art/gen_wrecking_ball.py [preview_dir]

Writes (measured from the node origin, the pivot; drawn for side = +1, the
code mirrors the bracket and latch with scale.x = side):
- wrecking_bracket.png  44x18, the pivot at (29, 10): the iron bracket
  x -14..14, y -8..-3, bolted at x +-11, the clevis down to the pivot; an
  arm out to x -27 carrying the gauge housing (a dark slot x -25..-10.5,
  y -7..-5, behind the code's four lights) and, hung under it,
  the banded wooden winch bucket centred on (-18, 2), rim y -4, foot y 5.
- wrecking_latch.png    2 frames of 12x11 (hframes 2), the latch pivot
  (10, -2) at (3, 3): frame 0 closed, the brass pawl hanging to y +4;
  frame 1 open, swung up and out.
- wrecking_chain.png    22x82, the pivot at (11, 2): ten links straight
  down (+y) to the ball's eye, the iron ball R 9 centred at (0, 70); the
  code rotates it by -angle.
- wrecking_cap.png      7x7, centre (3.5, 3.5): the brass pivot cap.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side
from gen_flail import ring

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]
BALL = [STEEL[0], STEEL[1], STEEL[2], STEEL[3], STEEL[4]]   # dull, heavy


def bracket():
    fig = Figure()
    # the gauge arm and housing out over the bucket
    fig.box((-27, -8.2, -13, -3.8), IRON, z=0, bevel=0.6)
    # one dark gauge slot, wide enough for the lights either way round (the
    # code draws them left to right whichever side the bucket hangs)
    fig.box((-25.2, -7.4, -10.6, -4.6), DARK[:2], z=2.4, bevel=0.2, grit=0.0)
    # the bail the bucket hangs on
    fig.capsule((-24.5, -3.6), (-23.6, -1.8), 0.45, IRON, z=0.2)
    fig.capsule((-11.5, -3.6), (-12.4, -1.8), 0.45, IRON, z=0.2)
    # the bucket: tapered oak staves, a dark mouth, two iron hoops
    fig.poly([(-24.4, -4), (-11.6, -4), (-14, 5.2), (-22, 5.2)], OAK, z=1, shade=0.55, grit=0.08)
    fig.poly([(-24.4, -4.2), (-11.6, -4.2), (-11.9, -2.9), (-24.1, -2.9)], DARK[:2], z=1.1, shade=0.5, grit=0.0)
    for x in (-21, -18, -15):
        fig.capsule((x, -2.4), (x + (x + 18) * -0.18, 4.4), 0.25, OAK[:2], z=1.05)
    fig.box((-24.2, -2.8, -11.8, -1.6), IRON, z=1.2, bevel=0.4)
    fig.box((-22.4, 2.6, -13.6, 3.8), IRON, z=1.2, bevel=0.4)
    # the ceiling bracket, bolted, and the clevis down to the pivot
    fig.box((-14.2, -8.2, 14.2, -2.8), IRON, z=2, bevel=0.9)
    for x in (-11, 11):
        fig.sphere((x, -5.6), 0.9, BRONZE, z=2.1)
    fig.box((-2.2, -3.2, 2.2, 1.6), IRON, z=2.2, bevel=0.6)
    fig.box((-0.5, -2.6, 0.5, 1.6), DARK[:2], z=2.3, bevel=0.1, grit=0.0)   # the clevis slot
    return fig.render(44, 18, (29, 10), extra=OAK_EXTRA)


def latch(closed):
    fig = Figure()
    fig.box((-1.6, -3, 1.6, -1), IRON, z=0, bevel=0.4)                 # its lug on the bracket
    if closed:
        fig.capsule((0, -1.8), (0, 4), 0.85, BRONZE, z=0.2)
        fig.capsule((0, 4), (1.8, 4.6), 0.75, BRONZE, z=0.25)          # the hook
    else:
        fig.capsule((0, -1.8), (5.2, -2.4), 0.85, BRONZE, z=0.2)
        fig.capsule((5.2, -2.4), (5.8, -0.6), 0.75, BRONZE, z=0.25)
    fig.sphere((0, -1.8), 0.7, STEEL, z=0.3)                            # the pin
    return fig.render(12, 11, (3, 3))


def chain():
    fig = Figure()
    for i in range(10):
        y = 3.4 + i * 6.3
        if i % 2 == 0:
            ring(fig, (0, y), (1.8, 2.6), 0.95, IRON, z=0.1)
        else:
            fig.capsule((0, y - 2.4), (0, y + 2.4), 0.75, IRON, z=0.2)
    fig.box((-1.8, 59.6, 1.8, 63), DARK[2:], z=0.3, bevel=0.5)          # the ball's eye
    fig.sphere((0, 70), 9.0, BALL, z=0.5, grit=0.02)
    fig.box((-8.7, 68.2, 8.7, 69.1), DARK[:3], z=0.55, bevel=0.2, grit=0.0)   # the cast seam
    for x in (-5.5, 0, 5.5):
        fig.sphere((x, 68.6), 0.55, IRON[2:], z=0.6)
    return fig.render(22, 82, (11, 2))


def cap():
    fig = Figure()
    fig.sphere((0, 0), 2.6, BRONZE, z=0)
    fig.sphere((-0.7, -0.7), 0.6, [BRONZE[5], BRONZE[6], BRONZE[7]], z=0.1)
    return fig.render(7, 7, (3.5, 3.5))


def main():
    b, c, h = bracket(), chain(), cap()
    lc, lo = latch(True), latch(False)
    write_png(SPR + 'wrecking_bracket.png', 44, 18, b)
    write_png(SPR + 'wrecking_latch.png', 24, 11, [x + y for x, y in zip(lc, lo)])
    write_png(SPR + 'wrecking_chain.png', 22, 82, c)
    write_png(SPR + 'wrecking_cap.png', 7, 7, h)
    print('wrote wrecking_bracket.png, wrecking_latch.png, wrecking_chain.png, wrecking_cap.png')
    if len(sys.argv) > 1:
        # together, hanging straight down, the latch closed
        W, H = 46, 92
        img = [[(0, 0, 0, 0)] * W for _ in range(H)]

        def paste(src, ox, oy):
            for y in range(len(src)):
                for x in range(len(src[0])):
                    if src[y][x][3] and 0 <= y + oy < H and 0 <= x + ox < W:
                        img[y + oy][x + ox] = src[y][x]
        px, py = 30, 10
        paste(b, px - 29, py - 10)
        paste(c, px - 11, py - 2)
        paste(lc, px + 10 - 3, py - 2 - 3)
        paste(h, px - 3, py - 3)
        big = side_by_side([img, b, lc, lo, c, h], 6)
        write_png(sys.argv[1] + '/wrecking_ball_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
