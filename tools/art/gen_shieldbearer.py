"""Clockwork shieldbearer: a squat steel automaton behind a tall riveted
tower shield. Ore thrown at its front glances off the shield; it has to be
hit from above or behind.

    python3 tools/art/gen_shieldbearer.py [preview_dir]

Writes assets/sprites/shieldbearer_walk.png (8 frames), _attack.png (6: brace,
shove the shield forward, hold, recover) and _death.png (6: the shield drops
flat in front, the body sags to its knees and slumps forward over it), 60x50, facing
right, same frame and origin as the soldier (body 13px left of centre).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side
from gen_soldier import leg, over, FW, FH, ORIGIN


def shield(x, top, bottom, rot=0.0, pivot=None, z=9):
    """Tower shield seen edge-on-ish: a tall steel slab with a bronze rim,
    rivets down the face and a dark viewing slit near the top. Its own
    figure (a figure's rotation applies to all of it), laid over the body."""
    fig = Figure()
    if rot:
        fig.transform(rot, pivot or (x, bottom), (0, 0))
    fig.poly([(x - 1.5, top + 1), (x + 3.2, top), (x + 3.6, bottom - 1), (x - 1.2, bottom)], STEEL, z=z, shade=0.75)
    fig.capsule((x + 3.4, top + 0.5), (x + 3.6, bottom - 1), 0.8, BRONZE, z=z + 0.1)     # rim
    fig.capsule((x - 1.3, top + 1), (x + 3.2, top), 0.8, BRONZE, z=z + 0.1)
    for k in range(4):
        y = top + 5 + k * (bottom - top - 8) / 3
        fig.sphere((x + 2.4, y), 0.6, BRONZE, z=z + 0.2)
    fig.capsule((x + 1.0, top + 3.2), (x + 3.4, top + 3.0), 0.45, DARK, z=z + 0.2)      # slit
    return fig.render(FW, FH, ORIGIN)


def build(i, n=8, walk=True, shove=0.0, lean=0.0, kneel=0.0, tip=0.0, dim=0.0,
          shield_down=0.0, breathe=0.0):
    ph = i / n * 2 * math.pi
    s = math.sin(ph) if walk else 0.0
    bob = (abs(math.cos(ph)) * 1.0) if walk else 0.0
    hip = (-0.5, -15 + bob + kneel * 8)
    fig = Figure()
    if tip:
        fig.transform(tip, (3, 0), (0, 0))   # slumps forward over its fallen shield
    if kneel:
        leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -25 * kneel, 10 + 95 * kneel, False)
        leg(fig, hip, 18 * kneel, 18 + 90 * kneel, True)
    elif walk:  # short, heavy steps
        leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -18 * s, max(0.0, -math.sin(ph + 0.6)) * 35, False)
        leg(fig, hip, 18 * s, max(0.0, math.sin(ph + 0.6)) * 35, True)
    else:
        leg(fig, (hip[0] - 0.5, hip[1] - 0.4), -18, 8, False)
        leg(fig, hip, 12 + shove * 1.2, 24, True)
    cx, cy = lean + shove * 0.4, -24 + bob + kneel * 8 + breathe
    glow = GLOW if dim < 0.5 else DARK
    # boiler on the back, venting pipe
    fig.ellipsoid((cx - 7, cy + 0.5), (3.6, 6.2), BRONZE, z=2)
    fig.capsule((cx - 8.5, cy - 5), (cx - 9.5, cy - 9.5), 0.8, STEEL, z=2.1)
    fig.disc((cx - 9.6, cy - 10), 1.2, DARK, z=2.2)
    # squat steel torso with a bronze belly band
    fig.ellipsoid((cx, cy), (7.2, 8.0), STEEL, z=5)
    fig.ellipsoid((cx + 0.5, cy + 3.5), (7.0, 2.2), BRONZE, z=5.2)
    for a in (210, 250, 290, 330):
        r = math.radians(a)
        fig.sphere((cx + math.cos(r) * 5.6, cy + math.sin(r) * 6.4), 0.55, BRONZE, z=5.3)
    fig.gear((cx - 1.5, cy - 1.5), 2.4, 7, i * 45, BRONZE, z=5.4)
    fig.sphere((cx - 1.5, cy - 1.5), 1.0, glow, z=5.5, emissive=dim < 0.5)
    # head: a low bucket helm tucked behind the shield top
    hx, hy = cx + 1.0, cy - 11 + kneel * 1.5
    fig.ellipsoid((hx, hy), (4.6, 3.8), STEEL, z=6)
    fig.ellipsoid((hx, hy - 3.2), (4.0, 1.2), BRONZE, z=6.05)
    fig.capsule((hx + 1.0, hy + 0.2), (hx + 4.4, hy + 0.2), 0.7, DARK, z=6.1)
    if dim < 0.5:
        fig.capsule_glow((hx + 1.6, hy + 0.2), (hx + 4.2, hy + 0.2), 0.5, z=6.2)
    # arm braced behind the shield
    sh = (cx + 1, cy - 4)
    hand = (cx + 6 + shove * 0.8, cy)
    fig.capsule(sh, hand, 1.7, STEEL, z=7)
    fig.sphere(sh, 2.6, BRONZE, z=7.1)
    # the shield: nearly its whole height, held a hand's width in front
    body = fig.render(FW, FH, ORIGIN)
    sx = cx + 8.5 + shove
    if shield_down:
        # dropped: it topples forward flat onto the ground, foot first
        sh = shield(sx + 4, -28, -0.5, rot=88 * shield_down, pivot=(sx + 7, -0.5))
    else:
        sh = shield(sx, cy - 15, cy + 13, rot=lean * 2)
    return over(sh, body)


def main():
    walk = [build(i) for i in range(8)]
    attack = [
        build(0, walk=False),
        build(1, walk=False, shove=-2.5, lean=-1.5),   # brace
        build(2, walk=False, shove=6, lean=2),         # shove (impact)
        build(3, walk=False, shove=7, lean=2.2),
        build(4, walk=False, shove=4, lean=1),
        build(5, walk=False, shove=1),
    ]
    dead = [
        build(0, walk=False, lean=-2),
        build(1, walk=False, kneel=0.5, dim=0.3, shield_down=0.3),
        build(2, walk=False, kneel=1.0, dim=0.6, shield_down=0.75),
        build(3, walk=False, kneel=1.0, dim=1, shield_down=1.0, tip=25),
        build(4, walk=False, kneel=1.0, dim=1, shield_down=1.0, tip=55),
        build(5, walk=False, kneel=1.0, dim=1, shield_down=1.0, tip=78),
    ]
    for name, frames in (('shieldbearer_walk', walk), ('shieldbearer_attack', attack),
                         ('shieldbearer_death', dead)):
        rows = [sum((f[y] for f in frames), []) for y in range(FH)]
        write_png(SPR + name + '.png', FW * len(frames), FH, rows)
    print('wrote shieldbearer_walk/attack/death.png')
    if len(sys.argv) > 1:
        big = side_by_side(walk + attack + dead, 6)
        write_png(sys.argv[1] + '/shieldbearer_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/shieldbearer_walk.gif', walk * 3, [10] * 24, 6)


if __name__ == '__main__':
    main()
