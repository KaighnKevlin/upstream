"""Snare: a clockwork bear trap. A steel base plate with a brass pressure
pan in the middle, two toothed half-hoop jaws hinged at the plate, and a
wind-up spring drum on each side.

    python3 tools/art/gen_snare.py [preview_dir]

Writes assets/sprites/snare.png: 4 frames of 36x20, feet at (18, 19):
0 = set (jaws flat), 1 = snapping, 2 = shut (jaws meeting overhead),
3 = winding back open.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 36, 20, (18, 19)


def jaw(fig, side, closed, z):
    """One jaw: a quarter-circle arc from its hinge at (side*9, -2) up to the
    apex over the pan when shut (closed = 1), swung 135 degrees outward about
    the hinge to lie flat when set (closed = 0). Teeth on the inner edge."""
    hx, hy, R = side * 9.0, -2.0, 8.5
    rot = side * math.radians(135) * (1 - closed)
    c, s_ = math.cos(rot), math.sin(rot)
    def place(x, y):          # a point of the shut arc, rotated about the hinge
        ux, uy = x - hx, y - hy
        return (hx + ux * c - uy * s_, min(hy - 0.6, hy + ux * s_ + uy * c))   # lies on the plate, not through it
    pts, teeth = [], []
    for k in range(8):
        t = k / 7 * math.pi / 2
        x, y = side * (9 - R + R * math.cos(t)), hy - R * math.sin(t)
        pts.append(place(x, y))
        if 1 <= k <= 6:
            # teeth point toward the arc's centre (inward/down when shut)
            tx, ty = side * (9 - R + (R - 2.2) * math.cos(t)), hy - (R - 2.2) * math.sin(t)
            teeth.append((place(x, y), place(tx, ty)))
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 0.95, STEEL, z=z)
    for p, q in teeth:
        fig.capsule(p, q, 0.45, STEEL, z=z - 0.05)


def build(i):
    fig = Figure()
    closed = [0.0, 0.55, 1.0, 0.3][i]
    fig.box((-15, -3, 15, 0), DARK, z=0, bevel=0.8)                     # base plate
    fig.box((-4, -4.2, 4, -2.6), BRONZE, z=0.5, bevel=0.5)              # pressure pan
    for side in (-1, 1):
        fig.disc((side * 15, -4), 3.2, DARK, z=0.3)                     # spring drums
        fig.gear((side * 15, -4), 2.8, 8, i * 20 * side, BRONZE, z=0.4, hub_mat=STEEL)
        jaw(fig, side, closed, 1 + (0.1 if side > 0 else 0))
    return fig.render(W, H, O)


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'snare.png', W * 4, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote snare.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/snare_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
