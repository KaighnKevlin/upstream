"""Kicker: a steel spring cylinder with a brass gland and a lamp bezel on a
stalk (the code lights the lamp in the mode's colour), and the punch: a
brass-faced plate on a polished rod that slides out of the cylinder.

    python3 tools/art/gen_kicker.py [preview_dir]

Writes (drawn for side = +1, punching right; mirrored in code for -1):
- kicker_body.png   22x22, the node origin at (30, 11). The cylinder runs
  x -25..-14 on y -1..9 (centre -20, 4); the lamp bezel is centred on
  (-20, -6), its lit middle 2 px across, left clear for the code.
- kicker_plate.png  28x16, the plate face's centre at (24, 8): the plate
  is x -2..2, y -6..6, the rod runs back to x -17 (it stays in the cylinder).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

BODY_W, BODY_H, BODY_O = 22, 22, (30, 11)
PLATE_W, PLATE_H, PLATE_O = 28, 16, (24, 8)


def body():
    fig = Figure()
    fig.box((-25, -1, -15.5, 9), STEEL, z=0, bevel=2.4)                    # the cylinder
    fig.box((-25.5, -1.8, -23.2, 9.8), BRONZE, z=0.2, bevel=0.7)           # rear cap
    fig.box((-16.6, -1.8, -14.2, 9.8), BRONZE, z=0.2, bevel=0.7)           # the gland
    fig.capsule((-22, 1.2), (-18, 1.2), 0.4, STEEL[3:], z=0.1)           # a highlight seam
    for x in (-21.5, -18.5):
        fig.sphere((x, 6.5), 0.5, BRONZE, z=0.3)
    fig.box((-20.8, -4, -19.2, -1), BRONZE, z=0.1, bevel=0.4)             # lamp stalk
    fig.disc((-20, -6), 3.1, BRONZE, z=0.4)                               # lamp bezel
    img = fig.render(BODY_W, BODY_H, BODY_O)
    # clear the lamp's middle: the code draws the lit colour there
    ox, oy = BODY_O
    for y in range(-8, -4):
        for x in range(-22, -18):
            if (x + 0.5 + 20) ** 2 + (y + 0.5 + 6) ** 2 <= 2.3:
                img[y + oy][x + ox] = (0, 0, 0, 0)
    return img


def plate():
    fig = Figure()
    fig.capsule((-16, 0), (-2, 0), 1.1, STEEL, z=0)                      # the rod
    fig.box((-2.4, -6.4, 0.4, 6.4), STEEL, z=0.1, bevel=0.6)             # backing plate
    fig.box((0, -6, 2.4, 6), BRONZE, z=0.2, bevel=0.6)                   # the brass face
    for y in (-4, 4):
        fig.sphere((-1, y), 0.5, BRONZE, z=0.3)
    return fig.render(PLATE_W, PLATE_H, PLATE_O)


def main():
    b, p = body(), plate()
    write_png(SPR + 'kicker_body.png', BODY_W, BODY_H, b)
    write_png(SPR + 'kicker_plate.png', PLATE_W, PLATE_H, p)
    print('wrote kicker_body.png, kicker_plate.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, p], 10)
        write_png(sys.argv[1] + '/kicker_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
