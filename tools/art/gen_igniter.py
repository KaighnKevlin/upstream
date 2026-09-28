"""Igniter: an iron fire basket hung from a bracket over a track, coals
glowing in it, and the flame that licks down out of its grate.

    python3 tools/art/gen_igniter.py [preview_dir]

Writes (all measured from the node origin, the point on the track below):
- igniter.png        18x26, the origin at (9, 26): a bolted mounting plate
  at y -24, the hanger rod, a yoke down to the rim, the tapered iron basket
  (rim y -12, grate y -3) with its straps, coals peeking over the rim.
- igniter_flame.png  3 frames of 10x14, the origin at (5, 4) in each: the
  flame hangs from the grate (y -3) down to about y +8, a bright core in
  it; the code steps the frames for a flicker and hangs it behind the
  basket.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FIRE_EXTRA = ['5a1e0c', 'aa3c14', 'e66e28', 'ffb450', 'ffecaa']
OUTER = [(90, 30, 12), (170, 60, 20), (230, 110, 40), (255, 180, 80)]
CORE = [(255, 180, 80), (255, 236, 170), (255, 248, 220)]
COALS = [(90, 30, 12), (170, 60, 20), (230, 110, 40), (255, 180, 80)]


def basket():
    fig = Figure()
    fig.box((-4, -24.6, 4, -22.4), STEEL, z=0, bevel=0.6)                # the mounting plate
    for x in (-2.6, 2.6):
        fig.sphere((x, -23.5), 0.55, BRONZE, z=0.1)
    fig.capsule((0, -22.5), (0, -19.4), 0.9, STEEL, z=0.05)              # the hanger rod
    for s in (-1, 1):
        fig.capsule((s * 7, -12.4), (s * 1.2, -18.4), 0.55, STEEL, z=0.06)   # the yoke to the rim
    fig.sphere((0, -18.6), 1.2, BRONZE, z=0.07)                          # the ring it hangs by
    fig.ellipsoid((0, -13.2), (5.6, 2.2), COALS, z=0.1, emissive=True)   # coals heaped over the rim
    for x, y in ((-2.5, -14.2), (1.8, -14.6)):
        fig.sphere((x, y), 0.9, CORE, z=0.11, emissive=True)
    fig.poly([(-7.6, -12), (7.6, -12), (4.6, -3), (-4.6, -3)], STEEL, z=0.2, shade=0.5)   # the basket
    fig.box((-8, -12.8, 8, -10.6), STEEL, z=0.3, bevel=0.6)              # its rim
    for x in (-4, 0, 4):
        fig.capsule((x, -10.6), (x * 0.6, -3.6), 0.4, DARK, z=0.35)      # straps
    fig.box((-5, -4, 5, -2.4), DARK, z=0.4, bevel=0.4)                   # the grate
    for x in (-3, 0, 3):
        fig.sphere((x, -3.2), 0.45, COALS, z=0.45, emissive=True)         # embers through it
    return fig.render(18, 26, (9, 26), extra=FIRE_EXTRA)


def flame(i):
    fig = Figure()
    L = [8.0, 9.6, 7.2][i]                                                # how far it licks down
    sway = [0.0, 0.7, -0.6][i]
    # the outer flame: a teardrop hanging from the grate, stacked blobs
    for k, (t, r) in enumerate(((0.0, 3.6), (0.3, 3.0), (0.55, 2.1), (0.78, 1.3), (0.95, 0.7))):
        fig.ellipsoid((sway * t, -2.2 + L * t), (r, r * 1.1), OUTER, z=0.1 + k * 0.01, emissive=True)
    # the core
    for k, (t, r) in enumerate(((0.0, 1.8), (0.25, 1.4), (0.45, 0.8))):
        fig.ellipsoid((sway * t * 0.8, -2.2 + L * t), (r, r * 1.2), CORE, z=0.5 + k * 0.01, emissive=True)
    return fig.render(10, 14, (5, 4), outline=False, extra=FIRE_EXTRA)


def main():
    b = basket()
    fr = [flame(i) for i in range(3)]
    write_png(SPR + 'igniter.png', 18, 26, b)
    write_png(SPR + 'igniter_flame.png', 30, 14, [sum((f[y] for f in fr), []) for y in range(14)])
    print('wrote igniter.png, igniter_flame.png')
    if len(sys.argv) > 1:
        # and each frame hung under the basket, as the game shows it
        shown = []
        for f in fr:
            img = [row[:] for row in b] + [[(0, 0, 0, 0)] * 18 for _ in range(10)]
            for y in range(14):
                for x in range(10):
                    if f[y][x][3] and not img[y + 22][x + 4][3]:
                        img[y + 22][x + 4] = f[y][x]          # the basket is in front
            shown.append(img)
        big = side_by_side([b] + fr + shown, 8)
        write_png(sys.argv[1] + '/igniter_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
