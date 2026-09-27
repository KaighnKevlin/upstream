"""Clockwork grenadier: a stocky bomber. A barrel chest with a bandolier of
brass bombs, a round riveted helmet with a slit visor, and a long throwing
arm on a clock-spring shoulder.

    python3 tools/art/gen_grenadier.py [preview_dir]

Writes assets/sprites/grenadier.png: 9 frames of 40x40, facing right, feet
at (17, 39): 0-5 walk (a bomb held low), 6 wind-up (arm back, bomb lit),
7 release (arm over the top, hand empty), 8 follow-through. The throwing
hand at release is about (+9, -30) from the feet.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side
from gen_soldier import leg

FW, FH, O = 40, 40, (17, 39)
BOMB = [(40, 38, 31), (60, 55, 50), (95, 88, 80), (140, 130, 115)]
SPARK = [(160, 60, 20), (230, 130, 40), (255, 210, 110), (255, 245, 200)]
VISOR = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]


def bomb(fig, c, z, lit=False):
    fig.sphere(c, 2.4, BOMB, z=z)
    fig.box((c[0] - 0.8, c[1] - 3.2, c[0] + 0.8, c[1] - 2.0), BRONZE, z=z + 0.05, bevel=0.2)
    if lit:
        fig.sphere((c[0] + 0.6, c[1] - 4.0), 0.9, SPARK, z=z + 0.1, emissive=True)


def build(i):
    walk = i < 6
    ph = i / 6 * math.tau if walk else 0.0
    s = math.sin(ph)
    bob = abs(math.cos(ph)) * 1.0 if walk else 0.0
    fig = Figure()
    hip = (0, -16 + bob)
    if walk:
        leg(fig, (hip[0] - 0.5, hip[1]), -22 * s, max(0.0, -math.sin(ph + 0.6)) * 35, False)
        leg(fig, hip, 22 * s, max(0.0, math.sin(ph + 0.6)) * 35, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1]), -16, 12, False)     # braced
        leg(fig, hip, 18, 20, True)
    lean = {6: -1.5, 7: 2.0, 8: 2.5}.get(i, 0.5)
    ch = (lean * 0.6, -23 + bob)
    # far arm
    fig.capsule((ch[0] - 1, ch[1] - 2), (ch[0] - 3, ch[1] + 5), 1.4, DARK, z=1)
    # barrel chest and bandolier
    fig.ellipsoid(ch, (6.0, 7.0), BRONZE, z=2, grit=0.07)
    for k in range(4):
        t = k / 3
        bomb(fig, (ch[0] - 4.5 + t * 8.5, ch[1] - 4.5 + t * 8.0), 2.3)
    fig.capsule((ch[0] - 5, ch[1] - 5.5), (ch[0] + 5, ch[1] + 4.5), 0.7, DARK, z=2.2)   # the strap
    # helmet head
    hd = (ch[0] + 1.0 + lean * 0.3, ch[1] - 10.5)
    fig.sphere(hd, 4.2, STEEL, z=3, grit=0.05)
    fig.ellipsoid((hd[0], hd[1] + 1.5), (5.2, 1.4), STEEL, z=3.05)                     # brim
    fig.box((hd[0] + 0.5, hd[1] - 0.6, hd[0] + 4.2, hd[1] + 0.6), VISOR, z=3.1, bevel=0.2)
    for a in (200, 250, 300):
        r = math.radians(a)
        fig.sphere((hd[0] + math.cos(r) * 3.2, hd[1] + math.sin(r) * 3.2), 0.45, BRONZE, z=3.12)
    # throwing arm on a spring shoulder
    sh = (ch[0] + 1.5, ch[1] - 3.5)
    fig.disc(sh, 2.0, BRONZE, z=4)
    fig.gear(sh, 1.6, 6, i * 30, STEEL, z=4.1)
    if walk:
        hand = (sh[0] + 3.0, sh[1] + 7.5 + s * 0.8)
        bomb(fig, (hand[0] + 1.5, hand[1] + 1.5), 4.4)
    elif i == 6:
        hand = (sh[0] - 7.5, sh[1] + 1.0)
        bomb(fig, (hand[0] - 1.5, hand[1] - 0.5), 4.4, lit=True)
    elif i == 7:
        hand = (sh[0] + 6.0, sh[1] - 6.5)
    else:
        hand = (sh[0] + 8.0, sh[1] + 3.5)
    elbow = ((sh[0] + hand[0]) / 2 - 1.0, (sh[1] + hand[1]) / 2 + 1.5)
    fig.capsule(sh, elbow, 1.4, STEEL, z=4.2)
    fig.capsule(elbow, hand, 1.2, STEEL, z=4.25)
    fig.sphere(hand, 1.5, BRONZE, z=4.3)
    return fig.render(FW, FH, O, extra=['28261f', '3c3732', '5f5850', '8c8273', 'a03c14', 'e68228', 'ffd26e', 'fff5c8', '460e0c', 'a01e18', 'e64632', 'ffa082'])


def main():
    frames = [build(i) for i in range(9)]
    write_png(SPR + 'grenadier.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote grenadier.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/grenadier_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
