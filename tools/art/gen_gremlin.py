"""Clockwork gremlin: a wiry little saboteur. Hunched bronze body with a
wind-up key in its back, a round head with two big green lamp eyes and
pointed fin ears, spindly steel legs, and a spanner as big as it is.

    python3 tools/art/gen_gremlin.py [preview_dir]

Writes assets/sprites/gremlin.png: 8 frames of 30x28, facing right, feet at
(13, 27): 0-5 run (spanner carried over the shoulder), 6-7 wrenching (the
spanner swung down in front, at about (+11, -6) from the feet).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 30, 28, (13, 27)
EYE = [(20, 70, 30), (60, 160, 60), (140, 230, 110), (220, 255, 190)]


def leg(fig, hip, swing, bend, near):
    t = math.radians(swing)
    knee = (hip[0] + 4.2 * math.sin(t), hip[1] + 4.2 * math.cos(t))
    s = t - math.radians(bend)
    foot = (knee[0] + 4.4 * math.sin(s), knee[1] + 4.4 * math.cos(s))
    mat, z = (STEEL, 6) if near else (DARK, 1)
    fig.capsule(hip, knee, 0.8, mat, z=z)
    fig.capsule(knee, foot, 0.7, mat, z=z + 0.1)
    fig.ellipsoid((foot[0] + 1.0, foot[1] - 0.2), (1.9, 0.9), BRONZE if near else DARK, z=z + 0.2)


def spanner(fig, a, b, z):
    fig.capsule(a, b, 1.0, STEEL, z=z)
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    px, py = -uy, ux
    for side in (-1, 1):   # open jaw: two prongs
        c = (b[0] + px * side * 1.6, b[1] + py * side * 1.6)
        fig.capsule(c, (c[0] + ux * 2.4, c[1] + uy * 2.4), 0.9, STEEL, z=z + 0.1)


def build(i):
    run = i < 6
    ph = i / 6 * math.tau if run else 0.0
    s = math.sin(ph)
    bob = abs(math.cos(ph)) * 0.9 if run else 0.0
    fig = Figure()
    hip = (0, -9 + bob)
    if run:
        leg(fig, (hip[0] - 0.5, hip[1]), -30 * s, max(0.0, -math.sin(ph + 0.6)) * 50, False)
        leg(fig, hip, 30 * s, max(0.0, math.sin(ph + 0.6)) * 50, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1]), -18, 30, False)
        leg(fig, hip, 22, 40, True)
    lean = 2.5 if run else 1.5
    body = (lean * 0.5, -13 + bob)
    # wind-up key in the back
    k = (body[0] - 5.5, body[1] - 1.5)
    fig.capsule(body, k, 0.6, BRONZE, z=1.5)
    turn = 1.0 + 0.8 * math.cos(ph * 2)
    fig.ellipsoid((k[0] - 0.8, k[1] - 1.4 * turn), (1.0, 1.5 * turn), BRONZE, z=1.6)
    fig.ellipsoid((k[0] - 0.8, k[1] + 1.4 * turn), (1.0, 1.5 * turn), BRONZE, z=1.6)
    # hunched body
    fig.ellipsoid(body, (4.5, 4.0), BRONZE, z=2, grit=0.08, tilt=-0.3)
    fig.gear((body[0] - 0.5, body[1] + 0.5), 1.8, 6, i * 25, STEEL, z=2.2)
    # head: forward and low
    hd = (body[0] + 4.5, body[1] - 4.2)
    fig.poly([(hd[0] - 3, hd[1] - 1.5), (hd[0] - 6.5, hd[1] - 5.5 - bob * 0.5), (hd[0] - 1.5, hd[1] - 3.0)], BRONZE, z=2.4)  # far fin ear
    fig.sphere(hd, 3.6, BRONZE, z=2.5, grit=0.05)
    fig.poly([(hd[0] - 1.2, hd[1] - 2.5), (hd[0] - 4.0, hd[1] - 7.5 - bob * 0.5), (hd[0] + 0.8, hd[1] - 3.2)], BRONZE, z=2.7)  # near fin ear
    fig.sphere((hd[0] + 1.6, hd[1] - 0.6), 1.35, EYE, z=3, emissive=True)
    fig.sphere((hd[0] + 3.0, hd[1] + 0.2), 1.05, EYE, z=3.05, emissive=True)
    fig.capsule((hd[0] + 0.5, hd[1] + 2.0), (hd[0] + 3.0, hd[1] + 2.3), 0.5, DARK, z=3.1)   # grille grin
    # arm and spanner
    sh = (body[0] + 1.5, body[1] - 0.5)
    if run:
        hand = (sh[0] + 2.0, sh[1] - 2.5 + s * 0.5)
        spanner(fig, (hand[0] + 3.0, hand[1] + 3.0), (hand[0] - 6.5, hand[1] - 7.0), 4)
    else:
        a = math.radians(-60 if i == 6 else 40)
        hand = (sh[0] + 4.0 * math.cos(a), sh[1] + 4.0 * math.sin(a))
        spanner(fig, hand, (hand[0] + 8.5 * math.cos(a), hand[1] + 8.5 * math.sin(a)), 4)
    fig.capsule(sh, hand, 0.8, STEEL, z=4.1)
    fig.sphere(hand, 1.1, BRONZE, z=4.2)
    return fig.render(FW, FH, O, extra=['14461e', '3ca03c', '8ce66e', 'dcffbe'])


def main():
    frames = [build(i) for i in range(8)]
    write_png(SPR + 'gremlin.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote gremlin.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/gremlin_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
