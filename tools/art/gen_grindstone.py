"""Grindstone: a dressed millstone on an iron axle, held in an oak A-frame
over an iron-banded stone trough (open at both ends, in line with the
track).

    python3 tools/art/gen_grindstone.py [preview_dir]

Writes (from the piece's origin, the middle of the bed's top face):
- grindstone_bed.png    48x36, origin at (24, 27): the trough along y 0..7,
  +-21 wide; the A-frame from (+-12, 0) up to the axle at (0, -13).
- grindstone_stone.png  6 frames of 24x24, the axle at (12, 12): the stone
  (radius 10) turned 0, 15 .. 75 degrees clockwise. Its dressing is 4-fold,
  so the six cover a full turn; the code picks one from its angle.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
FRAMES, SW = 6, 24


def bed():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 12, 0), (s * 2.5, -14), 1.4, OAK, z=0)             # the A-frame legs
        fig.box((s * 12 - 2.5, -1.5, s * 12 + 2.5, 0.5), STEEL, z=0.1, bevel=0.5)
    fig.capsule((-7.5, -6), (7.5, -6), 0.8, OAK, z=0.05)                      # its cross tie
    fig.disc((0, -13), 3.2, STEEL, z=0.2)                                        # the bearing behind the stone
    fig.box((-21, 0, 21, 7), ROCK, z=0.3, bevel=1.2)                             # the trough
    fig.box((-19.5, 0.3, 19.5, 1.6), ROCK[3:], z=0.35, bevel=0.4)              # its worn lip
    fig.box((-17, 2.5, 17, 5.5), ROCK[1:4], z=0.33, bevel=0.8, grit=0.02)                  # the channel face
    for x in (-18, 17):
        fig.box((x - 1, 0, x + 1, 7), STEEL, z=0.4, bevel=0.4)                 # iron bands
    for x in (-10, 10):
        fig.sphere((x, 4), 0.55, ROCK[4:], z=0.4)
    return fig.render(48, 36, (24, 27), extra=OAK_EXTRA)


def stone(deg):
    fig = Figure()
    fig.transform(deg, (0, 0))
    fig.disc((0, 0), 10, ROCK[2:], z=0)
    fig.disc((0, 0), 7.2, ROCK[2:5], z=0.1)                                      # the worn face
    for i in range(4):
        a = math.radians(i * 90 + 20)
        d = (math.cos(a), math.sin(a))
        fig.capsule((d[0] * 3.2, d[1] * 3.2), (d[0] * 9.2, d[1] * 9.2), 0.7, DARK, z=0.2)    # dressing grooves
    fig.disc((0, 0), 3.0, BRONZE[:6], z=0.3)                                            # the hub
    fig.box((-1.1, -1.1, 1.1, 1.1), STEEL, z=0.4, bevel=0.5)                    # the square axle end
    return fig.render(SW, SW, (SW // 2, SW // 2))


def main():
    b = bed()
    frames = [stone(k * 90 / FRAMES) for k in range(FRAMES)]
    sheet = [sum((f[y] for f in frames), []) for y in range(SW)]
    write_png(SPR + 'grindstone_bed.png', 48, 36, b)
    write_png(SPR + 'grindstone_stone.png', SW * FRAMES, SW, sheet)
    print('wrote grindstone_bed.png, grindstone_stone.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, sheet], 8)
        write_png(sys.argv[1] + '/grindstone_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
