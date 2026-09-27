"""Roller: a clockwork juggernaut that is nothing but a ball. Riveted iron
plates, a bronze drive band around it (so you can see it spin), and a red
lamp-slit peering out of the band.

    python3 tools/art/gen_roller.py [preview_dir]

Writes assets/sprites/roller.png: 1 frame of 30x30, centred; the body
rotates it as it rolls.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 30, 30, (15, 15)
EYE = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]


def build():
    fig = Figure()
    fig.sphere((0, 0), 13.5, STEEL, z=0, grit=0.09)
    # plate seams
    for a in (35, 100, 160, 215, 280, 330):
        r = math.radians(a)
        fig.capsule((math.cos(r) * 5, math.sin(r) * 5), (math.cos(r) * 12.5, math.sin(r) * 12.5), 0.35, DARK, z=0.2)
    # the drive band, straight across, with teeth
    fig.box((-13.5, -3.2, 13.5, 3.2), BRONZE, z=0.5, bevel=1.0, grit=0.05)
    for x in range(-11, 12, 4):
        fig.box((x - 0.7, -4.2, x + 0.7, -3.0), BRONZE, z=0.55, bevel=0.2)
        fig.box((x - 0.7, 3.0, x + 0.7, 4.2), BRONZE, z=0.55, bevel=0.2)
    # the eye slit
    fig.box((2.5, -1.3, 9.5, 1.3), DARK, z=0.7, bevel=0.3)
    fig.ellipsoid((6, 0), (3.2, 0.9), EYE, z=0.8, emissive=True)
    # rivets
    for a in range(0, 360, 30):
        r = math.radians(a + 15)
        fig.sphere((math.cos(r) * 10.8, math.sin(r) * 10.8), 0.6, BRONZE, z=0.3)
    return fig.render(W, H, O, extra=['460e0c', 'a01e18', 'e64632', 'ffa082'])


def main():
    f = build()
    write_png(SPR + 'roller.png', W, H, f)
    print('wrote roller.png')
    if len(sys.argv) > 1:
        big = side_by_side([f], 8)
        write_png(sys.argv[1] + '/roller_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
