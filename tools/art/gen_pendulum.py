"""Wrecking pendulum parts: an iron wrecking ball and the brass pivot hub it
hangs from. The chain is drawn by the game.

    python3 tools/art/gen_pendulum.py [preview_dir]

Writes assets/sprites/wrecking_ball.png (26x28: the ball, centre at (13, 15),
with its shackle on top at (13, 3)) and pendulum_hub.png (16x14, the
bearing's centre at (8, 7)).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = [(41, 38, 31), (53, 60, 66), (58, 73, 74), (80, 92, 96), (95, 124, 131), (112, 144, 146)]


def ball():
    fig = Figure()
    fig.sphere((0, 0), 10.5, IRON, z=1)
    fig.ellipsoid((0, 0), (10.6, 2.2), BRONZE, z=1.2)          # brass band round the waist
    for a in range(-60, 61, 30):                                   # rivets on the band
        x = math.sin(math.radians(a)) * 9.2
        fig.sphere((x, 0), 0.7, STEEL, z=1.3)
    for (x, y) in ((-4, -5.5), (3.5, -6.5), (5.5, 4.5), (-5.5, 5)):  # rivets on the iron
        fig.sphere((x, y), 0.6, STEEL, z=1.25)
    fig.ellipsoid((0, -10.5), (3.2, 1.6), BRONZE, z=1.4)       # cap plate
    fig.capsule((-2.2, -11), (-2.2, -13.5), 0.8, STEEL, z=1.5)   # shackle
    fig.capsule((2.2, -11), (2.2, -13.5), 0.8, STEEL, z=1.5)
    fig.capsule((-2.2, -13.5), (2.2, -13.5), 0.8, STEEL, z=1.5)
    return fig.render(26, 28, (13, 15), extra=['353c42', '3a494a', '505c60', '5f7c83', '709092'])


def hub():
    fig = Figure()
    fig.ellipsoid((0, 0), (6.5, 5.5), BRONZE, z=1)
    fig.gear((0, 0), 4.2, 8, 10, STEEL, z=1.1)
    fig.sphere((0, 0), 1.6, BRONZE, z=1.2)
    fig.disc((0, 0), 0.6, DARK, z=1.3)
    return fig.render(16, 14, (8, 7))


def main():
    b, h = ball(), hub()
    write_png(SPR + 'wrecking_ball.png', 26, 28, b)
    write_png(SPR + 'pendulum_hub.png', 16, 14, h)
    print('wrote wrecking_ball.png, pendulum_hub.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, h], 8)
        write_png(sys.argv[1] + '/pendulum_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
