"""Cave dressing: things that hang from cave ceilings or sit on cave floors.

    python3 tools/art/gen_cave.py [preview_dir]

assets/sprites/cave_decor.png: a strip of 16x16 cells. Ceiling pieces hang
from the top edge of their cell, floor pieces stand on the bottom edge.
  0-2 floor:   cyan crystal clusters (the game gives them a small light)
  3   floor:   fossil gear half sunk in the rock
  4   floor:   glowing cap mushrooms
  5-6 ceiling: stalactites
  7   ceiling: roots (near the surface only)
  8   ceiling: a dangling broken chain with a hook
"""
import math, random, sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

ROOT = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c')]
C = 16


def crystals(seed):
    r = random.Random(seed)
    fig = Figure()
    fig.ellipsoid((0, 15.5), (6, 1.6), ROCK, z=0)
    for k in range(r.randint(3, 4)):
        x = r.uniform(-4, 4)
        h = r.uniform(5, 11) * (1.2 if k == 0 else 1.0)
        lean = x * 0.35 + r.uniform(-1, 1)
        fig.capsule((x, 15), (x + lean, 15 - h), r.uniform(1.0, 1.6), GLOW, z=1 + k * 0.1, grit=0.0)
        fig.sphere((x + lean, 15 - h), 0.6, [GLOW[-1]] * 2, z=2 + k, emissive=True)
    return fig.render(C, C, (8, 0))


def fossil_gear():
    """An old brass gear standing upright in the floor, rubble at its foot."""
    fig = Figure()
    fig.disc((0, 10.5), 5.6, DARK, z=0)                              # shadowed hub face
    fig.gear((0, 10.5), 5.4, 10, 14, BRONZE, z=1)
    fig.sphere((0, 10.5), 1.3, STEEL, z=2)                           # axle stub
    fig.ellipsoid((0, 16), (7.5, 1.4), ROCK, z=3)                    # rubble at its foot
    fig.sphere((-5, 15), 1.2, ROCK, z=3.1)
    return fig.render(C, C, (8, 0))


def mushrooms():
    fig = Figure()
    for x, h, rr in ((-3.5, 6, 2.6), (1.5, 9, 3.2), (5, 4.5, 2.0)):
        fig.capsule((x, 15.5), (x + 0.3, 15.5 - h), 0.6, STEEL, z=0)
        fig.ellipsoid((x + 0.3, 15.5 - h), (rr, rr * 0.55), GLOW, z=1, emissive=True)
    return fig.render(C, C, (8, 0))


def stalactite(seed):
    r = random.Random(seed)
    fig = Figure()
    for k, (x, L, w) in enumerate(((-2.5, r.uniform(9, 14), 2.4), (2.5, r.uniform(5, 9), 1.8), (5.5, r.uniform(3, 5), 1.2))):
        steps = 5
        for i in range(steps):
            t0, t1 = i / steps, (i + 1) / steps
            fig.capsule((x, L * t0), (x + 0.2, L * t1), w * (1 - t0 * 0.8), ROCK, z=k + i * 0.01)
    fig.ellipsoid((0, 0), (7, 1.6), ROCK, z=0)
    return fig.render(C, C, (8, 0))


def roots():
    r = random.Random(5)
    fig = Figure()
    for k in range(4):
        x = r.uniform(-5, 5)
        pts = [(x, 0)]
        for i in range(4):
            px, py = pts[-1]
            pts.append((px + r.uniform(-1.8, 1.8), py + r.uniform(2.5, 3.8)))
        for a, b in zip(pts, pts[1:]):
            fig.capsule(a, b, 0.6 - 0.1 * pts.index(a) * 0.3, ROOT, z=k, grit=0.1)
    return fig.render(C, C, (8, 0))


def chain():
    fig = Figure()
    for i in range(5):
        y = 1 + i * 2.2
        if i % 2 == 0:
            fig.ellipsoid((0, y), (0.9, 1.4), STEEL, z=i)
        else:
            fig.ellipsoid((0, y), (0.45, 1.3), DARK, z=i)
    fig.capsule((0, 11.5), (0, 13.5), 0.6, STEEL, z=6)
    fig.capsule((0, 13.5), (2.5, 14.5), 0.6, STEEL, z=6)   # hook
    fig.capsule((2.5, 14.5), (3, 12.5), 0.6, STEEL, z=6)
    return fig.render(C, C, (8, 0))


def main():
    cells = [crystals(1), crystals(2), crystals(3), fossil_gear(), mushrooms(),
             stalactite(4), stalactite(9), roots(), chain()]
    rows = [sum((c[y] for c in cells), []) for y in range(C)]
    write_png(SPR + 'cave_decor.png', C * len(cells), C, rows)
    print('wrote cave_decor.png (%d cells)' % len(cells))
    if len(sys.argv) > 1:
        big = side_by_side(cells, 8)
        write_png(sys.argv[1] + '/cave_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
