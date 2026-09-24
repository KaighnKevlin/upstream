"""Clockwork soldier: shield-and-spear infantry automaton (replaces the skeleton).

    python3 tools/art/gen_soldier.py [preview_dir]

Writes assets/sprites/soldier_walk.png (8 frames) and soldier_attack.png
(6 frames: draw back, lunge, hold, recover), 60x50, facing right; body 13px
left of the frame centre.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH = 60, 50
ORIGIN = (17, 48)
THIGH, SHIN = 7.5, 7.5


def leg(fig, hip, swing, bend, near):
    t = math.radians(swing)
    knee = (hip[0] + THIGH * math.sin(t), hip[1] + THIGH * math.cos(t))
    s = t - math.radians(bend)
    foot = (knee[0] + SHIN * math.sin(s), knee[1] + SHIN * math.cos(s))
    mat, z = (STEEL, 8) if near else (DARK, 1)
    fig.capsule(hip, knee, 1.7, mat, z=z)
    fig.capsule(knee, foot, 1.5, mat, z=z + 0.1)
    fig.sphere(knee, 1.7, BRONZE if near else DARK, z=z + 0.2)
    fig.ellipsoid((foot[0] + 1.2, foot[1] - 0.2), (2.9, 1.3), BRONZE if near else DARK, z=z + 0.3)  # boot
    return foot


def build(i, n=8, lunge=0.0, spear_back=0.0, lean=0.0, walk=True):
    ph = i / n * 2 * math.pi
    s = math.sin(ph) if walk else 0.0
    bob = (abs(math.cos(ph)) * 1.2) if walk else 0.0
    ox = lunge
    hip = (ox - 0.5, -17 + bob)
    fig = Figure()
    # legs: far leg opposite phase; knee bends on the forward swing
    leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -26 * s, max(0.0, -math.sin(ph + 0.6)) * 45 if walk else 10, False)
    leg(fig, hip, 26 * s, max(0.0, math.sin(ph + 0.6)) * 45 if walk else 18, True)
    cx, cy = ox + lean, -25 + bob
    # backpack boiler + wind-up key
    fig.ellipsoid((cx - 6.5, cy - 1), (3.2, 5.8), STEEL, z=2)
    ka = i / n * 2 * math.pi
    kw = 0.5 + 2.4 * abs(math.cos(ka))
    fig.capsule((cx - 7, cy - 6), (cx - 8, cy - 9), 0.6, STEEL, z=2.1)
    fig.ellipsoid((cx - 8.3, cy - 10.5), (kw, 2.0), BRONZE, z=2.2 if math.cos(ka) > 0 else 6.5, grit=0.03)
    # far arm + spear (held level, pointing forward)
    sh_far = (cx + 0.5, cy - 4)
    hand = (cx + 6 + spear_back * -1 + lunge * 0.3, cy + 1)
    fig.capsule(sh_far, hand, 1.4, DARK, z=3)
    sx0 = hand[0] - 8 - spear_back * 0.2; sx1 = hand[0] + 13
    fig.capsule((sx0, cy + 1.5), (sx1, cy - 0.5), 0.6, BRONZE, z=3.1, grit=0.02)   # shaft
    fig.ellipsoid((sx1 + 2.2, cy - 0.7), (3.0, 1.2), STEEL, z=3.2, grit=0.02, tilt=-4)  # spearhead
    # body
    fig.ellipsoid((cx, cy), (6, 7.5), BRONZE, z=5)                         # barrel torso
    fig.ellipsoid((cx, cy + 6.3), (6.2, 1.6), DARK, z=5.2)                 # belt
    for a in (200, 250, 290, 340):                                         # rivets
        r = math.radians(a)
        fig.sphere((cx + math.cos(r) * 4.6, cy + math.sin(r) * 5.8), 0.55, STEEL, z=5.3)
    fig.disc((cx + 2.6, cy - 1), 2.4, DARK, z=5.4)
    fig.sphere((cx + 2.9, cy - 1), 1.6, GLOW, z=5.5, emissive=True)          # chest core
    # head: domed helmet, crest, glowing visor slit
    hx, hy = cx + 1.2, cy - 11.5
    fig.ellipsoid((hx, hy), (4.4, 4.2), BRONZE, z=6)
    fig.ellipsoid((hx - 0.8, hy - 4.2), (3.2, 1.2), BRONZE, z=5.9, grit=0.1)  # crest
    fig.capsule((hx + 0.8, hy + 0.3), (hx + 4.2, hy + 0.3), 0.75, DARK, z=6.1)
    fig.capsule_glow((hx + 1.4, hy + 0.3), (hx + 4.0, hy + 0.3), 0.55, z=6.2)
    fig.sphere((cx, cy - 7.8), 1.6, STEEL, z=5.8)                           # neck
    # near arm with the round shield on the forearm
    sh = (cx - 1, cy - 4)
    elbow = (cx + 1.5 + lunge * 0.2, cy + 1.5)
    fig.capsule(sh, elbow, 1.5, STEEL, z=7)
    fig.sphere(sh, 2.2, BRONZE, z=7.1)                                       # pauldron
    shield = (cx + 5 + lunge * 0.25, cy + 1)
    fig.disc(shield, 5.6, BRONZE, z=9)
    fig.gear(shield, 3.0, 8, 0, STEEL, z=9.1)
    fig.sphere(shield, 0.9, BRONZE, z=9.2)
    return fig.render(FW, FH, ORIGIN)


def main():
    walk = [build(i) for i in range(8)]
    attack = [
        build(0, lunge=0, spear_back=0, walk=False),
        build(1, lunge=-2, spear_back=5, lean=-1.5, walk=False),   # draw back
        build(2, lunge=6, spear_back=-5, lean=1.5, walk=False),    # lunge (impact)
        build(3, lunge=7, spear_back=-6, lean=2, walk=False),
        build(4, lunge=4, spear_back=-4, lean=1, walk=False),
        build(5, lunge=1, spear_back=0, walk=False),
    ]
    for name, frames in (('soldier_walk', walk), ('soldier_attack', attack)):
        rows = [sum((f[y] for f in frames), []) for y in range(FH)]
        write_png(SPR + name + '.png', FW * len(frames), FH, rows)
    print('wrote soldier_walk.png, soldier_attack.png')
    if len(sys.argv) > 1:
        big = side_by_side(walk + attack, 6)
        write_png(sys.argv[1] + '/soldier_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/soldier.gif', walk * 2 + attack + [attack[0]] * 3, [10] * 16 + [8, 10, 6, 14, 10, 8, 20, 20, 20], 7)


if __name__ == '__main__':
    main()
