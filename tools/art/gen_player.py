"""The player: a prospector in a brass dome helmet with a headlamp.

    python3 tools/art/gen_player.py [preview_dir]

Writes assets/sprites/prospector.png: one strip of 32x40 frames, facing right,
feet at (16, 38) so the frame centre is the body centre:
  frames 0-3 idle, 4-11 run, 12-13 jump, 14-16 pickaxe swing (raise, strike,
  follow-through).
Also assets/sprites/pickaxe.png (24x16): handle along +x from the butt at
(2, 8) (the pivot, held at the shoulder), head at the far end with the pick
tip on the +y side so it leads a clockwise swing.
"""
import math, sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH = 32, 40
ORIGIN = (16, 38)
SKIN_EXTRA = ['6b3d2a', 'a8694a', 'd49a72', 'f0c8a0']
LAMP_EXTRA = ['fff1c8']
SKIN = [_hex(h) for h in SKIN_EXTRA]
LAMP = [_hex(h) for h in ('a88f67', 'd9c27e', 'e2cb94', 'fff1c8')]
LEATHER = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c', '8d7051', 'a88f67')]
CLOTH = [_hex(h) for h in ('29261f', '29261f', '353c42', '3a494a', '4f3d43', '605d55')]
BEARD = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c')]
COAT = [_hex(h) for h in ('29261f', '353c42', '3a494a', '5f7c83', '709092', '93a29c')]  # slate teal
THIGH, SHIN = 5.5, 5.5


def limb(fig, a, ang, bend, l1, l2, mat, r1, r2, z):
    t = math.radians(ang)
    k = (a[0] + l1 * math.sin(t), a[1] + l1 * math.cos(t))
    s = t - math.radians(bend)
    e = (k[0] + l2 * math.sin(s), k[1] + l2 * math.cos(s))
    fig.capsule(a, k, r1, mat, z=z)
    fig.capsule(k, e, r2, mat, z=z + 0.1)
    return k, e


def build(legs=(0, 0), bends=(8, 8), arms=(0, 0), bob=0.0, lamp=1.0):
    fig = Figure()
    hip = (0, -12 + bob)
    near_leg, far_leg = legs
    # far leg / far arm (darker, behind)
    _, fe = limb(fig, (hip[0] - 0.5, hip[1]), far_leg, bends[1], THIGH, SHIN, BEARD, 1.5, 1.35, 1)
    fig.ellipsoid((fe[0] + 1, fe[1] - 0.3), (2.3, 1.2), CLOTH, z=1.3)
    sh = (0.5, -20.5 + bob)
    limb(fig, (sh[0] - 1, sh[1]), -arms[0], -20, 4.2, 4.0, CLOTH, 1.3, 1.1, 2)
    # backpack tank + gauge
    fig.box((-6.4, -24.5 + bob, -3.0, -15 + bob), BRONZE, z=3, bevel=1.3)
    fig.ellipsoid((-4.7, -24.5 + bob), (1.7, 0.8), BRONZE, z=3.1)
    fig.disc((-4.7, -19.5 + bob), 1.2, DARK, z=3.2)
    fig.sphere((-4.7, -19.5 + bob), 0.8, GLOW, z=3.3, emissive=True)
    # body: coat, belt
    fig.ellipsoid((0, -17.5 + bob), (3.8, 5.8), COAT, z=4)
    fig.box((-3.8, -13.6 + bob, 3.8, -12.2 + bob), DARK, z=4.2, bevel=0.5)
    fig.box((0.6, -13.8 + bob, 2.4, -12.0 + bob), BRONZE, z=4.3, bevel=0.5)       # buckle
    # near leg
    _, ne = limb(fig, hip, near_leg, bends[0], THIGH, SHIN, LEATHER, 1.6, 1.45, 5)
    fig.ellipsoid((ne[0] + 1, ne[1] - 0.3), (2.4, 1.3), CLOTH, z=5.3)
    # head: face, eye, short beard, brass helmet with brim, goggles, lamp
    hx, hy = 1.4, -26.3 + bob
    fig.ellipsoid((hx, hy), (3.1, 3.3), SKIN, z=6, grit=0.03)
    fig.sphere((hx + 1.7, hy - 0.2), 0.5, DARK, z=6.15)                           # eye
    fig.ellipsoid((hx + 0.8, hy + 2.3), (2.1, 1.1), BEARD, z=6.1, grit=0.1)       # beard
    fig.sphere((hx + 2.8, hy + 0.5), 0.75, SKIN, z=6.2)                           # nose
    fig.ellipsoid((hx - 0.4, hy - 2.9), (3.8, 2.5), BRONZE, z=6.5)                 # helmet
    fig.ellipsoid((hx + 0.3, hy - 1.5), (4.6, 0.8), BRONZE, z=6.6, grit=0.03)      # brim
    fig.disc((hx + 1.2, hy - 3.2), 1.0, STEEL, z=6.7)                             # goggle
    fig.sphere((hx + 3.3, hy - 3.0), 1.3, LAMP, z=6.8, emissive=True)              # headlamp
    # near arm (swings), hand
    _, hand = limb(fig, sh, arms[1], -24, 4.2, 4.0, COAT, 1.4, 1.2, 7)
    fig.sphere(hand, 1.2, SKIN, z=7.2)
    return fig.render(FW, FH, ORIGIN, extra=SKIN_EXTRA + LAMP_EXTRA)


