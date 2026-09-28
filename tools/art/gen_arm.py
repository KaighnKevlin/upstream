"""Robotic arm: a brass turret on a steel column, two steel arm links with
brass joints, and a steel claw.

    python3 tools/art/gen_arm.py [preview_dir]

Writes:
- arm_base.png   24x24, the node origin (the turret's foot, centre) at
  (12, 22); the shoulder boss is at (0, -16).
- arm_upper.png  27x9, the shoulder at (4, 4); the link runs +x 20 px to
  the elbow (drawn there as a brass knuckle). Rotated to the link's angle.
- arm_lower.png  25x9, the elbow at (4, 4); the link runs +x 18 px to the
  wrist. Rotated to the link's angle.
- arm_claw.png   2 frames of 14x10 (open, shut), the wrist at (7, 2);
  the fingers hang down about 5 px. Not rotated.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:5]


def base():
    fig = Figure()
    fig.box((-2, -15, 2, -4), IRON, z=0, bevel=0.8)                 # the column
    fig.box((-10, -6, 10, 0.5), BRONZE, z=0.2, bevel=1.0)            # the turret drum
    fig.box((-10.5, -1.2, 10.5, 1), STEEL, z=0.3, bevel=0.5)         # its steel foot ring
    for x in (-7, 7):
        fig.sphere((x, -3.2), 0.6, STEEL, z=0.4)
    fig.disc((0, -3), 2.3, DARK, z=0.35)                             # the filter lamp's bezel
    fig.disc((0, -16), 4.6, BRONZE, z=0.5)                           # the shoulder boss
    fig.sphere((0, -16), 1.6, STEEL, z=0.6)
    return fig.render(24, 24, (12, 22))


def link(length, knuckle):
    fig = Figure()
    fig.box((-1, -1.6, length + 0.5, 1.6), STEEL, z=0, bevel=0.8)
    fig.box((length * 0.35, -2.1, length * 0.55, 2.1), BRONZE, z=0.1, bevel=0.5)   # a clamp band
    if knuckle:
        fig.disc((length, 0), 2.8, BRONZE, z=0.3)
        fig.sphere((length, 0), 1.0, STEEL, z=0.4)
    else:
        fig.disc((length, 0), 1.9, STEEL, z=0.3)
    return fig.render(int(length) + 7, 9, (4, 4))


def claw(open_):
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1.0, 1.0), (s * open_, 4.0), 0.75, STEEL, z=0)
        fig.capsule((s * open_, 4.0), (s * (open_ - 1.2), 6.0), 0.6, STEEL, z=0.1)
    fig.box((-2.4, -1.4, 2.4, 1.8), BRONZE, z=0.3, bevel=0.6)       # the wrist block
    return fig.render(14, 10, (7, 2))


def main():
    b, u, l = base(), link(20, True), link(18, False)
    c0, c1 = claw(4.0), claw(2.5)
    write_png(SPR + 'arm_base.png', 24, 24, b)
    write_png(SPR + 'arm_upper.png', len(u[0]), 9, u)
    write_png(SPR + 'arm_lower.png', len(l[0]), 9, l)
    sheet = [c0[y] + c1[y] for y in range(10)]
    write_png(SPR + 'arm_claw.png', 28, 10, sheet)
    print('wrote arm_base.png, arm_upper.png, arm_lower.png, arm_claw.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, u, l, c0, c1], 6)
        write_png(sys.argv[1] + '/arm_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
