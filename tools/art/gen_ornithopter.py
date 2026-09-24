"""Clockwork ornithopter: a brass flier that drops fused bombs on the dome.

    python3 tools/art/gen_ornithopter.py [preview_dir]

Writes assets/sprites/ornithopter.png (6 frames of 48x32: one wingbeat,
facing right, body centre at (22, 18)) and bomb.png (2 frames of 10x12, the
fuse spark flickering; the bomb's centre at (5, 7)).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 48, 32, (22, 18)
N = 6
MEMBRANE = DARK


def wing(fig, flap, z, far):
    """Side view of a flapping wing: root on the body's back, the tip swings
    up (flap > 0) or down (flap < 0). Leading edge is a steel spar."""
    root_f, root_b = (3, -3), (-7, -3)
    h = 13 * flap
    tip_f = (root_f[0] - 3, root_f[1] - h)
    tip_b = (root_b[0] - 6, root_b[1] - h * 0.8)
    dx = 1 if far else 0
    pts = [(root_f[0] + dx, root_f[1]), (tip_f[0] + dx, tip_f[1]), (tip_b[0] + dx, tip_b[1]), (root_b[0] + dx, root_b[1])]
    fig.poly(pts, MEMBRANE, z=z, shade=0.25 if far else 0.55)
    spar = STEEL if not far else DARK
    fig.capsule(pts[0], pts[1], 0.7, spar, z=z + 0.1)
    for t in (0.35, 0.7):  # ribs
        a = (pts[0][0] + (pts[3][0] - pts[0][0]) * t, pts[0][1])
        b = (pts[1][0] + (pts[2][0] - pts[1][0]) * t, pts[1][1] + (pts[2][1] - pts[1][1]) * t)
        fig.capsule(a, b, 0.4, spar, z=z + 0.1)


def build(i):
    ph = i / N * 2 * math.pi
    flap = math.sin(ph)
    bob = -1.2 * math.cos(ph)          # body lifts on the downstroke
    fig = Figure()
    fig.transform(0, (0, 0), (0, bob))
    wing(fig, flap, 0, True)                                           # far wing
    fig.capsule((-13, 0), (-8, 0), 1.2, BRONZE, z=1)                   # tail boom
    fig.poly([(-12, 0), (-17, -5), (-16, 0), (-17, 4)], BRONZE, z=1.1, shade=0.6)  # tail fins
    fig.ellipsoid((0, 0), (9, 4.6), BRONZE, z=2)                       # fuselage
    fig.ellipsoid((-1, -2.8), (6, 1.6), BRONZE, z=2.1, grit=0.1)       # top plate
    fig.disc((-2, 1), 3.0, DARK, z=2.2)
    fig.gear((-2, 1), 2.6, 7, i * 30, STEEL, z=2.3)                    # drive gear
    fig.ellipsoid((8.5, 0.5), (3, 3.2), STEEL, z=2.4)                  # nose cowl
    fig.sphere((9.8, 0.3), 1.8, GLOW, z=2.5, emissive=True)            # eye
    fig.capsule((1, 4), (1, 7), 0.6, STEEL, z=1.8)                     # bomb clamp
    fig.ellipsoid((1, 7.5), (2.2, 1.0), DARK, z=1.9)
    wing(fig, flap, 3, False)                                          # near wing
    return fig.render(FW, FH, O)


def bomb(k):
    fig = Figure()
    fig.sphere((0, 1), 3.6, BRONZE, z=0)
    fig.ellipsoid((0, -2.5), (1.6, 1.0), STEEL, z=1)                   # fuse cap
    fig.capsule((0, -3), (1.2, -5), 0.4, DARK, z=1.1)                  # fuse
    fig.sphere((1.4, -5.3), 0.9 + 0.4 * k, [(255, 241, 200), (245, 165, 90)], z=2, emissive=True)
    fig.capsule((-2.5, 1), (2.5, 1), 0.35, DARK, z=0.5)                # seam band
    return fig.render(10, 12, (5, 7), extra=['fff1c8', 'f5a55a'])


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'ornithopter.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    bombs = [bomb(k) for k in range(2)]
    write_png(SPR + 'bomb.png', 20, 12, [sum((b[y] for b in bombs), []) for y in range(12)])
    print('wrote ornithopter.png, bomb.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames + bombs, 6)
        write_png(sys.argv[1] + '/ornithopter_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/ornithopter.gif', frames * 4, [6] * (N * 4), 6)


if __name__ == '__main__':
    main()
