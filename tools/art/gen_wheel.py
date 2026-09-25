"""Gravity wheel: an overshot wheel of brass and oak with eight bucket cups
on its rim, and the stand that carries its axle. Ore riding the buckets
down one side turns it.

    python3 tools/art/gen_wheel.py [preview_dir]

Writes assets/sprites/gravity_wheel.png (66x66, axle at the centre (33, 33);
bucket k's mouth faces along the rim at angle k*45 degrees clockwise from
straight up, cups open toward the direction of travel) and wheel_stand.png
(50x40, the bearing at (25, 6); the feet on the bottom row).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
R_RIM = 24.0
N_BUCKETS = 8


def wheel():
    fig = Figure()
    # spokes (oak) from the hub to the rim
    for k in range(N_BUCKETS):
        a = math.radians(k * 45 + 22.5)
        p = (math.sin(a) * (R_RIM - 1), -math.cos(a) * (R_RIM - 1))
        fig.capsule((0, 0), p, 1.1, OAK, z=1)
    # rim: a brass band made of short capsules round the circle
    segs = 32
    for k in range(segs):
        a0, a1 = k / segs * math.tau, (k + 1) / segs * math.tau
        p0 = (math.sin(a0) * R_RIM, -math.cos(a0) * R_RIM)
        p1 = (math.sin(a1) * R_RIM, -math.cos(a1) * R_RIM)
        fig.capsule(p0, p1, 1.4, BRONZE, z=2)
    # bucket troughs on the rim: oak wedges, the dark mouth opening outward
    # and forward (clockwise), so they scoop at the top and tip at the bottom
    for k in range(N_BUCKETS):
        a = math.radians(k * 45)
        out = (math.sin(a), -math.cos(a))             # radial
        fwd = (math.cos(a), math.sin(a))              # clockwise tangent
        def at(f, o):
            return (out[0] * (R_RIM + o) + fwd[0] * f, out[1] * (R_RIM + o) + fwd[1] * f)
        fig.poly([at(-5, -1), at(4, -1), at(5, 5), at(-5, 8)], OAK, z=3, shade=0.6)
        fig.poly([at(-3.2, 1.2), at(3, 1.2), at(3.6, 4.6), at(-3.2, 6.2)], DARK, z=3.1, shade=0.3)
        fig.capsule(at(-5, -1), at(-5, 8), 0.8, BRONZE, z=3.2)   # brass-bound back edge
    # hub: brass boss with a steel gear face
    fig.disc((0, 0), 6.0, BRONZE, z=4)
    fig.gear((0, 0), 4.6, 10, 0, STEEL, z=4.1)
    fig.sphere((0, 0), 1.8, BRONZE, z=4.2)
    return fig.render(66, 66, (33, 33), extra=OAK_EXTRA)


def stand():
    fig = Figure()
    # two splayed oak legs to a brass bearing block, cross-braced
    for side in (-1, 1):
        fig.capsule((side * 2, 6), (side * 20, 38), 1.8, OAK, z=1)
        fig.ellipsoid((side * 20, 38.5), (3.4, 1.2), DARK, z=1.1)
    fig.capsule((-11, 24), (11, 24), 1.1, OAK, z=0.9)
    fig.ellipsoid((0, 6), (5, 4), BRONZE, z=2)
    fig.disc((0, 6), 2.2, DARK, z=2.1)
    return fig.render(50, 40, (25, 0), extra=OAK_EXTRA)


def main():
    w, s = wheel(), stand()
    write_png(SPR + 'gravity_wheel.png', 66, 66, w)
    write_png(SPR + 'wheel_stand.png', 50, 40, s)
    print('wrote gravity_wheel.png, wheel_stand.png')
    if len(sys.argv) > 1:
        big = side_by_side([w, s], 6)
        write_png(sys.argv[1] + '/wheel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
