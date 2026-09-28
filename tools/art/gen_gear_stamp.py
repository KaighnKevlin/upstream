"""Gear stamp: a small drop hammer. Two steel posts under a brass
crossbeam, a waisted iron anvil with a gear-shaped die in its face, and a
steel hammer head on a rod.

    python3 tools/art/gen_gear_stamp.py [preview_dir]

Writes (from the piece's origin, the middle of its feet):
- gear_stamp_frame.png   40x62, origin at (20, 60): posts at x +-14 from
  the floor to the beam on y -57..-52; the anvil's face along y -16,
  +-12 wide, waisted down to its foot on y -4..0.
- gear_stamp_hammer.png  18x12, the middle of its striking face at (9, 10):
  the head is 14 x 8 with a collar on top for the rod.
- gear_stamp_rod.png     4x4, the rod, tiled down from the beam.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:5]


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.box((s * 14 - 2, -55, s * 14 + 2, -1), STEEL, z=0, bevel=0.8)      # the posts
        for y in (-40, -24):
            fig.sphere((s * 14, y), 0.6, BRONZE, z=0.1)
        fig.box((s * 14 - 3.5, -3, s * 14 + 3.5, 0), BRONZE, z=0.2, bevel=0.6)  # their feet
        fig.capsule((s * 14, -46), (s * 5, -54), 0.9, STEEL[:6], z=0.05)      # knee braces
    fig.box((-17, -57.5, 17, -51.5), BRONZE, z=0.3, bevel=0.9)                 # the crossbeam
    for x in (-14, 14):
        fig.sphere((x, -54.5), 0.8, STEEL, z=0.4)
    fig.box((-3, -52, 3, -49.5), STEEL, z=0.35, bevel=0.5)                      # the rod's guide
    # the anvil: a steel face, a waisted iron body, a foot
    fig.poly([(-12, -16), (12, -16), (10, -11), (5, -9), (5, -4), (-5, -4), (-5, -9), (-10, -11)], IRON, z=0.3, shade=0.4)
    fig.box((-12.2, -16.3, 12.2, -12.6), STEEL, z=0.4, bevel=0.7)             # the face
    fig.capsule((-11, -15.9), (11, -15.9), 0.4, STEEL[5:], z=0.45)            # its bright top edge
    fig.disc((0, -13.6), 2.5, DARK, z=0.5)                                      # the gear die, a brass gear set in
    fig.gear((0, -13.6), 1.8, 6, 0, BRONZE, z=0.55)
    fig.box((-9, -4.5, 9, 0), IRON, z=0.35, bevel=0.8)                         # the foot
    for x in (-6.5, 6.5):
        fig.sphere((x, -2.2), 0.6, BRONZE, z=0.4)
    return fig.render(40, 62, (20, 60))


def hammer():
    fig = Figure()
    fig.box((-7, -8, 7, 0), STEEL, z=0, bevel=1.0)
    fig.box((-6.5, -2, 6.5, -0.2), IRON[:4], z=0.1, bevel=0.5)                # the striking face
    fig.box((-7.4, -6.5, 7.4, -5), BRONZE, z=0.2, bevel=0.4)                   # a brass band
    fig.box((-2.5, -10, 2.5, -7.5), BRONZE, z=0.2, bevel=0.6)                  # the rod collar
    return fig.render(18, 12, (9, 10))


def rod():
    fig = Figure()
    fig.box((-1, -2, 1, 6), STEEL, z=0, bevel=0.9, grit=0.0)
    img = fig.render(4, 4, (2, 0), outline=False)
    for y in range(4):
        img[y][0] = img[y][3] = (41, 38, 31, 255)
    return img


def main():
    parts = [('gear_stamp_frame', frame()), ('gear_stamp_hammer', hammer()), ('gear_stamp_rod', rod())]
    for name, img in parts:
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(n + '.png' for n, _ in parts))
    if len(sys.argv) > 1:
        big = side_by_side([p[1] for p in parts], 8)
        write_png(sys.argv[1] + '/gear_stamp_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
