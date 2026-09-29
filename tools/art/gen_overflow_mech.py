"""Overflow gate, as a real marble-machine part: a counterweighted flap on a
steel tent. The flap stands on the apex, leaning over the overflow plate so
every marble rolls down the primary side; an iron arm fixed under it
carries the counterweight (a stack of iron discs, one per piece it waits
for) that holds it there. When the primary line has backed up to the gate,
the next marble can't roll that way: the queue behind shoves it against the
flap, the flap yields (the counterweight swings up) and the marble goes
over the overflow side; as soon as the primary side has room the weight
swings the flap back. For a physics line that ends in a heap, a brass
feeler pan set where it ends pulls the flap over on a string once enough
pieces sit still in it.

    python3 tools/art/gen_overflow_mech.py [preview_dir]

Drawn primary to the right, overflow to the left (the code mirrors it with
scale.x = side). Measured from the pivot = the apex, the node origin; y down.
- overflow_frame.png   44x44, the apex at (22, 28): the oak A-frame and
  foot plate (row +14), the funnel lips (+-18, -24) -> (+-10, -12), and the
  tent: steel plates from the apex down to (+-12.8, 7.8) (0.55 rad), top
  edge on the rolling line, with a brass apex block.
- overflow_flap.png    26x26, the pivot at (13, 13): the flap upright
  (rotation 0), blade to y -11; the counterweight arm down to (-4, 8)
  where the discs hang. The code rotates it -0.45 (resting over the
  overflow side) .. +0.45 (yielded).
- overflow_disc.png    7x3, its centre at (3, 1): one counterweight disc.
- overflow_pan.png     20x9, the hanger at (10, 1): the feeler pan.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]
TILT, ARM = 0.55, 15.0


def frame():
    fig = Figure()
    ex, ey = ARM * math.cos(TILT), ARM * math.sin(TILT)
    for s in (-1, 1):
        fig.capsule((s * 2.5, 5), (s * 8, 13), 1.4, OAK, z=0, grit=0.1)   # oak legs
    fig.box((-11, 12.3, 11, 14.8), IRON, z=0.2, bevel=0.6)               # foot plate
    for x in (-8, 8):
        fig.sphere((x, 13.5), 0.6, BRONZE, z=0.3)
    for s in (-1, 1):
        fig.capsule((s * 1.0, 1.1), (s * ex, ey + 1.1), 1.15, STEEL, z=0.5)   # the tent's plates
        fig.sphere((s * ex * 0.6, ey * 0.6 + 1.3), 0.5, BRONZE, z=0.6)
        fig.box((s * ex - 1.2, ey - 0.3, s * ex + 1.2, ey + 2.6), BRONZE, z=0.65, bevel=0.5)
    fig.poly([(-3.2, 3.8), (3.2, 3.8), (2.2, -0.6), (-2.2, -0.6)], BRONZE, z=0.7, shade=0.55)   # apex block
    for s in (-1, 1):                                                    # funnel lips
        fig.capsule((s * 18, -24), (s * 10, -12), 1.5, STEEL, z=1)
        fig.box((s * 18 - 1.6, -26.2, s * 18 + 1.6, -23), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((s * 18, -24.6), 0.55, STEEL, z=1.2)
    return fig.render(44, 44, (22, 28), extra=OAK_EXTRA)


def flap():
    fig = Figure()
    fig.capsule((0, 0), (-4, 8), 0.8, IRON, z=0)                         # counterweight arm
    fig.sphere((-4, 8), 1.0, IRON, z=0.05)
    fig.poly([(-1.6, 0), (1.6, 0), (1.2, -11), (-1.2, -11)], OAK, z=0.2, shade=0.6, grit=0.1)   # oak flap
    fig.box((-1.6, -11.6, 1.6, -9.8), BRONZE, z=0.25, bevel=0.4)         # its brass cap
    fig.box((-1.7, -5.5, 1.7, -4.3), IRON, z=0.25, bevel=0.3)            # strap
    fig.disc((0, 0), 2.2, STEEL, z=0.3)                                  # hinge
    fig.sphere((0, 0), 0.9, BRONZE, z=0.4)
    return fig.render(26, 26, (13, 13), extra=OAK_EXTRA)


def disc():
    fig = Figure()
    fig.box((-3, -1, 3, 1), IRON, z=0, bevel=0.5)
    return fig.render(7, 3, (3, 1))


def pan():
    fig = Figure()
    fig.poly([(-9, 2), (9, 2), (6, 6.5), (-6, 6.5)], BRONZE, z=0, shade=0.5)
    fig.box((-9.5, 1.2, 9.5, 2.8), [BRONZE[4], BRONZE[5], BRONZE[6], BRONZE[7]], z=0.1, bevel=0.4)
    fig.capsule((0, 0.5), (0, 2), 0.6, STEEL, z=0.2)                     # hanger
    fig.sphere((0, 0.5), 0.8, STEEL, z=0.25)
    return fig.render(20, 9, (10, 1))


def main():
    parts = {'overflow_frame': frame(), 'overflow_flap': flap(), 'overflow_disc': disc(), 'overflow_pan': pan()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side(list(parts.values()), 8)
        write_png(sys.argv[1] + '/overflow_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
