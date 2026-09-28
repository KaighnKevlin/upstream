"""Transfer arm: a steel arm on a brass pivot boss, a beaten-brass scoop
on the long end and an iron counterweight on the short one; the stand is
a steel leg down to a foot bracket, with a brass cradle rail at the catch.

    python3 tools/art/gen_transfer_arm.py [preview_dir]

Writes (drawn for side = +1; the code mirrors them for side = -1):
- transfer_arm.png    22x68, the pivot at (11, 20); the arm hangs straight
  down: counterweight centre at y -12, the cup at y 36 (a 8 px bowl round
  (0, 35), open toward the pivot). The code rotates it by the arm's angle.
- transfer_stand.png  58x60, the pivot at (38, 7); the leg runs to
  (10, 46), the foot at y 47, the cradle rail at y 39.6 from x -33 to -11.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

ARM, REST = 36.0, 0.5
AW, AH, AO = 22, 68, (11, 20)
SW, SH, SO = 58, 60, (38, 7)
IRON = STEEL[:5]


def arm():
    fig = Figure()
    fig.box((-1.6, -12, 1.6, 36), STEEL, z=0, bevel=0.8)           # the arm bar
    for y in (8, 20):
        fig.box((-2.4, y - 1, 2.4, y + 1), BRONZE, z=0.1, bevel=0.5)
    # the counterweight: an iron block on the short end
    fig.sphere((0, -12.5), 4.8, IRON, z=0.3, grit=0.03)
    fig.box((-5, -13.2, 5, -11.8), BRONZE, z=0.4, bevel=0.4)
    # the scoop: a brass bowl open toward the pivot
    pts = [(math.cos(math.pi * k / 12) * 8, 35 + math.sin(math.pi * k / 12) * 8) for k in range(13)]
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 1.4, BRONZE, z=0.5)
    fig.box((-8.6, 33.2, -6.4, 36.4), STEEL, z=0.6, bevel=0.5)      # steel lip caps
    fig.box((6.4, 33.2, 8.6, 36.4), STEEL, z=0.6, bevel=0.5)
    # the pivot boss
    fig.disc((0, 0), 4.2, BRONZE, z=0.8)
    fig.disc((0, 0), 2.0, DARK, z=0.9)
    return fig.render(AW, AH, AO)


def stand():
    fig = Figure()
    fig.capsule((0, 0), (10, 45), 1.8, STEEL, z=0)                    # the leg
    fig.capsule((2, 16), (-4, 7), 1.0, IRON, z=-0.1)                   # a strut back to the wall
    fig.box((3, 44.5, 17, 48.5), IRON, z=0.1, bevel=0.7)               # the foot bracket
    for x in (5.5, 14.5):
        fig.sphere((x, 46.5), 0.6, BRONZE, z=0.2)
    fig.disc((0, 0), 5.5, STEEL, z=0.2)                                # the bearing plate
    for a in range(0, 360, 90):
        fig.sphere((math.cos(math.radians(a + 45)) * 4, math.sin(math.radians(a + 45)) * 4), 0.55, BRONZE, z=0.3)
    # the cradle rail at the catch, on a bracket from the leg
    cx, cy = -math.sin(REST) * ARM, math.cos(REST) * ARM
    fig.box((cx - 16, cy + 7, cx + 6, cy + 9.4), BRONZE, z=0.3, bevel=0.6)
    fig.capsule((cx + 5, cy + 9), (8.5, 38), 1.0, IRON, z=0.2)
    fig.box((cx - 17, cy + 3.5, cx - 15, cy + 9.4), BRONZE, z=0.35, bevel=0.5)   # a stop at the back
    return fig.render(SW, SH, SO)


def main():
    a, s = arm(), stand()
    write_png(SPR + 'transfer_arm.png', AW, AH, a)
    write_png(SPR + 'transfer_stand.png', SW, SH, s)
    print('wrote transfer_arm.png, transfer_stand.png')
    if len(sys.argv) > 1:
        big = side_by_side([a, s], 4)
        write_png(sys.argv[1] + '/transfer_arm_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
