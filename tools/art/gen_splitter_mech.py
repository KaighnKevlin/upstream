"""Splitter, as a real marble-machine part: a tipping-T toggle. A steel tent
(two plates sloping down from a brass apex block) with a pivoted T on its
apex: an upright blade that leans over one plate and blocks it, two toes
lying along the plates, and a tail hanging inside the tent. A marble rolls
down the open plate over that side's raised toe, presses it flat, and the
T rocks over: the blade now blocks the side it just used. A brass locking
peg in one of three holes on the plate under the apex jams the tail so the
T can't rock: left hole, everything goes left; right hole, right; the
parking hole at the bottom leaves it free.

    python3 tools/art/gen_splitter_mech.py [preview_dir]

Writes (all measured from the pivot = the apex, the node origin; y down;
the plates run from it to (+-13.2, 7.2), angle 0.5 rad):
- splitter_roof.png  34x24, the apex at (17, 5): the plates (their top edge
  on the line the marbles roll on), the apex block, and the lock plate with
  its holes at (-2, 10), (2, 10) and the parking hole (0, 15).
- splitter_vane.png  30x26, the pivot at (15, 13): the T upright (rotation
  0): blade up to y -10, toes along +-x to 7 px (just below horizontal, so
  they lie flat on a plate when the T leans 0.45 rad over it), the tail
  down to y +10 with a knob. The code rotates it +-0.45.
- splitter_peg.png   5x5, its centre at (2, 2): the locking peg's head.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]
TILT = 0.5
HALF = 15.0


def roof():
    fig = Figure()
    ex, ey = HALF * math.cos(TILT), HALF * math.sin(TILT)
    # the lock plate inside the tent, behind everything
    fig.poly([(-4.2, 6), (4.2, 6), (3.6, 17), (-3.6, 17)], IRON, z=-0.5, shade=0.35)
    for (hx, hy) in ((-2, 10), (2, 10), (0, 15)):
        fig.disc((hx, hy), 1.1, DARK, z=-0.4)
    for s in (-1, 1):
        # a plate: its top edge on the rolling line, 2 px thick under it
        fig.capsule((s * 1.0, 1.1), (s * ex, ey + 1.1), 1.15, STEEL, z=0)
        fig.sphere((s * ex * 0.55, ey * 0.55 + 1.3), 0.5, BRONZE, z=0.1)   # rivet
        fig.box((s * ex - 1.2, ey - 0.3, s * ex + 1.2, ey + 2.6), BRONZE, z=0.15, bevel=0.5)   # lip at the end
    fig.poly([(-3.2, 3.8), (3.2, 3.8), (2.2, -0.6), (-2.2, -0.6)], BRONZE, z=0.2, shade=0.55)   # apex block
    return fig.render(34, 24, (17, 5))


def vane():
    fig = Figure()
    fig.capsule((0, 0), (0, 10), 0.8, IRON, z=0)                          # tail
    fig.sphere((0, 10), 1.3, IRON, z=0.05)                               # its knob
    for s in (-1, 1):
        fig.capsule((0, -0.5), (s * 7, -0.2), 0.75, BRONZE, z=0.1)       # toes
        fig.sphere((s * 7, -0.2), 0.9, BRONZE, z=0.15)
    fig.box((-1.1, -10, 1.1, 0), STEEL, z=0.2, bevel=0.5)                # the blade
    fig.box((-1.4, -10.8, 1.4, -9.2), BRONZE, z=0.25, bevel=0.4)         # its cap
    fig.disc((0, 0), 2.2, STEEL, z=0.3)                                  # hub
    fig.sphere((0, 0), 0.9, BRONZE, z=0.4)
    return fig.render(30, 26, (15, 13))


def peg():
    fig = Figure()
    fig.sphere((0, 0), 1.9, BRONZE, z=0)
    fig.sphere((-0.5, -0.5), 0.6, [BRONZE[6], BRONZE[7]], z=0.1)
    return fig.render(5, 5, (2, 2))


def main():
    r, v, p = roof(), vane(), peg()
    write_png(SPR + 'splitter_roof.png', 34, 24, r)
    write_png(SPR + 'splitter_vane.png', 30, 26, v)
    write_png(SPR + 'splitter_peg.png', 5, 5, p)
    print('wrote splitter_roof.png, splitter_vane.png, splitter_peg.png')
    if len(sys.argv) > 1:
        big = side_by_side([r, v, p], 8)
        write_png(sys.argv[1] + '/splitter_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
