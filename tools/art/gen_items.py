"""Ore chunks, brass ingots and the spring trampoline.

    python3 tools/art/gen_items.py [preview_dir]

Writes assets/sprites/ore.png (3 variants, 12x12 each), ingot.png (14x8) and
trampoline.png (44x22: brass plate on a steel coil; the plate's top is
3px from the top edge).
"""
import math, random, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side


def ore(seed):
    r = random.Random(seed)
    fig = Figure()
    # lumpy rock: a few overlapping blobs
    for k in range(4):
        a = r.random() * math.tau
        fig.ellipsoid((math.cos(a) * 1.4, math.sin(a) * 1.2), (3.4 + r.random() * 1.2, 2.8 + r.random()),
                      ROCK, z=k * 0.01, tilt=r.random() * 90, grit=0.12)
    # copper nuggets breaking the surface
    for k in range(3 + seed % 2):
        a = r.random() * math.tau; d = 1.2 + r.random() * 1.6
        fig.sphere((math.cos(a) * d, math.sin(a) * d), 0.9 + r.random() * 0.6, COPPER, z=1 + k * 0.01, grit=0.03)
    return fig.render(12, 12, (6, 6), extra=COPPER_EXTRA)


def ingot():
    fig = Figure()
    fig.box((-6, -2.6, 6, 2.6), BRONZE, z=0, bevel=1.6, grit=0.03)
    fig.box((-4.6, -2.6, 4.6, -0.6), BRONZE, z=1, bevel=1.0, grit=0.02)    # raised top face
    return fig.render(14, 8, (7, 4))


def trampoline():
    fig = Figure()
    # riveted base
    fig.box((-11, 14, 11, 18), DARK, z=0, bevel=1.2)
    for x in (-8, 8):
        fig.sphere((x, 16), 0.8, STEEL, z=0.5)
    # the coil: 3 turns, front strands bright, back strands dark, gaps between
    top, bot, turns = 6.0, 14.0, 3
    n = turns * 2
    for k in range(n):
        y0 = bot + (top - bot) * k / n; y1 = bot + (top - bot) * (k + 1) / n
        front = k % 2 == 0
        fig.capsule((-5 if front else 5, y0), (5 if front else -5, y1), 0.65,
                    STEEL if front else DARK, z=2 if front else 1, grit=0.02)
    # guide posts
    for x in (-9, 9):
        fig.capsule((x, 5.5), (x, 14), 0.7, BRONZE, z=1.5)
    # the brass plate on top, with a dark grip strip
    fig.box((-20, 1.5, 20, 6.0), BRONZE, z=3, bevel=1.5)
    fig.box((-18, 0.3, 18, 2.2), DARK, z=3.5, bevel=0.6, grit=0.02)
    for x in (-17, 17):
        fig.sphere((x, 4.4), 0.8, STEEL, z=3.6)
    return fig.render(44, 22, (22, 3))


def debris():
    """Clockwork debris for deaths: 6 pieces, 8x8 each."""
    pieces = []
    f = Figure(); f.gear((0, 0), 3.0, 7, 10, BRONZE); pieces.append(f)          # brass gear
    f = Figure(); f.gear((0, 0), 2.6, 6, 0, STEEL); pieces.append(f)            # steel gear
    f = Figure(); f.box((-2, -2, 2, 2), STEEL, bevel=0.8, tilt=30)              # hex-ish bolt
    f.disc((0, 0), 0.8, DARK); pieces.append(f)
    f = Figure()                                                               # coil spring
    for k in range(4):
        f.capsule((-2.5, -3 + k * 1.6), (2.5, -2.2 + k * 1.6), 0.45, STEEL, z=k)
    pieces.append(f)
    f = Figure(); f.box((-3, -1.5, 3, 1.5), BRONZE, bevel=0.8, tilt=-20)        # plate shard
    f.sphere((-1.5, 0), 0.5, STEEL, z=1); pieces.append(f)
    f = Figure(); f.ellipsoid((0, 0), (2.4, 1.5), GLOW, emissive=True, tilt=40); pieces.append(f)  # core glass
    return [p.render(8, 8, (4, 4)) for p in pieces]


def main():
    ores = [ore(s) for s in (3, 8, 13)]
    rows = [sum((f[y] for f in ores), []) for y in range(12)]
    write_png(SPR + 'ore.png', 36, 12, rows)
    ing = ingot(); write_png(SPR + 'ingot.png', 14, 8, ing)
    tr = trampoline(); write_png(SPR + 'trampoline.png', 44, 22, tr)
    deb = debris()
    write_png(SPR + 'debris.png', 48, 8, [sum((d[y] for d in deb), []) for y in range(8)])
    print('wrote ore.png, ingot.png, trampoline.png, debris.png')
    if len(sys.argv) > 1:
        pad = lambda f, w, h: [row + [(0, 0, 0, 0)] * (w - len(row)) for row in f] + [[(0, 0, 0, 0)] * w] * (h - len(f))
        big = side_by_side([pad(o, 12, 22) for o in ores] + [pad(ing, 14, 22), tr] + [pad(d, 8, 22) for d in deb], 10)
        write_png(sys.argv[1] + '/items_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
