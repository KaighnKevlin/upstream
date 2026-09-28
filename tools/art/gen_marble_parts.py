"""Sprites for three of the older Marble Works pieces:

- beam_tap.png   44x20, the node origin (the Beam's axis) at (22, 10):
  a brass collar of two riveted bands (rows -7..-4 and 4..7 about the
  origin, x -17..17) tied by steel straps, a steel-lipped spout out to
  +x (17..23), a lamp bezel at x -17 (the code draws the filter colour in
  it). Drawn for side = +1; mirrored for -1.
- sieve_rail.png 18x10, repeats along x, origin row 7: one steel rung
  (x 0..12, its top on row -1, where pieces roll) and a gap of 6, with a
  thin back rail on row -4 that runs through the gap. The code tiles it
  from the high end along the rail.
- loop.png       156x76, the node (the hoop's foot) at (72, 42): a riveted
  steel hoop of radius 23.5 about (0, -16), on a brass stand, and the rail
  from (-70, -1.5) to (80, 12.5). Drawn for side = +1; mirrored for -1.

    python3 tools/art/gen_marble_parts.py [preview_dir]
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:5]


def beam_tap():
    fig = Figure()
    for y0 in (-7.2, 3.8):
        fig.box((-17, y0, 17, y0 + 3.4), BRONZE, z=0.2, bevel=0.8)
        for x in (-11, -3, 5, 13):
            fig.sphere((x, y0 + 1.7), 0.55, STEEL, z=0.3)
    for x in (-15.5, 15.5):
        fig.box((x - 1.2, -6, x + 1.2, 6), IRON, z=0.1, bevel=0.5)   # straps
    # the spout
    fig.box((16, -5, 22.5, 5), BRONZE, z=0.4, bevel=1.0)
    fig.box((21, -5.6, 23.4, 5.6), STEEL, z=0.5, bevel=0.6)
    fig.box((17.5, -2.2, 21, 2.2), DARK, z=0.45, bevel=0.3)
    # the lamp bezel
    fig.disc((-17, 0), 3.4, STEEL, z=0.6)
    fig.disc((-17, 0), 2.2, DARK, z=0.7)
    return fig.render(44, 20, (22, 10))


def sieve():
    fig = Figure()
    fig.box((-4, -5.2, 22, -3.6), STEEL[1:6], z=0, bevel=0.5, grit=0.03)   # the back rail
    for x in (15,):
        fig.capsule((x, -4.2), (x, 1.8), 0.6, IRON, z=0.05)          # a hanger in the gap
    fig.box((0.2, -1.4, 11.8, 1.8), STEEL[2:], z=0.3, bevel=0.9)          # the rung
    fig.sphere((6, 0.2), 0.55, BRONZE, z=0.4)
    return fig.render(18, 10, (0, 7))


def loop():
    fig = Figure()
    c, rr = (0, -16), 23.5
    n = 64
    pts = [(c[0] + math.cos(2 * math.pi * k / n) * rr, c[1] + math.sin(2 * math.pi * k / n) * rr) for k in range(n + 1)]
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 1.5, STEEL, z=0.5)
    for k in range(0, n, 8):
        a = 2 * math.pi * (k + 4) / n
        fig.sphere((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr), 0.6, BRONZE, z=0.6)
    # the stand: brass legs from the hoop's foot to a steel foot plate
    for s in (-1, 1):
        fig.capsule((s * 9, 7.5), (s * 5, 29), 1.1, BRONZE, z=0.1)
    fig.capsule((-7, 18), (7, 18), 0.7, IRON, z=0.05)
    fig.box((-9, 28, 9, 31), IRON, z=0.2, bevel=0.6)
    # the rail
    fig.capsule((-70, -1.5), (80, 12.5), 1.3, STEEL, z=0.3)
    for t in (0.1, 0.3, 0.72, 0.9):
        x, y = -70 + 150 * t, -1.5 + 14 * t
        fig.box((x - 1.2, y + 0.4, x + 1.2, y + 3.6), BRONZE, z=0.25, bevel=0.4)   # sleepers
    return fig.render(156, 76, (72, 42))


def main():
    b, s, lp = beam_tap(), sieve(), loop()
    write_png(SPR + 'beam_tap.png', 44, 20, b)
    write_png(SPR + 'sieve_rail.png', 18, 10, s)
    write_png(SPR + 'loop.png', 156, 76, lp)
    print('wrote beam_tap.png, sieve_rail.png, loop.png')
    if len(sys.argv) > 1:
        ss = [sum((row for _ in range(5)), []) for row in s]
        big = side_by_side([b, ss, lp], 3)
        write_png(sys.argv[1] + '/marble_parts_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
