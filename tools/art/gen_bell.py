"""Bell: a cast brass bell (turned on a lathe: shoulder, waist and a flared
sound-bow, with the clapper ball showing under the lip) hung from a
wrought-iron wall bracket; and the muffled bell, the same bell wrapped in
green felt and tied round the waist.

    python3 tools/art/gen_bell.py [preview_dir]

Writes:
- bell_bracket.png  26x10, the node origin at (13, 7): the bar runs
  x -11..11 on the row y -4, the yoke hangs to the pivot at (0, -2), and
  the pull-wire's eye is at (8, -4).
- bell.png          28x28, the pivot (node (0, -2)) at (14, 2): the bell's
  crown at local y 0, the mouth at y 20 (+-12), the clapper to y 25. The
  code rotates it about the pivot as it swings.
- bell_felt.png     28x28, same frame: the felt-wrapped bell.
"""
import math, sys
import clockwork
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FELT_EXTRA = ['1c3324', '284a33', '366344', '4a7f58', '65a072']
FELT = [(28, 51, 36), (40, 74, 51), (54, 99, 68), (74, 127, 88), (101, 160, 114)]
TWINE_EXTRA = ['5e4028', '946a42', 'c49a62']
TWINE = [(94, 64, 40), (148, 106, 66), (196, 154, 98)]
IRON = STEEL[:6]


def lathe(fig, y0, y1, rfun, mat, z=0, grit=0.05):
    """A surface of revolution about x = 0 (seen side on), radius rfun(y)
    for y0 <= y <= y1, lit as a round body."""
    rmax = max(rfun(y0 + (y1 - y0) * k / 20) for k in range(21))

    def fn(x, y):
        if y < y0 or y > y1: return None
        r = rfun(y)
        if r <= 0 or abs(x) > r: return None
        u = x / r
        nz = math.sqrt(max(0.0, 1 - u * u))
        dr = (rfun(min(y1, y + 0.2)) - rfun(max(y0, y - 0.2))) / 0.4
        nx, ny = u * 1.15, -dr * nz * 0.8
        l = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
        return clockwork._shade((nx / l, ny / l, nz / l), mat, grit, int(x * 3), int(y * 3))
    fig.prims.append((z, fn, (-rmax, y0, rmax, y1)))


def bell_r(y):
    t = max(0.0, min(1.0, (y - 1.0) / 19.0))
    return 3.6 + 3.0 * t + 5.4 * t ** 4


def bracket():
    fig = Figure()
    fig.box((-11, -5.4, 11, -2.6), IRON, z=0, bevel=0.8)              # the bar
    fig.box((-12.5, -6.6, -10, -1.4), IRON, z=0.1, bevel=0.6)         # wall plate
    fig.sphere((-11.3, -4), 0.55, STEEL, z=0.2)
    fig.capsule((-9, -2.6), (-4, 1.5), 0.6, IRON, z=-0.1)             # a scroll brace
    fig.box((-2.2, -3.2, 2.2, -0.6), IRON, z=0.3, bevel=0.6)          # the yoke
    fig.sphere((0, -2), 0.8, BRONZE, z=0.4)                           # its pin
    fig.disc((8, -4), 1.5, BRONZE, z=0.4)                             # the pull-wire's eye
    fig.sphere((8, -4), 0.6, DARK, z=0.5)
    return fig.render(26, 10, (13, 7))


def bell(felt=False):
    fig = Figure()
    fig.disc((0, -0.2), 1.7, BRONZE, z=0)                             # the crown loop
    fig.sphere((0, -0.2), 0.7, DARK, z=0.1)
    fig.ellipsoid((0, 1.9), (3.7, 1.9), BRONZE, z=0.2)                # shoulder dome
    if not felt:
        fig.capsule((0, 16), (0, 22.5), 0.5, IRON, z=-0.5)            # the clapper
        fig.sphere((0, 23), 2.0, STEEL, z=-0.4)
        lathe(fig, 1.5, 20.2, bell_r, BRONZE, z=0.3)
        for y in (6.0, 16.6):
            r = bell_r(y) - 0.1
            fig.capsule((-r + 0.5, y), (r - 0.5, y), 0.4, BRONZE, z=0.5)   # cast bands
        fig.capsule((-11.9, 19.9), (11.9, 19.9), 1.1, BRONZE, z=0.6)       # the sound-bow lip
        fig.poly([(-2.6, 4.5), (-1.8, 4.5), (-4.6, 16), (-5.6, 16)], BRONZE, z=0.7, shade=0.97, grit=0)  # glint
        return fig.render(28, 28, (14, 2))
    # the felt: bulkier than the bell, gathered under the mouth
    lathe(fig, 1.0, 21.5, lambda y: bell_r(min(y, 20.0)) + 0.9 - max(0.0, y - 20.0) * 1.2, FELT, z=0.3, grit=0.12)
    fig.ellipsoid((0, 21.8), (7.5, 2.2), FELT, z=0.35, grit=0.12)
    r = bell_r(12) + 1.0
    fig.capsule((-r, 12), (r, 12), 0.75, TWINE, z=0.6)                # tied round the waist
    fig.sphere((2.5, 12.3), 1.1, TWINE, z=0.7)                         # the knot
    fig.capsule((2.5, 12.5), (3.8, 16.5), 0.45, TWINE, z=0.65)
    fig.capsule((2.2, 12.5), (1.2, 16), 0.45, TWINE, z=0.65)
    return fig.render(28, 28, (14, 2), extra=FELT_EXTRA + TWINE_EXTRA)


def main():
    br, b, f = bracket(), bell(), bell(True)
    write_png(SPR + 'bell_bracket.png', 26, 10, br)
    write_png(SPR + 'bell.png', 28, 28, b)
    write_png(SPR + 'bell_felt.png', 28, 28, f)
    print('wrote bell_bracket.png, bell.png, bell_felt.png')
    if len(sys.argv) > 1:
        big = side_by_side([br, b, f], 8)
        write_png(sys.argv[1] + '/bell_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
