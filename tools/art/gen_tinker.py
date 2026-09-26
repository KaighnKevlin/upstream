"""Clockwork tinker: a squat round repair automaton with a toolbox on its
back, one big goggle lens, and a welding-torch arm with a blue flame.

    python3 tools/art/gen_tinker.py [preview_dir]

Writes assets/sprites/tinker.png: 8 frames of 36x34, facing right, feet at
(16, 33): 0-5 walk, 6-7 weld (torch raised, flame flaring). The torch tip is
at about (+13, -16) from the feet when welding.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side
from gen_soldier import leg

FW, FH, O = 36, 34, (16, 33)
FLAME = [(40, 70, 140), (80, 150, 230), (160, 220, 255), (230, 250, 255)]


def build(i):
    walk = i < 6
    ph = i / 6 * math.tau if walk else 0.0
    s = math.sin(ph)
    bob = abs(math.cos(ph)) * 0.8 if walk else 0.0
    fig = Figure()
    hip = (0, -10 + bob)
    if walk:
        leg(fig, (hip[0] - 0.5, hip[1]), -22 * s, max(0.0, -math.sin(ph + 0.6)) * 35, False)
        leg(fig, hip, 22 * s, max(0.0, math.sin(ph + 0.6)) * 35, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1]), -12, 10, False)
        leg(fig, hip, 14, 18, True)
    cx, cy = 0.0, -17 + bob
    # toolbox on the back, a wrench handle sticking out
    fig.box((cx - 11, cy - 6, cx - 4, cy + 3), [(80, 20, 18), (150, 40, 32), (190, 64, 44), (210, 100, 70)], z=1, bevel=0.8)
    fig.capsule((cx - 10, cy - 7), (cx - 13, cy - 11), 0.7, STEEL, z=0.9)
    fig.box((cx - 11.5, cy - 2, cx - 3.5, cy - 1), BRONZE, z=1.1, bevel=0.3)
    # round body
    fig.sphere((cx, cy), 6.5, BRONZE, z=2, grit=0.05)
    fig.ellipsoid((cx + 1, cy + 3.5), (5.5, 2), STEEL, z=2.1)
    for a in (210, 260, 310):
        r = math.radians(a)
        fig.sphere((cx + math.cos(r) * 5, cy + math.sin(r) * 5), 0.5, STEEL, z=2.2)
    # the goggle lens
    fig.disc((cx + 3, cy - 2), 2.8, DARK, z=2.3)
    fig.disc((cx + 3, cy - 2), 2.0, GLOW, z=2.4)
    fig.sphere((cx + 2.3, cy - 2.7), 0.5, [(240, 250, 250)] * 2, z=2.5, emissive=True)
    # torch arm
    sh = (cx + 2, cy + 1)
    if walk:
        tip = (cx + 9, cy + 4 + s)
    else:
        tip = (cx + 11, cy - 1 - (i - 6) * 1.5)
    fig.capsule(sh, tip, 1.2, STEEL, z=3)
    fig.capsule(tip, (tip[0] + 2.5, tip[1] - 0.8), 0.8, BRONZE, z=3.1)
    tt = (tip[0] + 3.2, tip[1] - 1.0)
    if walk:
        fig.sphere(tt, 0.8, FLAME, z=3.2, emissive=True)   # pilot flame
    else:
        big = 1.6 if i == 6 else 2.3
        fig.ellipsoid((tt[0] + big * 0.8, tt[1]), (big * 1.3, big * 0.7), FLAME, z=3.2, emissive=True)
    return fig.render(FW, FH, O, extra=['501410', '962820', 'be402c', 'd26446', '284690', '5096e6', 'a0dcff', 'e6faff'])


def main():
    frames = [build(i) for i in range(8)]
    write_png(SPR + 'tinker.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote tinker.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/tinker_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
