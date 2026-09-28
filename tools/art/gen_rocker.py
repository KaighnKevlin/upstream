"""Flip-flop rocker: a brass rocker bar on a steel pivot boss, and the stand
it sits on: a riveted A-frame with two steel funnel lips above that steer
drops onto the pivot. Also the base art of the weigh scale, overflow gate
and points (they draw their own extras over it).

    python3 tools/art/gen_rocker.py [preview_dir]

Writes assets/sprites/rocker_bar.png (36x10, the pivot at (18, 4); the top
of the bar, where marbles roll, is on the pivot's row, so the code rotates
the sprite by the rocker's angle about that point) and rocker_base.png
(44x44, the pivot at (22, 28); lips run (+-18, -24) -> (+-10, -12) and the
feet stand on the row at +14 from the pivot).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

BAR_W, BAR_H, BAR_O = 36, 10, (18, 4)
BASE_W, BASE_H, BASE_O = 44, 44, (22, 28)


def bar():
    fig = Figure()
    # the rocker: a brass beam, a touch thicker at the middle, capped in steel
    fig.box((-15, -0.5, 15, 2.2), BRONZE, z=0, bevel=0.8)
    fig.poly([(-9, 2), (9, 2), (5, 4.2), (-5, 4.2)], BRONZE, z=-0.1, shade=0.45)   # the keel under the pivot
    for x in (-15, 15):
        fig.box((x - 1.4, -0.8, x + 1.4, 2.6), STEEL, z=0.2, bevel=0.6)
    for x in (-9, 9):
        fig.sphere((x, 0.9), 0.6, STEEL, z=0.3)       # rivets
    # the pivot boss and its pin
    fig.disc((0, 1), 3.2, STEEL, z=0.5)
    fig.sphere((0, 1), 1.3, BRONZE, z=0.6)
    return fig.render(BAR_W, BAR_H, BAR_O)


def base():
    fig = Figure()
    # A-frame from the pivot down to a foot plate
    for s in (-1, 1):
        fig.capsule((0, 2), (s * 6.5, 13), 1.3, BRONZE, z=0)
    fig.capsule((-3.8, 8.5), (3.8, 8.5), 0.7, DARK, z=-0.1)         # cross brace
    fig.box((-9, 12.3, 9, 14.8), STEEL, z=0.2, bevel=0.6)
    for x in (-6.5, 6.5):
        fig.sphere((x, 13.5), 0.6, BRONZE, z=0.3)
    fig.disc((0, 2.5), 3.4, BRONZE, z=0.1)                            # the bearing the bar sits in
    fig.disc((0, 2.5), 1.6, DARK, z=0.15)
    # funnel lips: steel plates on brass clamps
    for s in (-1, 1):
        fig.capsule((s * 18, -24), (s * 10, -12), 1.5, STEEL, z=1)
        fig.box((s * 18 - 1.6, -26.2, s * 18 + 1.6, -23), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((s * 18, -24.6), 0.55, STEEL, z=1.2)
    return fig.render(BASE_W, BASE_H, BASE_O)


def main():
    b, s = bar(), base()
    write_png(SPR + 'rocker_bar.png', BAR_W, BAR_H, b)
    write_png(SPR + 'rocker_base.png', BASE_W, BASE_H, s)
    print('wrote rocker_bar.png, rocker_base.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, s], 8)
        write_png(sys.argv[1] + '/rocker_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
