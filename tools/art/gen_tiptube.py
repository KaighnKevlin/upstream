"""Tiptube: a riveted brass tube with steel collars on a pivot boss, and the
steel post it swings on (a foot plate below, a bracket for the return
spring's anchor).

    python3 tools/art/gen_tiptube.py [preview_dir]

Writes (drawn for side = +1; the code mirrors them for side = -1):
- tiptube_tube.png   54x20, the pivot at (15, 10). The tube runs along +x
  from -12 (the mouth) to +36 (the far end), 16 px across; the code
  rotates it about the pivot by the tube's angle.
- tiptube_stand.png  22x26, the pivot at (13, 3). The post runs down to a
  foot plate on row +18; the spring bracket sticks out to (-8, +14).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

TUBE_W, TUBE_H, TUBE_O = 54, 20, (15, 10)
STAND_W, STAND_H, STAND_O = 22, 26, (13, 3)


def tube():
    fig = Figure()
    # the barrel: a brass cylinder seen side-on, a dark bore line down it
    fig.box((-11, -7, 35, 7), BRONZE, z=0, bevel=4.5, grit=0.05)
    fig.capsule((-9, 3.6), (33, 3.6), 0.5, BRONZE[:4], z=0.05)          # the seam
    for x in range(-4, 32, 7):
        fig.sphere((x, 3.6), 0.5, STEEL, z=0.1)                         # seam rivets
    # steel collars at both open ends and a band at the middle
    for x0, x1 in ((-12.5, -9), (32, 36.5), (15, 17.5)):
        fig.box((x0, -8, x1, 8), STEEL, z=0.3, bevel=1.4)
    for x in (-10.8, 34.2):
        fig.sphere((x, -5.5), 0.5, BRONZE, z=0.4)
        fig.sphere((x, 5.5), 0.5, BRONZE, z=0.4)
    # the pivot boss riveted onto the barrel
    fig.disc((0, 0), 4.2, STEEL, z=0.5)
    fig.sphere((0, 0), 1.8, BRONZE, z=0.6)
    return fig.render(TUBE_W, TUBE_H, TUBE_O)


def stand():
    fig = Figure()
    fig.box((-1.6, -1, 1.6, 17), STEEL, z=0, bevel=0.8)                 # the post
    fig.capsule((0, 9), (-8, 14), 0.9, BRONZE, z=0.1)                   # spring bracket
    fig.sphere((-8, 14), 1.3, BRONZE, z=0.2)
    fig.sphere((-8, 14), 0.5, DARK, z=0.3)
    for s in (-1, 1):
        fig.capsule((0, 12), (s * 5, 17), 0.8, STEEL, z=0.05)           # gussets
    fig.box((-7, 16.5, 7, 19.5), BRONZE, z=0.3, bevel=0.6)              # foot plate
    for x in (-4.5, 4.5):
        fig.sphere((x, 18), 0.55, STEEL, z=0.4)
    fig.disc((0, 0), 3.2, BRONZE, z=0.4)                                # the bearing
    fig.disc((0, 0), 1.4, DARK, z=0.45)
    return fig.render(STAND_W, STAND_H, STAND_O)


def main():
    t, s = tube(), stand()
    write_png(SPR + 'tiptube_tube.png', TUBE_W, TUBE_H, t)
    write_png(SPR + 'tiptube_stand.png', STAND_W, STAND_H, s)
    print('wrote tiptube_tube.png, tiptube_stand.png')
    if len(sys.argv) > 1:
        big = side_by_side([t, s], 8)
        write_png(sys.argv[1] + '/tiptube_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
