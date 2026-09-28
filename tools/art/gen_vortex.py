"""Vortex funnel: a beaten-brass coin funnel on a splayed oak stand, in
three layers so the marbles circling in it show through the bowl:
the stand (behind), the bowl (the code draws it a little translucent,
with the swirl lines over it) and the rim and spout (in front).

    python3 tools/art/gen_vortex.py [preview_dir]

Writes three 124x118 sprites, all with the node origin (the rim's
centre) at (62, 20): vortex_stand.png, vortex_bowl.png, vortex_rim.png.
The rim is the ellipse r 56 x 15.7 about the origin; the cone runs from
it down to the spout, +-7 at y 64; the spout collar is y 64..72; the legs
run from (+-34, 29) to (+-42, 94).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 124, 118, (62, 20)
R, DEPTH, TILT, SPOUT = 56.0, 64.0, 0.28, 7.0
OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def _ell(a):
    return (math.cos(a) * R, math.sin(a) * R * TILT)


def stand():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * R * 0.6, DEPTH * 0.45), (s * R * 0.75, DEPTH + 30), 1.3, OAK, z=0)
        fig.box((s * R * 0.75 - 3, DEPTH + 28.5, s * R * 0.75 + 3, DEPTH + 31.5), STEEL, z=0.1, bevel=0.5)
    fig.capsule((-R * 0.68, DEPTH + 12), (R * 0.68, DEPTH + 12), 0.9, OAK, z=-0.1)   # the stretcher
    return fig.render(W, H, O, extra=OAK_EXTRA)


def bowl():
    fig = Figure()
    # (the far side, inside the rim's top half, is left open: marbles
    # circling round the back show there)
    # the near cone: beaten brass panels, lit from the left
    n = 8
    for k in range(n):
        u0, u1 = -1 + 2 * k / n, -1 + 2 * (k + 1) / n
        a0, a1 = math.acos(-u0), math.acos(-u1)
        top0 = (-math.cos(a0) * R, math.sin(a0) * R * TILT)
        top1 = (-math.cos(a1) * R, math.sin(a1) * R * TILT)
        fig.poly([top0, top1, (SPOUT * u1, DEPTH), (SPOUT * u0, DEPTH)], BRONZE, z=0.1,
                 shade=0.62 - 0.42 * k / (n - 1), grit=0.05)
        if k:
            fig.capsule(top0, (SPOUT * u0, DEPTH), 0.35, BRONZE[:3], z=0.15)   # seams
    for y in (22, 44):                                                         # hoops
        hw = R + (SPOUT - R) * y / DEPTH
        pts = [(math.cos(math.pi * k / 16) * hw, y + math.sin(math.pi * k / 16) * hw * TILT) for k in range(17)]
        for p, q in zip(pts, pts[1:]):
            fig.capsule(p, q, 0.6, STEEL, z=0.2)
    return fig.render(W, H, O, outline=False)


def rim():
    fig = Figure()
    pts = [_ell(2 * math.pi * k / 48) for k in range(49)]
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 1.4, BRONZE, z=1 if p[1] > 0 else 0.5)
    for k in range(0, 48, 6):
        x, y = _ell(2 * math.pi * k / 48 + 0.06)
        fig.sphere((x, y), 0.6, STEEL, z=1.2)
    for s in (-1, 1):
        fig.capsule((s * R, 0.5), (s * SPOUT, DEPTH), 0.9, BRONZE[:6], z=0.8)   # the cone's edges
    fig.box((-SPOUT - 1.5, DEPTH - 0.5, SPOUT + 1.5, DEPTH + 7.5), BRONZE, z=1, bevel=1.0)
    fig.box((-SPOUT - 2, DEPTH + 2.5, SPOUT + 2, DEPTH + 4.5), STEEL, z=1.1, bevel=0.5)
    return fig.render(W, H, O)


def main():
    s, b, r = stand(), bowl(), rim()
    write_png(SPR + 'vortex_stand.png', W, H, s)
    write_png(SPR + 'vortex_bowl.png', W, H, b)
    write_png(SPR + 'vortex_rim.png', W, H, r)
    print('wrote vortex_stand.png, vortex_bowl.png, vortex_rim.png')
    if len(sys.argv) > 1:
        comp = [[(r[y][x] if r[y][x][3] else b[y][x] if b[y][x][3] else s[y][x]) for x in range(W)] for y in range(H)]
        big = side_by_side([comp], 3)
        write_png(sys.argv[1] + '/vortex_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
