"""Brass sentry: the prospector's own clockwork guard. A stout knight in
polished brass with a round steel shield, a hammer, a crest of copper
fins, and a cyan lamp for a visor (the enemies' lamps are red).

    python3 tools/art/gen_sentry.py [preview_dir]

Writes assets/sprites/sentry.png: 10 frames of 40x40, facing right, feet
at (17, 39): 0-5 walk, 6 wind-up (hammer back), 7 strike (hammer down in
front), 8 recover, 9 wound down (slumped, lamp dark).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side
from gen_soldier import leg

FW, FH, O = 40, 40, (17, 39)
LAMP = [(30, 90, 110), (60, 170, 200), (130, 225, 240), (220, 250, 255)]
FIN = COPPER


def build(i):
    walk = i < 6
    down = i == 9
    ph = i / 6 * math.tau if walk else 0.0
    s = math.sin(ph)
    bob = abs(math.cos(ph)) * 1.0 if walk else 0.0
    sag = 3.0 if down else 0.0
    fig = Figure()
    hip = (0, -16 + bob + sag * 0.6)
    if walk:
        leg(fig, (hip[0] - 0.5, hip[1]), -20 * s, max(0.0, -math.sin(ph + 0.6)) * 32, False)
        leg(fig, hip, 20 * s, max(0.0, math.sin(ph + 0.6)) * 32, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1]), -14, 18 + sag * 6, False)
        leg(fig, hip, 16, 22 + sag * 6, True)
    lean = {6: -1.5, 7: 2.5, 8: 1.0, 9: 1.5}.get(i, 0.3)
    ch = (lean * 0.5, -24 + bob + sag)
    # round shield on the far arm, held in front
    fig.disc((ch[0] + 6.5, ch[1] + 2.0), 5.6, STEEL, z=1.5)
    fig.disc((ch[0] + 6.5, ch[1] + 2.0), 4.2, DARK, z=1.55)
    fig.disc((ch[0] + 6.5, ch[1] + 2.0), 3.4, STEEL, z=1.6)
    fig.sphere((ch[0] + 6.5, ch[1] + 2.0), 1.3, BRONZE, z=1.65)
    # body: polished brass cuirass
    fig.ellipsoid(ch, (5.5, 6.8), BRONZE, z=2, grit=0.04)
    fig.capsule((ch[0] - 4.5, ch[1] + 2.5), (ch[0] + 4.5, ch[1] + 2.5), 0.7, STEEL, z=2.1)
    fig.gear((ch[0] - 1.0, ch[1] - 1.5), 1.8, 8, i * 25, STEEL, z=2.15)
    # helm with copper fin crest and a cyan visor lamp
    hd = (ch[0] + 1.0 + lean * 0.3, ch[1] - 10.0 + sag * 0.5)
    for k in range(3):
        fig.poly([(hd[0] - 3 + k * 1.8, hd[1] - 2.5), (hd[0] - 4.5 + k * 1.8, hd[1] - 7.5 + k * 0.6), (hd[0] - 1.8 + k * 1.8, hd[1] - 3.0)], FIN, z=2.9)
    fig.sphere(hd, 4.0, BRONZE, z=3, grit=0.04)
    fig.box((hd[0] + 0.3, hd[1] - 0.8, hd[0] + 4.2, hd[1] + 0.8), DARK if down else LAMP, z=3.1, bevel=0.2)
    # hammer arm (near side)
    sh = (ch[0] - 1.5, ch[1] - 3.0)
    fig.disc(sh, 1.9, STEEL, z=4)
    if walk:
        hand = (sh[0] - 1.0, sh[1] + 8.0 + s * 0.6)
        head_at, ang = (hand[0] - 1.0, hand[1] - 8.0), -90
    elif i == 6:
        hand = (sh[0] - 5.5, sh[1] - 4.5)
        head_at, ang = (hand[0] - 5.0, hand[1] - 5.5), 135
    elif i == 7:
        hand = (sh[0] + 8.0, sh[1] + 2.0)
        head_at, ang = (hand[0] + 8.0, hand[1] + 1.5), 10
    elif i == 8:
        hand = (sh[0] + 5.5, sh[1] + 6.0)
        head_at, ang = (hand[0] + 5.0, hand[1] + 5.5), 45
    else:
        hand = (sh[0] + 1.0, sh[1] + 9.0)
        head_at, ang = (hand[0] + 3.0, hand[1] + 6.0), 70
    fig.capsule(sh, hand, 1.3, STEEL, z=4.1)
    fig.capsule(hand, head_at, 0.8, DARK, z=4.2)                     # haft
    a = math.radians(ang)
    px, py = -math.sin(a), math.cos(a)
    fig.box((head_at[0] - 2.4, head_at[1] - 2.4, head_at[0] + 2.4, head_at[1] + 2.4), STEEL, z=4.3, bevel=0.6)
    fig.sphere(hand, 1.4, BRONZE, z=4.4)
    return fig.render(FW, FH, O, extra=['1e5a6e', '3caac8', '82e1f0', 'dcfaff'])


def main():
    frames = [build(i) for i in range(10)]
    write_png(SPR + 'sentry.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote sentry.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/sentry_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