def pickaxe():
    fig = Figure()
    fig.capsule((0, 0), (16, 0), 0.9, LEATHER, z=0, grit=0.1)           # wooden handle
    fig.ellipsoid((15, 0), (1.2, 1.5), BRONZE, z=1)                     # brass ferrule
    # head: long point on +y (leads the swing), short adze on -y
    fig.capsule((17, -3.5), (17.5, 0), 1.3, STEEL, z=2)
    fig.capsule((17.5, 0), (16.5, 4.5), 1.2, STEEL, z=2)
    fig.capsule((16.5, 4.5), (14.8, 6.8), 0.7, STEEL, z=2.1)             # point
    fig.box((16, -5.2, 19, -3.4), STEEL, z=2.2, bevel=0.6)               # adze
    return fig.render(24, 16, (2, 8))


def main():
    idle = [build(bob=0.5 * math.sin(i / 4 * math.tau)) for i in range(4)]
    run = []
    for i in range(8):
        p = i / 8 * math.tau
        s = math.sin(p)
        run.append(build(legs=(34 * s, -34 * s),
                         bends=(max(0.0, math.sin(p + 1.0)) * 70 + 5, max(0.0, -math.sin(p + 1.0)) * 70 + 5),
                         arms=(-30 * s, 30 * s), bob=-abs(math.cos(p)) * 1.2 + 0.6))
    jump = [build(legs=(30, -10), bends=(60, 40), arms=(-60, 70), bob=-1),
            build(legs=(10, -20), bends=(25, 30), arms=(-40, 40), bob=0)]
    mine = [build(arms=(-150, 150), bob=0.4),      # raise
            build(arms=(-75, 75), bob=0.8),         # strike
            build(arms=(-25, 25), bob=0.6)]         # follow through
    frames = idle + run + jump + mine
    rows = [sum((f[y] for f in frames), []) for y in range(FH)]
    write_png(SPR + 'prospector.png', FW * len(frames), FH, rows)
    print('wrote prospector.png (%d frames)' % len(frames))
    pk = pickaxe()
    write_png(SPR + 'pickaxe.png', 24, 16, pk)
    if len(sys.argv) > 1:
        big = side_by_side(frames, 7)
        write_png(sys.argv[1] + '/prospector_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/prospector_run.gif', run * 3, [7] * 24, 8)


if __name__ == '__main__':
    main()
