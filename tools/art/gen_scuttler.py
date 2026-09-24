"""Clockwork scuttler: small, fast, beetle-like (replaces the goblin).

    python3 tools/art/gen_scuttler.py [preview_dir]

Writes assets/sprites/scuttler_walk.png (6 frames of FW x FH, facing right)
and scuttler_pounce.png (6 frames: crouch, crouch deeper with the core
flaring, leap with legs tucked, nose-down, core white-hot x2). The game
tweens the leap arc and detonates it against the dome on the last frame.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH = 44, 36
ORIGIN = (20, 34)   # figure (0, 0) = between the feet on the ground
N = 6

HIPS = [(-5, -12, -1.3), (0, -11.5, -0.15), (5, -12, 1.2)]  # x, y, splay


def leg(fig, hip, phase, near, tuck=0.0, crouch=0.0):
    """Spider leg: rises out and up to a knee, then angles down to the foot.
    crouch splays the feet wider; tuck pulls them up under the body."""
    hx, hy, splay = hip
    swing = math.cos(phase)
    lift = max(0.0, math.sin(phase)) * 2.5
    fx = hx + splay * (7.5 + crouch * 2.5) + swing * 2.5 * (1 - tuck)
    fy = -lift + tuck * (hy + 8.5)
    kx = hx + splay * (5.0 + crouch * 1.5) + swing * 1.2
    ky = hy - 3.5 - lift * 0.4 + tuck * 1.5
    mat = STEEL if near else DARK
    z = 9 if near else 1
    fig.capsule((hx, hy), (kx, ky), 0.95, mat, z=z)
    fig.capsule((kx, ky), (fx, fy), 0.8, mat, z=z + 0.1)
    fig.sphere((kx, ky), 1.25, BRONZE if near else DARK, z=z + 0.2)  # knee joint


def build(i, crouch=0.0, tuck=0.0, flare=0.0, tilt=0.0, rise=0.0, key_speed=1.0):
    ph = i / N * 2 * math.pi
    bob = abs(math.sin(ph * 2)) * 0.8 if not (crouch or tuck) else 0.0
    if crouch or tuck:
        ph = 0.0  # legs planted / tucked, no gait
    fig = Figure()
    if tilt or rise:
        fig.transform(tilt, (0, -13), (0, -rise))
    hips = [(x, y + crouch * 3, sp) for x, y, sp in HIPS]
    # far legs (the other tripod), then body, then near legs
    for k, hip in enumerate(hips):
        leg(fig, (hip[0] + 1, hip[1] - 1, hip[2]), ph + (0 if k == 1 else math.pi), False, tuck, crouch)
    by = -13 - bob + crouch * 3
    fig.ellipsoid((0, by + 3.5), (9.5, 3.5), DARK, z=4)                 # belly
    fig.ellipsoid((0, by), (11, 7.5), BRONZE, z=5)                      # shell
    fig.ellipsoid((-1.5, by - 4), (6.5, 3), BRONZE, z=6, grit=0.1)      # ridge plate
    fig.disc((-2.5, by + 0.5), 5.2, DARK, z=6.8)                        # gear recess
    fig.gear((-2.5, by + 0.5), 4.6, 9, i * 13, STEEL, z=7)              # turning gear
    fig.sphere((-2.5, by + 0.5), 1.2, BRONZE, z=7.5)                    # axle
    fig.disc((9.2, by - 0.8), 4.4, DARK, z=10)                          # eye socket
    fig.sphere((9.8, by - 0.9), 3.3 + flare * 1.2, GLOW, z=10.5, emissive=True)  # core eye
    if flare > 0.5:  # overloading: seams glow, sparks off the eye
        fig.capsule_glow((-6, by - 1.5), (5, by - 3), 0.5, z=6.9)
        fig.capsule_glow((-4, by + 4.5), (6, by + 3.5), 0.45, z=6.9)
        bolt(fig, (12, by - 2), (16, by - 6), seed=i * 5 + 1, jag=1.0, segs=3)
        bolt(fig, (12, by + 1), (16.5, by + 3), seed=i * 5 + 2, jag=1.0, segs=3)
    # wind-up key on the back, spinning (seen side-on: width follows cos)
    ka = i / N * math.pi * 2 * key_speed
    fig.capsule((-7, by - 5), (-9.5, by - 8.5), 0.8, STEEL, z=3)
    kw = 0.6 + 3.2 * abs(math.cos(ka))
    kz = 3 if math.cos(ka) > 0 else 6.5
    fig.ellipsoid((-10.8, by - 10.8), (kw, 2.8), BRONZE, z=kz, grit=0.03)
    if kw > 2:  # the bow's hole shows when it turns to face us
        fig.ellipsoid((-10.8, by - 10.8), (kw * 0.4, 1.1), DARK, z=kz + 0.1, grit=0.0)
    for k, hip in enumerate(hips):
        leg(fig, hip, ph + (math.pi if k == 1 else 0), True, tuck, crouch)
    return fig.render(FW, FH, ORIGIN)


def main():
    frames = [build(i) for i in range(N)]
    rows = [sum((f[y] for f in frames), []) for y in range(FH)]
    write_png(SPR + 'scuttler_walk.png', FW * N, FH, rows)
    pounce = [build(0, crouch=0.6, key_speed=2.5), build(1, crouch=1.0, flare=0.4, key_speed=2.5),
              build(2, tuck=0.6, flare=0.7, tilt=-12, rise=2, key_speed=3),
              build(3, tuck=1.0, flare=0.9, tilt=8, rise=0, key_speed=3),
              build(4, tuck=1.0, flare=1.3, tilt=18, rise=0, key_speed=3),
              build(5, tuck=1.0, flare=1.8, tilt=22, rise=0, key_speed=3)]
    rows = [sum((f[y] for f in pounce), []) for y in range(FH)]
    write_png(SPR + 'scuttler_pounce.png', FW * len(pounce), FH, rows)
    print('wrote scuttler_walk.png (%d frames), scuttler_pounce.png' % N)
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/scuttler_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/scuttler_walk.gif', frames, [9] * N, 8)
        big = side_by_side(pounce, 8)
        write_png(sys.argv[1] + '/scuttler_pounce_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
