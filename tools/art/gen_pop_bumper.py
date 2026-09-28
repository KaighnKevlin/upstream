"""Pop bumper: a round steel skirt under a domed brass cap (the post), and
the brass kicking ring round it, its own sprite so the code can push it out
(scale it up) when it kicks.

    python3 tools/art/gen_pop_bumper.py [preview_dir]

Writes (both centred on the node origin, the bumper's centre; R = 10):
- pop_bumper_ring.png  26x26, centre (13, 13): a bevelled brass band from
  r 9 to r 12 with rivets, hollow in the middle.
- pop_bumper.png       20x20, centre (10, 10): the steel skirt (r 8.5) with
  a dark groove, bolts, and the brass cap (r 5) with a lit crown.
"""
import math
import sys
from clockwork import *
from clockwork import _shade
from pixtools import write_png
from titan_lib import SPR, side_by_side


def annulus(fig, c, r0, r1, mat, z=0, grit=0.05):
    """A rounded band (a torus seen face-on) between radii r0 and r1."""
    cx, cy = c
    mid, half = (r0 + r1) / 2, (r1 - r0) / 2

    def fn(x, y):
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy)
        if d < r0 or d > r1:
            return None
        k = (d - mid) / half                     # -1 inner edge .. 1 outer edge
        ux, uy = dx / (d or 1), dy / (d or 1)
        nx, ny = ux * k * 0.8, uy * k * 0.8
        return _shade((nx, ny, math.sqrt(max(0.05, 1 - nx * nx - ny * ny))), mat, grit, int(x * 3), int(y * 3))
    fig.prims.append((z, fn, (cx - r1, cy - r1, cx + r1, cy + r1)))


def ring():
    fig = Figure()
    annulus(fig, (0, 0), 9.0, 12.2, BRONZE, z=0)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        fig.sphere((math.cos(a) * 10.6, math.sin(a) * 10.6), 0.6, STEEL, z=0.2)
    return fig.render(26, 26, (13, 13))


def post():
    fig = Figure()
    fig.disc((0, 0), 8.6, STEEL, z=0)                                   # the skirt
    annulus(fig, (0, 0), 5.2, 6.4, DARK, z=0.1)                         # a groove round the cap
    for k in range(6):
        a = k * math.pi / 3
        fig.sphere((math.cos(a) * 7.4, math.sin(a) * 7.4), 0.55, BRONZE, z=0.2)
    fig.sphere((0, 0), 5.2, BRONZE, z=0.3)                              # the domed cap
    fig.sphere((-1.6, -1.6), 1.3, [BRONZE[5], BRONZE[6], BRONZE[7]], z=0.4)   # its lit crown
    return fig.render(20, 20, (10, 10))


def main():
    r, p = ring(), post()
    write_png(SPR + 'pop_bumper_ring.png', 26, 26, r)
    write_png(SPR + 'pop_bumper.png', 20, 20, p)
    print('wrote pop_bumper_ring.png, pop_bumper.png')
    if len(sys.argv) > 1:
        # and the two stacked, as the game shows them
        both = [row[:] for row in r]
        for y in range(20):
            for x in range(20):
                if p[y][x][3]:
                    both[y + 3][x + 3] = p[y][x]
        big = side_by_side([r, p, both], 8)
        write_png(sys.argv[1] + '/pop_bumper_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
