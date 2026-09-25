"""The Foundry Engine (boss): a walking blast furnace on four piston legs.
A riveted iron hearth with a glowing mouth, a boiler dome and chimney on
top, a slag ladle on a crane arm that flings molten slag, and a hatch at the
back that lets scuttlers out.

    python3 tools/art/gen_foundry.py [preview_dir]

Writes assets/sprites/foundry.png: 10 frames of 110x112, facing right, feet
at (55, 111): 0-5 walk (the legs step in diagonal pairs, the body rocks),
6-9 fling (the ladle arm swings back, over, releases, returns). The ladle
releases at about (+34, -94) from the feet on frame 8. The chimney top is
at (-3, -98); the hatch at (-31, -45).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 110, 112, (55, 111)
FIRE = [(90, 30, 12), (170, 60, 20), (230, 110, 40), (255, 180, 80), (255, 236, 170)]
EXTRA = ['5a1e0c', 'aa3c14', 'e66e28', 'ffb450', 'ffecaa']


def leg(fig, hip, lift, fwd, near, z):
    """A piston leg: a thick upper strut, a knee joint, a piston shin, a
    splayed foot. lift raises the foot, fwd moves it forward."""
    mat = STEEL if near else DARK
    foot = (hip[0] + fwd, -3 - lift)
    knee = ((hip[0] + foot[0]) / 2 + (6 if near else 4), (hip[1] + foot[1]) / 2 - 2)
    fig.capsule(hip, knee, 4.2, mat, z=z)
    fig.sphere(knee, 4.0, BRONZE if near else DARK, z=z + 0.1)
    fig.capsule(knee, foot, 3.0, mat, z=z + 0.05)
    fig.capsule((knee[0] - 1.5, knee[1] + 2), (foot[0] - 1.5, foot[1] - 5), 1.2, BRONZE if near else DARK, z=z + 0.15)
    fig.ellipsoid((foot[0], foot[1] + 1), (7, 2.6), BRONZE if near else DARK, z=z + 0.2)


def build(i):
    walk = i < 6
    ph = i / 6 * math.tau if walk else 0.0
    rock = math.sin(ph) * 1.2 if walk else 0.0
    bob = abs(math.cos(ph)) * 1.5 if walk else 0.0
    fig = Figure()
    # legs: diagonal pairs (front-near with back-far) alternate
    a = math.sin(ph)
    b = -a
    for (hx, near, s) in ((-24, False, b), (18, False, a)):
        leg(fig, (hx + 4, -34 + bob), max(0.0, s) * 7, s * 8, near, 0)
    # body: a wide riveted hearth with a tapering furnace stack on it
    cy = -52 + bob
    fig.box((-37, cy - 6, 31, cy + 18), STEEL, z=2, bevel=5.0, grit=0.06)
    fig.poly([(-32, cy - 5), (26, cy - 5), (14, cy - 34), (-20, cy - 34)], STEEL, z=1.9, shade=0.75)
    for (y, w0, w1) in ((cy - 7, -34, 28), (cy - 20, -26, 20), (cy - 33, -21, 15)):
        fig.box((w0, y - 2, w1, y + 2), BRONZE, z=2.1, bevel=1.0)
    fig.box((-39, cy + 14, 33, cy + 19), BRONZE, z=2.1, bevel=1.5)
    for x in range(-33, 30, 7):
        fig.sphere((x, cy + 16.5), 0.8, STEEL, z=2.2)
    for x in range(-30, 26, 7):
        fig.sphere((x, cy - 7), 0.7, STEEL, z=2.2)
    # plate seams on the hearth
    for x in (-18, 0):
        fig.capsule((x, cy - 3), (x, cy + 12), 0.4, DARK, z=2.15)
    # a steam pipe down the side of the stack into the hearth
    fig.capsule((-24, cy - 30), (-30, cy - 12), 1.6, BRONZE, z=2.3)
    fig.capsule((-30, cy - 12), (-30, cy - 4), 1.6, BRONZE, z=2.3)
    # the furnace mouth on the front, glowing, with a grate
    fig.box((10, cy - 2, 29, cy + 14), DARK, z=2.3, bevel=2.0)
    glow = 1.0 if i % 2 == 0 else 0.85
    fig.ellipsoid((19.5, cy + 6), (8 * glow, 7 * glow), FIRE, z=2.4, emissive=True)
    for x in (13, 17, 21, 25):
        fig.capsule((x, cy - 1), (x, cy + 13), 0.7, DARK, z=2.5)
    # back hatch with a wheel lock
    fig.box((-37, cy, -26, cy + 14), BRONZE, z=2.3, bevel=1.5)
    fig.gear((-31.5, cy + 7), 3.2, 8, i * 20, STEEL, z=2.4)
    # pressure gauge on the stack, chimney on top
    fig.disc((-4, cy - 20), 3.4, DARK, z=2.35)
    fig.disc((-4, cy - 20), 2.6, [(230, 226, 206)] * 3, z=2.4)
    fig.capsule((-4, cy - 20), (-4 + 2.2 * math.cos(ph + 1), cy - 20 + 2.2 * math.sin(ph + 1)), 0.4, DARK, z=2.45)
    fig.capsule((-3, cy - 34), (-3, cy - 44), 4.0, DARK, z=1.7)
    fig.ellipsoid((-3, cy - 44), (6, 2.2), BRONZE, z=1.75)
    # the crane arm and slag ladle, pivoting on the stack's shoulder
    if walk:
        arm = -150 + rock * 2
    else:
        arm = [-165, -110, -45, -130][i - 6]
    base = (14, cy - 22)
    a_r = math.radians(arm)
    tip = (base[0] + math.cos(a_r) * 28, base[1] + math.sin(a_r) * 28)
    fig.capsule(base, tip, 2.2, BRONZE, z=3)
    fig.sphere(base, 3.4, STEEL, z=3.1)
    fig.ellipsoid(tip, (6, 4), DARK, z=3.2)
    if i != 8:
        fig.ellipsoid((tip[0], tip[1] - 1.5), (4.2, 1.8), FIRE, z=3.3, emissive=True)
    # near legs in front
    for (hx, s) in ((-24, a), (18, b)):
        leg(fig, (hx, -30 + bob), max(0.0, s) * 7, s * 8, True, 4)
    return fig.render(FW, FH, O, extra=EXTRA)


def main():
    frames = [build(i) for i in range(10)]
    write_png(SPR + 'foundry.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote foundry.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 4)
        write_png(sys.argv[1] + '/foundry_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
