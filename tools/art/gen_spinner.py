"""Spinner: an iron A-bracket with a brass power gauge on its head, the
four-bladed brass vane the code turns under it, and the hub cap on its axle.

    python3 tools/art/gen_spinner.py [preview_dir]

Writes (all measured from the axle, the node origin; blade length R = 12):
- spinner_bracket.png  22x30, the axle at (11, 27): two iron legs from the
  head bar (y -18, x -9..9) in to a bearing at the axle, and the gauge on
  top, a brass bezel round a dark slot at y -23 (x -5..5) that the code
  fills with the power.
- spinner_vane.png     28x28, centre (14, 14): four brass paddles, each
  creased down the middle and flaring from the hub out to r 12 with a
  steel tip; the code rotates it.
- spinner_hub.png      8x8, centre (4, 4): the steel hub with a brass cap.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def bracket():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 7, -18), (s * 0.8, -1), 1.2, STEEL, z=0)         # the legs
    fig.box((-9.6, -19.4, 9.6, -16.6), STEEL, z=0.2, bevel=0.7)          # the head bar
    for x in (-7.5, 7.5):
        fig.sphere((x, -18), 0.6, BRONZE, z=0.3)                         # bolts
    fig.box((-7.2, -25.2, 7.2, -20.6), BRONZE, z=0.4, bevel=0.8)         # the gauge bezel
    fig.box((-5.6, -23.8, 5.6, -21.8), DARK, z=0.5, bevel=0.2, grit=0.0)   # its slot
    fig.box((-1.2, -21, 1.2, -19), STEEL, z=0.35, bevel=0.4)             # the gauge's stem
    fig.disc((0, 0), 2.6, STEEL, z=0.1)                                  # the bearing
    return fig.render(22, 30, (11, 27))


def vane():
    fig = Figure()
    for k in range(4):
        a = k * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        rot = lambda u, v: (u * c - v * s, u * s + v * c)
        # a paddle: narrow at the hub, flaring to the tip
        fig.poly([rot(2, -1.2), rot(10.5, -2.4), rot(10.5, 2.4), rot(2, 1.2)], BRONZE, z=0.1, shade=0.55)
        fig.poly([rot(2, 0), rot(10.5, 0), rot(10.5, 2.4), rot(2, 1.2)], BRONZE, z=0.11, shade=0.8)   # its lit half
        fig.capsule(rot(3, 0), rot(9.6, 0), 0.4, [BRONZE[1], BRONZE[2]], z=0.15)   # a pressed rib
        fig.box((10.2 * c - 1.2, 10.2 * s - 1.2, 10.2 * c + 1.2, 10.2 * s + 1.2), STEEL, z=0.2, bevel=0.6,
                tilt=math.degrees(a))                                    # the steel tip
        fig.capsule(rot(10.4, -2.3), rot(10.4, 2.3), 0.9, STEEL, z=0.2)
    fig.disc((0, 0), 2.8, BRONZE, z=0.05)
    return fig.render(28, 28, (14, 14))


def hub():
    fig = Figure()
    fig.disc((0, 0), 2.9, STEEL, z=0)
    fig.sphere((0, 0), 1.7, BRONZE, z=0.1)
    return fig.render(8, 8, (4, 4))


def main():
    b, v, h = bracket(), vane(), hub()
    write_png(SPR + 'spinner_bracket.png', 22, 30, b)
    write_png(SPR + 'spinner_vane.png', 28, 28, v)
    write_png(SPR + 'spinner_hub.png', 8, 8, h)
    print('wrote spinner_bracket.png, spinner_vane.png, spinner_hub.png')
    if len(sys.argv) > 1:
        # and the three stacked, as the game shows them
        both = [[(0, 0, 0, 0)] * 28 for _ in range(44)]
        for img, ox, oy in ((b, 3, 0), (v, 0, 13), (h, 10, 23)):
            for y in range(len(img)):
                for x in range(len(img[0])):
                    if img[y][x][3]:
                        both[y + oy][x + ox] = img[y][x]
        big = side_by_side([b, v, h, both], 8)
        write_png(sys.argv[1] + '/spinner_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
