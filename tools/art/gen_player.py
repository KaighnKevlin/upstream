"""The player: a prospector in a brass dome helmet with a headlamp.

    python3 tools/art/gen_player.py [preview_dir]

Writes assets/sprites/prospector.png: one strip of 32x40 frames, facing right,
feet at (16, 38) so the frame centre is the body centre:
  frames 0-3 idle, 4-11 run, 12-13 jump, 14-16 pickaxe swing (raise, strike,
  follow-through).
Frame 17 is "hurt" (knocked back, arms flung); 18 rise, 19-20 fall, 21 land. prospector_death.png: 6 frames
of 64x40 (wider so the fall fits; feet at (32, 38), so it lines up with the
32x40 frames when both are centred): reel, topple back, land, bounce, lie
with the headlamp flickering out.
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


SCARF = [_hex(h) for h in ('29261f', '5a1a16', '8c2a20', 'b8402c', 'd86448')]
SCARF_EXTRA = ['5a1a16', '8c2a20', 'b8402c', 'd86448']


def build(legs=(0, 0), bends=(8, 8), arms=(0, 0), bob=0.0, lamp=1.0,
          rot=0.0, shift=(0, 0), size=(FW, FH, ORIGIN), eye=True):
    fig = Figure()
    if rot or shift != (0, 0):
        fig.transform(rot, (0, -1), shift)
    hip = (0, -12 + bob)
    near_leg, far_leg = legs
    swing = (near_leg - far_leg) / 70.0          # coat-tails and scarf follow the stride
    # far leg with its boot (darker, behind)
    _, fe = limb(fig, (hip[0] - 0.5, hip[1]), far_leg, bends[1], THIGH, SHIN, BEARD, 1.6, 1.45, 1)
    fig.ellipsoid((fe[0] + 1.1, fe[1] - 0.4), (2.6, 1.5), CLOTH, z=1.3)
    sh = (0.5, -20.5 + bob)
    limb(fig, (sh[0] - 1, sh[1]), -arms[0], -20, 4.2, 4.0, CLOTH, 1.4, 1.2, 2)
    # scarf tail streaming back from the neck
    fig.poly([(-1.5, -23.2 + bob), (-7.5, -22.5 + bob - swing * 1.5), (-8.5, -20.8 + bob - swing), (-1.5, -21.5 + bob)], SCARF, z=2.6, shade=0.7)
    # backpack boiler: tank, chimney, gauge, a copper pipe to the shoulder
    fig.box((-7.2, -25.5 + bob, -3.0, -14.5 + bob), BRONZE, z=3, bevel=1.6, grit=0.05)
    fig.capsule((-6.2, -25.5 + bob), (-6.2, -28.5 + bob), 0.8, DARK, z=2.9)
    fig.ellipsoid((-6.2, -28.8 + bob), (1.3, 0.6), BRONZE, z=2.95)
    fig.disc((-5.1, -20.0 + bob), 1.4, DARK, z=3.2)
    fig.sphere((-5.1, -20.0 + bob), 0.9, GLOW, z=3.3, emissive=True)
    fig.capsule((-3.4, -16.0 + bob), (-1.5, -19.0 + bob), 0.55, COPPER, z=3.4)
    # duster: long coat with tails that swing out behind
    fig.poly([(-3.8, -17 + bob), (2.8, -17 + bob), (2.4, -11.5 + bob), (-5.2 - swing * 1.5, -10.8 + bob)], COAT, z=3.8, shade=0.6)
    fig.ellipsoid((0, -17.8 + bob), (4.2, 6.0), COAT, z=4, grit=0.04)
    for y in (-20.5, -17.5, -14.5):
        fig.sphere((2.6, y + bob), 0.45, BRONZE, z=4.2)                        # buttons
    fig.capsule((-3.0, -22.5 + bob), (3.2, -13.8 + bob), 0.65, LEATHER, z=4.25)  # bandolier
    fig.box((-4.0, -13.8 + bob, 4.0, -12.2 + bob), DARK, z=4.3, bevel=0.5)   # belt
    fig.box((0.8, -14.0 + bob, 2.6, -12.0 + bob), BRONZE, z=4.4, bevel=0.5)  # buckle
    fig.box((-3.6, -13.0 + bob, -1.4, -10.8 + bob), LEATHER, z=4.35, bevel=0.5)  # pouch
    # near leg and its boot, brass toe cap
    _, ne = limb(fig, hip, near_leg, bends[0], THIGH, SHIN, LEATHER, 1.7, 1.55, 5)
    fig.ellipsoid((ne[0] + 1.1, ne[1] - 0.4), (2.7, 1.6), CLOTH, z=5.3)
    fig.sphere((ne[0] + 3.0, ne[1] - 0.2), 0.8, BRONZE, z=5.4)
    # head: face, eye, beard, the red scarf at the throat
    hx, hy = 1.4, -26.3 + bob
    fig.ellipsoid((hx, hy), (3.1, 3.3), SKIN, z=6, grit=0.03)
    if eye:
        fig.sphere((hx + 1.7, hy - 0.2), 0.5, DARK, z=6.15)
    else:
        fig.capsule((hx + 1.1, hy - 0.1), (hx + 2.3, hy - 0.1), 0.3, DARK, z=6.15)
    fig.ellipsoid((hx + 0.8, hy + 2.3), (2.1, 1.1), BEARD, z=6.1, grit=0.1)
    fig.sphere((hx + 2.8, hy + 0.5), 0.75, SKIN, z=6.2)
    fig.ellipsoid((hx - 0.8, hy + 3.9), (2.8, 0.9), SCARF, z=5.9)               # scarf at the collar
    # brass dome helmet: a riveted band, goggles pushed up, a big headlamp
    fig.ellipsoid((hx - 0.4, hy - 3.2), (4.4, 3.2), BRONZE, z=6.5, grit=0.03)
    fig.capsule((hx - 4.6, hy - 1.6), (hx + 4.0, hy - 1.6), 0.75, STEEL, z=6.6)  # band
    fig.sphere((hx - 2.6, hy - 1.6), 0.45, BRONZE, z=6.65)
    fig.ellipsoid((hx + 0.6, hy - 1.0), (5.2, 0.8), BRONZE, z=6.55, grit=0.03)   # brim
    for gx in (-1.2, 1.2):
        fig.disc((hx + gx, hy - 4.3), 1.1, DARK, z=6.7)
        fig.disc((hx + gx, hy - 4.3), 0.7, GLOW, z=6.75)                      # goggle lenses
    fig.box((hx + 2.6, hy - 4.6, hx + 4.2, hy - 2.0), STEEL, z=6.8, bevel=0.4)  # lamp housing
    if lamp > 0.5:
        fig.sphere((hx + 4.3, hy - 3.3), 1.5, LAMP, z=6.9, emissive=True)
    else:
        fig.sphere((hx + 4.3, hy - 3.3), 1.5, BRONZE, z=6.9)
    # near arm (swings) in a leather glove
    _, hand = limb(fig, sh, arms[1], -24, 4.2, 4.0, COAT, 1.5, 1.3, 7)
    fig.sphere(hand, 1.3, LEATHER, z=7.2)
    w, h, o = size
    return fig.render(w, h, o, extra=SKIN_EXTRA + LAMP_EXTRA + SCARF_EXTRA + COPPER_EXTRA)


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
    hurt = [build(legs=(-18, 20), bends=(30, 20), arms=(60, -80), bob=0.5, rot=-10, eye=False)]
    # 18 rise (knees tucked, near arm reaching up), 19-20 fall (legs dangling,
    # arms out, flapping), 21 land (crouch that absorbs the drop)
    air = [build(legs=(40, 10), bends=(90, 70), arms=(-30, 130), bob=-1.5),
           build(legs=(-8, 16), bends=(18, 30), arms=(-100, 95), bob=0),
           build(legs=(-2, 10), bends=(26, 22), arms=(-125, 120), bob=0.3),
           build(legs=(28, -22), bends=(80, 80), arms=(-35, 45), bob=3.2)]
    frames = idle + run + jump + mine + hurt + air
    D = (64, 40, (32, 38))
    death = [build(legs=(-18, 20), bends=(30, 20), arms=(60, -80), rot=-18, size=D, eye=False),
             build(legs=(10, 30), bends=(50, 40), arms=(90, -100), rot=-48, shift=(-2, -3), size=D, eye=False),
             build(legs=(30, 40), bends=(40, 30), arms=(120, -120), rot=-88, shift=(-3, -6), size=D, eye=False),
             build(legs=(40, 50), bends=(30, 20), arms=(130, -110), rot=-80, shift=(-3, -8), size=D, eye=False, lamp=0.0),
             build(legs=(35, 45), bends=(30, 25), arms=(125, -115), rot=-90, shift=(-3, -6), size=D, eye=False),
             build(legs=(35, 45), bends=(30, 25), arms=(125, -115), rot=-90, shift=(-3, -6), size=D, eye=False, lamp=0.0)]
    rows = [sum((f[y] for f in death), []) for y in range(40)]
    write_png(SPR + 'prospector_death.png', 64 * len(death), 40, rows)
    rows = [sum((f[y] for f in frames), []) for y in range(FH)]
    write_png(SPR + 'prospector.png', FW * len(frames), FH, rows)
    print('wrote prospector.png (%d frames)' % len(frames))
    pk = pickaxe()
    write_png(SPR + 'pickaxe.png', 24, 16, pk)
    if len(sys.argv) > 1:
        big = side_by_side(death, 7)
        write_png(sys.argv[1] + '/prospector_death_preview.png', len(big[0]), len(big), big)
        big = side_by_side(frames, 7)
        write_png(sys.argv[1] + '/prospector_preview.png', len(big[0]), len(big), big)
        pass


if __name__ == '__main__':
    main()
