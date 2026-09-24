"""Clockwork scuttler: small, fast, beetle-like (replaces the goblin).

    python3 tools/art/gen_scuttler.py [preview_dir]

Writes assets/sprites/scuttler_walk.png (6 frames of FW x FH, facing right).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH = 44, 36
ORIGIN = (20, 34)   # figure (0, 0) = between the feet on the ground
N = 6

HIPS = [(-5, -12, -1.3), (0, -11.5, -0.15), (5, -12, 1.2)]  # x, y, splay


def leg(fig, hip, phase, near):
    """Spider leg: rises out and up to a knee, then angles down to the foot."""
    hx, hy, splay = hip
    swing = math.cos(phase)
    lift = max(0.0, math.sin(phase)) * 2.5
    fx = hx + splay * 7.5 + swing * 2.5
    fy = -lift
    kx = hx + splay * 5.0 + swing * 1.2
    ky = hy - 3.5 - lift * 0.4
    mat = STEEL if near else DARK
    z = 9 if near else 1
    fig.capsule((hx, hy), (kx, ky), 0.95, mat, z=z)
    fig.capsule((kx, ky), (fx, fy), 0.8, mat, z=z + 0.1)
    fig.sphere((kx, ky), 1.25, BRONZE if near else DARK, z=z + 0.2)  # knee joint


def build(i):
    ph = i / N * 2 * math.pi
    bob = abs(math.sin(ph * 2)) * 0.8
    fig = Figure()
    # far legs (the other tripod), then body, then near legs
    for k, hip in enumerate(HIPS):
        leg(fig, (hip[0] + 1, hip[1] - 1, hip[2]), ph + (0 if k == 1 else math.pi), False)
    by = -13 - bob
    fig.ellipsoid((0, by + 3.5), (9.5, 3.5), DARK, z=4)                 # belly
    fig.ellipsoid((0, by), (11, 7.5), BRONZE, z=5)                      # shell
    fig.ellipsoid((-1.5, by - 4), (6.5, 3), BRONZE, z=6, grit=0.1)      # ridge plate
    fig.disc((-2.5, by + 0.5), 5.2, DARK, z=6.8)                        # gear recess
    fig.gear((-2.5, by + 0.5), 4.6, 9, i * 13, STEEL, z=7)              # turning gear
    fig.sphere((-2.5, by + 0.5), 1.2, BRONZE, z=7.5)                    # axle
    fig.disc((9.2, by - 0.8), 4.4, DARK, z=10)                          # eye socket
    fig.sphere((9.8, by - 0.9), 3.3, GLOW, z=10.5, emissive=True)       # core eye
    # wind-up key on the back, spinning (seen side-on: width follows cos)
    ka = i / N * math.pi * 2
    fig.capsule((-7, by - 5), (-9.5, by - 8.5), 0.8, STEEL, z=3)
    kw = 0.6 + 3.2 * abs(math.cos(ka))
    kz = 3 if math.cos(ka) > 0 else 6.5
    fig.ellipsoid((-10.8, by - 10.8), (kw, 2.8), BRONZE, z=kz, grit=0.03)
    if kw > 2:  # the bow's hole shows when it turns to face us
        fig.ellipsoid((-10.8, by - 10.8), (kw * 0.4, 1.1), DARK, z=kz + 0.1, grit=0.0)
    for k, hip in enumerate(HIPS):
        leg(fig, hip, ph + (math.pi if k == 1 else 0), True)
    return fig.render(FW, FH, ORIGIN)


def main():
    frames = [build(i) for i in range(N)]
    rows = [sum((f[y] for f in frames), []) for y in range(FH)]
    write_png(SPR + 'scuttler_walk.png', FW * N, FH, rows)
    print('wrote scuttler_walk.png (%d frames)' % N)
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/scuttler_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/scuttler_walk.gif', frames, [9] * N, 8)


if __name__ == '__main__':
    main()
