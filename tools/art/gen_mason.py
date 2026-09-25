"""Clockwork mason: a squat bricklayer automaton with a hod of bricks on its
back and a trowel arm. At a ditch it lobs bricks in and fills it level.

    python3 tools/art/gen_mason.py [preview_dir]

Writes assets/sprites/mason.png: 10 frames of 48x44, facing right, feet at
(20, 42): 0-5 walk, 6-9 lob (reach back into the hod, swing, release,
recover). The brick leaves the hand at about (+10, -24) on frame 8.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side
from gen_soldier import leg

FW, FH, O = 48, 44, (20, 42)
BRICK = [(41, 38, 31), (90, 42, 30), (140, 66, 44), (176, 96, 64), (206, 132, 92)]
EXTRA = ['5a2a1e', '8c422c', 'b06040', 'ce845c']


def build(i):
    walk = i < 6
    ph = i / 6 * math.tau if walk else 0.0
    s = math.sin(ph)
    bob = abs(math.cos(ph)) * 1.0 if walk else 0.0
    arm = [None, None, None, None, None, None, -140, -60, 20, -20][i]   # throwing arm angle
    fig = Figure()
    hip = (0, -15 + bob)
    if walk:
        leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -24 * s, max(0.0, -math.sin(ph + 0.6)) * 40, False)
        leg(fig, hip, 24 * s, max(0.0, math.sin(ph + 0.6)) * 40, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -14, 8, False)
        leg(fig, hip, 16, 20, True)
    cx, cy = 0.5, -22 + bob
    # the hod: a brass frame on its back stacked with bricks
    fig.box((cx - 13, cy - 13, cx - 5, cy + 3), DARK, z=1, bevel=0.8)
    for k in range(4):
        fig.box((cx - 12.5, cy - 12 + k * 3.6, cx - 5.5, cy - 9.4 + k * 3.6), BRICK, z=1.2 + k * 0.01, bevel=0.4, grit=0.1)
    fig.capsule((cx - 13.5, cy - 14), (cx - 13.5, cy + 4), 0.7, BRONZE, z=1.3)
    fig.capsule((cx - 4.5, cy - 14), (cx - 4.5, cy + 4), 0.7, BRONZE, z=1.3)
    # far arm with the trowel
    fig.capsule((cx + 1, cy - 3), (cx + 7, cy + 3), 1.4, DARK, z=2)
    fig.poly([(cx + 7, cy + 2), (cx + 12, cy + 4.5), (cx + 7.5, cy + 5)], STEEL, z=2.1, shade=0.7)
    # stout body, apron plate, chest furnace
    fig.ellipsoid((cx, cy), (7, 7.5), BRONZE, z=3, grit=0.08)
    fig.ellipsoid((cx + 1, cy + 4), (6, 3.2), STEEL, z=3.1)
    fig.disc((cx + 3, cy - 1.5), 2.2, DARK, z=3.2)
    fig.sphere((cx + 3.2, cy - 1.5), 1.4, [(120, 40, 20), (220, 110, 40), (255, 190, 90)], z=3.3, emissive=True)
    # head: a flat-capped block with a single lens
    hx, hy = cx + 1.5, cy - 10.5
    fig.box((hx - 4, hy - 3.5, hx + 4, hy + 3), STEEL, z=4, bevel=1.5)
    fig.box((hx - 5, hy - 5, hx + 5, hy - 3.5), BRONZE, z=4.1, bevel=0.5)
    fig.sphere((hx + 2.4, hy - 0.5), 1.3, GLOW, z=4.2, emissive=True)
    # near arm: swings with the walk, or throws
    sh = (cx - 0.5, cy - 4)
    if arm is None:
        a = math.radians(90 - 25 * s)
        hand = (sh[0] + math.cos(a) * 8, sh[1] + math.sin(a) * 8)
    else:
        a = math.radians(arm)
        hand = (sh[0] + math.cos(a) * 8.5, sh[1] + math.sin(a) * 8.5)
    fig.capsule(sh, hand, 1.6, STEEL, z=5)
    fig.sphere(sh, 2.3, BRONZE, z=5.1)
    fig.sphere(hand, 1.5, BRONZE, z=5.2)
    if i in (6, 7):   # a brick in hand
        fig.box((hand[0] - 2.5, hand[1] - 1.5, hand[0] + 2.5, hand[1] + 1.5), BRICK, z=5.3, bevel=0.4)
    return fig.render(FW, FH, O, extra=EXTRA)


def brick():
    fig = Figure()
    fig.box((-3, -2, 3, 2), BRICK, z=0, bevel=0.5, grit=0.1)
    return fig.render(8, 6, (4, 3), extra=EXTRA)


def main():
    frames = [build(i) for i in range(10)]
    write_png(SPR + 'mason.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    write_png(SPR + 'brick.png', 8, 6, brick())
    print('wrote mason.png, brick.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/mason_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
