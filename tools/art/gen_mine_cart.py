"""Mine cart: a track that tiles along any length (two steel rails on
timber sleepers), the stop post at each end, the loading hopper's side
plates, the riveted iron tub with a brass rim, and a spoked wheel the code
turns as the cart rolls.

    python3 tools/art/gen_mine_cart.py [preview_dir]

Writes (the track and cart are drawn along the track's direction, rotated
in code; stops and hopper upright):
- mine_track.png   10x10 tile, repeats along x (a sleeper every 10 px):
  the track line on row 1, rails on rows 3 and 6.
- mine_stop.png    8x17, the post's foot on the track line at (4, 12): a
  steel post up to y -8 with a timber buffer.
- mine_hopper.png  28x36, the node origin at (14, 43): brass side plates
  from (+-10, -41) down to (+-5, -22), on steel stays; open between.
- mine_cart.png    26x16, the track point under the cart at (13, 13): the
  tub x -11..11, y -12..0, axle boxes at (+-6, 1).
- mine_wheel.png   7x7, the axle at (3, 3).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [BRONZE[0], BRONZE[1], BRONZE[1], BRONZE[2], BRONZE[3]]
IRON = [STEEL[0], STEEL[1], STEEL[2], STEEL[3], STEEL[4], STEEL[5]]


def track():
    fig = Figure()
    fig.box((3, 0.5, 7, 8.5), WOOD, z=0, bevel=0.8, grit=0.08)          # the sleeper
    fig.capsule((4, 2), (4, 7), 0.3, [BRONZE[1]] * 2, z=0.05)           # its grain
    for y in (2, 5):
        fig.box((-4, y - 0.7, 14, y + 0.9), STEEL, z=1, bevel=0.5, grit=0.03)
    for y in (2, 5):
        fig.sphere((5, y + 0.1), 0.45, DARK, z=1.1)                     # the spikes
    return fig.render(10, 10, (0, 1), outline=False)


def stop():
    fig = Figure()
    fig.box((-1.5, -8, 1.5, 5), STEEL, z=0, bevel=0.6)
    fig.box((-3, -9, 3, -6), WOOD, z=0.1, bevel=0.7)                     # a timber buffer
    fig.sphere((0, -7.5), 0.6, BRONZE, z=0.2)
    fig.box((-3.5, 3.5, 3.5, 5.5), STEEL, z=0.1, bevel=0.5)              # a foot plate
    return fig.render(8, 17, (4, 12))


def hopper():
    fig = Figure()
    for s in (-1, 1):
        # a steel stay down to the stop, and a brass side plate
        fig.capsule((s * 6, -23), (s * 3, -8), 0.6, STEEL, z=0)
        fig.poly([(s * 9, -42), (s * 12, -42), (s * 7, -22), (s * 4.5, -22)], BRONZE, z=1, shade=0.62 if s < 0 else 0.45)
        fig.sphere((s * 9.6, -36), 0.6, STEEL, z=1.1)
        fig.sphere((s * 7, -27), 0.6, STEEL, z=1.1)
    fig.box((-13, -43, -8, -41), BRONZE, z=1.2, bevel=0.5)
    fig.box((8, -43, 13, -41), BRONZE, z=1.2, bevel=0.5)
    return fig.render(28, 36, (14, 43))


def cart():
    fig = Figure()
    # the axle boxes
    for x in (-6, 6):
        fig.box((x - 2, -2, x + 2, 1.5), DARK, z=0, bevel=0.5, grit=0.02)
    # the tub: tapered iron, a brass rim, riveted bands
    fig.poly([(-11.5, -12), (11.5, -12), (10, 0), (-10, 0)], IRON, z=1, shade=0.5)
    fig.poly([(-11.5, -12), (11.5, -12), (11.3, -10.4), (-11.3, -10.4)], IRON, z=1.05, shade=0.85)
    fig.box((-12, -13, 12, -11), BRONZE, z=1.2, bevel=0.6)
    for x in (-4.5, 4.5):
        fig.box((x - 0.8, -11, x + 0.8, 0), IRON, z=1.1, bevel=0.4)
        for y in (-8, -3):
            fig.sphere((x, y), 0.55, BRONZE, z=1.2)
    fig.poly([(-10, -1.4), (10, -1.4), (10, 0), (-10, 0)], DARK, z=1.15, shade=0.4, grit=0.0)
    return fig.render(26, 16, (13, 13))


def wheel():
    fig = Figure()
    fig.disc((0, 0), 3.2, STEEL, z=0)
    fig.disc((0, 0), 2.2, DARK, z=0.1)
    fig.capsule((-2.2, 0), (2.2, 0), 0.45, STEEL, z=0.2)                 # one spoke across
    fig.sphere((0, 0), 0.9, BRONZE, z=0.3)
    return fig.render(7, 7, (3.5, 3.5))


def main():
    parts = {'mine_track': track(), 'mine_stop': stop(), 'mine_hopper': hopper(), 'mine_cart': cart(), 'mine_wheel': wheel()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        t = parts['mine_track']
        tt = [sum((row for _ in range(5)), []) for row in t]
        big = side_by_side([tt] + [parts[n] for n in ('mine_stop', 'mine_hopper', 'mine_cart', 'mine_wheel')], 6)
        write_png(sys.argv[1] + '/mine_cart_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
