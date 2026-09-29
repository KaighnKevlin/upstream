"""Points switch, as a real part: a railway-style weighted ground throw. A
steel switch tongue on a pivot under the funnel sends everything down one
side; below it, on the foot plate, a throw lever with an iron ball on its
end lies over to one side and its weight holds the tongue there through a
rod. Throwing it (a trigger's pull, or a click) swings the ball up over the
top and down the other side, and the rod drags the tongue across.

    python3 tools/art/gen_points_mech.py [preview_dir]

Writes (all measured from the pivot, the node origin; y down):
- points_frame.png   44x46, the pivot at (22, 28): an iron stand from the
  tongue's bearing to the foot plate on the row +14, the funnel lips
  (+-18, -24) -> (+-10, -12), the lever's bearing at (0, 14) and the two
  stop blocks the lever rests on at (+-10, 12).
- points_tongue.png  36x10, the pivot at (18, 4): the switch tongue, its
  top on the pivot's row, x -15..15 (tapered steel, brass heel). Rotated.
- points_lever.png   16x20, its bearing at (8, 16): the lever straight up
  (rotation 0) to the ball at y -11.5. The code lays it over +-1.25 rad.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]
RED_EXTRA = ['5a1a14', '8e2a1e', 'c0452e']
RED = [(90, 26, 20), (142, 42, 30), (192, 69, 46)]


def frame():
    fig = Figure()
    fig.capsule((0, 2), (0, 12.5), 1.5, IRON, z=0)                       # the stand
    fig.box((-12, 12.8, 12, 15.4), IRON, z=0.2, bevel=0.6)               # foot plate
    for s in (-1, 1):
        fig.box((s * 10 - 1.6, 10.6, s * 10 + 1.6, 13), BRONZE, z=0.3, bevel=0.5)   # stops
    fig.disc((0, 14), 2.2, BRONZE, z=0.35)                               # lever bearing
    fig.disc((0, 1.5), 3.4, IRON, z=0.1)                                 # tongue bearing
    fig.disc((0, 1.5), 1.6, DARK, z=0.15)
    for s in (-1, 1):                                                    # funnel lips
        fig.capsule((s * 18, -24), (s * 10, -12), 1.5, STEEL, z=1)
        fig.box((s * 18 - 1.6, -26.2, s * 18 + 1.6, -23), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((s * 18, -24.6), 0.55, STEEL, z=1.2)
    return fig.render(44, 46, (22, 28))


def tongue():
    fig = Figure()
    fig.poly([(-15, -0.4), (15, -0.4), (15, 0.8), (4, 2.6), (-4, 2.6), (-15, 0.8)], STEEL, z=0, shade=0.6)
    fig.box((-15, -0.6, 15, 0.6), STEEL, z=0.05, bevel=0.3)              # running edge
    fig.disc((0, 1.2), 3.0, BRONZE, z=0.3)                               # heel
    fig.sphere((0, 1.2), 1.1, STEEL, z=0.4)
    return fig.render(36, 10, (18, 4))


def lever():
    fig = Figure()
    fig.capsule((0, 0), (0, -10), 1.0, RED, z=0)                         # painted lever
    fig.sphere((0, -11.5), 3.3, IRON, z=0.2)                             # the ball
    fig.sphere((-1.2, -12.7), 0.9, [STEEL[5], STEEL[6], STEEL[7]], z=0.3)   # its shine
    fig.disc((0, 0), 1.6, BRONZE, z=0.3)
    return fig.render(16, 20, (8, 16), extra=RED_EXTRA)


def main():
    parts = {'points_frame': frame(), 'points_tongue': tongue(), 'points_lever': lever()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side(list(parts.values()), 8)
        write_png(sys.argv[1] + '/points_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
