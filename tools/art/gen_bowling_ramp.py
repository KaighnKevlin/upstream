"""Bowling ramp: a tall brass slide on an oak trestle. From a funnel mouth
at the top it drops near-straight, then curls out flat along the floor to
its exit lip. Drawn sending to +x (the code mirrors it for side -1).

    python3 tools/art/gen_bowling_ramp.py [preview_dir]

Writes bowling_ramp.png, 78x150, the piece's origin (its foot on the
floor under the slide's bend) at (26, 146). The slide is the code's path:
a quadratic curve (0, -120) -> (2, -7) -> (46, -7); the brass rail it runs
on is 8 px outside it (behind, then under), the steel guard rail 8 px
inside it down the steep drop (where y < -30). The trestle post stands at
x -18; the funnel lips run (+-17, -140) -> (+-9, -120); the exit lip is at
(46, 1).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
A, B, C = (0, -120), (2, -7), (46, -7)
W, H, O = 78, 150, (26, 146)


def path(n=48):
    pts = []
    for i in range(n + 1):
        t = i / n
        q = [(1 - t) ** 2 * A[k] + 2 * (1 - t) * t * B[k] + t * t * C[k] for k in (0, 1)]
        pts.append(tuple(q))
    return pts


def offsets(pts, d):
    """-> points d px to the outside of the curve (the code's `n`)."""
    out = []
    for i in range(len(pts)):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1
        tx, ty = tx / L, ty / L
        out.append((pts[i][0] - ty * d, pts[i][1] + tx * d))
    return out


def ramp():
    fig = Figure()
    pts = path()
    outer = offsets(pts, 8)
    rail = offsets(pts, 9)
    inner = [p for p, q in zip(offsets(pts, -8), pts) if q[1] < -30]
    # the trestle: an oak post, braced out to the rail
    fig.box((-20.5, -122, -15.5, 0), OAK, z=0, bevel=0.9)
    fig.capsule((-16.5, -120), (-16.5, -1), 0.5, OAK[:2], z=0.05)
    for y in (-104, -72, -40, -12):
        fig.box((-21, y - 1.1, -15, y + 1.1), STEEL, z=0.2, bevel=0.4)
    for y in (-24, -56, -88):
        k = next(i for i, p in enumerate(outer) if p[1] >= y)
        tgt = rail[k]
        fig.capsule((-18, y), (tgt[0], tgt[1] + 2), 1.1, OAK, z=0.1)
        fig.sphere((-18, y), 0.8, BRONZE, z=0.3)
        fig.box((tgt[0] - 1.8, tgt[1] - 1.8, tgt[0] + 1.8, tgt[1] + 1.8), STEEL, z=0.55, bevel=0.5)   # the clamp
    fig.box((-23, -1.8, 44, 1.6), OAK, z=0.15, bevel=0.7)                     # the sill along the floor
    for x in (-18, 10, 34):
        fig.sphere((x, -0.1), 0.6, STEEL, z=0.2)
    # the slide: a wide brass rail (with a lit inner face) and a steel guard
    for p, q in zip(outer, outer[1:]):
        fig.capsule(p, q, 1.7, BRONZE, z=0.4)
    for p, q in zip(offsets(pts, 6.9), offsets(pts, 6.9)[1:]):
        fig.capsule(p, q, 0.45, BRONZE[4:], z=0.45)
    for p, q in zip(inner, inner[1:]):
        fig.capsule(p, q, 1.0, STEEL, z=0.4)
    # a few straps across the drop, holding the guard to the rail
    for i in (4, 12, 20):
        o, g = outer[i], offsets(pts, -8)[i]
        fig.capsule(o, g, 0.55, STEEL[:5], z=0.35)
    # the mouth: flared brass plates with steel rims
    for s in (-1, 1):
        fig.poly([(s * 17, -140.5), (s * 21, -140.5), (s * 12, -120), (s * 9, -120)], BRONZE, z=0.6, shade=0.5)
        fig.capsule((s * 17, -140), (s * 9, -120), 0.9, BRONZE[2:], z=0.65)
        fig.box((s * 19 - 3, -142.5, s * 19 + 3, -139.5), STEEL, z=0.7, bevel=0.6)
        fig.sphere((s * 13.5, -130), 0.6, STEEL, z=0.7)
    # the exit lip
    fig.disc((46, 1), 2.6, BRONZE, z=0.8)
    fig.sphere((46, 1), 1.1, STEEL, z=0.85)
    return fig.render(W, H, O, extra=OAK_EXTRA)


def main():
    r = ramp()
    write_png(SPR + 'bowling_ramp.png', W, H, r)
    print('wrote bowling_ramp.png')
    if len(sys.argv) > 1:
        big = side_by_side([r], 4)
        write_png(sys.argv[1] + '/bowling_ramp_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
