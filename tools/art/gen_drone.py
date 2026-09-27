"""Porter drone and its dock.

    python3 tools/art/gen_drone.py [preview_dir]

drone.png: 2 frames of 22x16, centred at (11, 7): a round brass body with a
cyan lamp, a whirring rotor on top (two blur frames), and a little claw
hanging below (its tip at about (0, +7)).
dock.png: 40x26, feet at (20, 25): a riveted landing pad on a squat brass
housing with a beacon lamp and a gauge.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

LAMP = [(30, 90, 110), (60, 170, 200), (130, 225, 240), (220, 250, 255)]


def drone(i):
    fig = Figure()
    fig.capsule((0, -3.5), (0, -1.5), 0.6, DARK, z=0)
    blade = 9.5 if i == 0 else 6.0
    fig.ellipsoid((0, -4.3), (blade, 0.9), STEEL, z=0.2, grit=0.02)       # rotor blur
    fig.sphere((0, -4.5), 1.0, BRONZE, z=0.3)
    fig.ellipsoid((0, 1.0), (5.5, 3.6), BRONZE, z=1, grit=0.05)
    fig.box((-5.2, 1.2, 5.2, 2.2), DARK, z=1.1, bevel=0.3)
    fig.sphere((2.8, 0.2), 1.2, LAMP, z=1.2, emissive=True)
    for s in (-1, 1):                                                   # claw
        fig.capsule((s * 1.2, 4.0), (s * 2.4, 6.2), 0.5, STEEL, z=0.9)
        fig.capsule((s * 2.4, 6.2), (s * 1.0, 7.4), 0.45, STEEL, z=0.9)
    return fig.render(22, 16, (11, 7), extra=['1e5a6e', '3caac8', '82e1f0', 'dcfaff'])


def dock():
    fig = Figure()
    fig.box((-17, -7, 17, 0), DARK, z=0, bevel=1.0)                     # housing
    fig.box((-15, -6, 15, -1), BRONZE, z=0.1, bevel=0.8, grit=0.05)
    fig.box((-19, -10, 19, -7), STEEL, z=0.3, bevel=0.6)                # landing pad
    for x in range(-16, 17, 4):
        fig.sphere((x, -8.5), 0.5, BRONZE, z=0.4)
    fig.disc((-9, -3.5), 2.2, DARK, z=0.5)                              # gauge
    fig.disc((-9, -3.5), 1.6, [(225, 215, 185)] * 2, z=0.55)
    fig.capsule((12, -10), (12, -18), 0.8, DARK, z=0.2)                 # beacon mast
    fig.sphere((12, -19.5), 1.8, LAMP, z=0.6, emissive=True)
    fig.gear((3, -3.5), 2.4, 8, 10, STEEL, z=0.5)
    return fig.render(40, 26, (20, 25), extra=['1e5a6e', '3caac8', '82e1f0', 'dcfaff', 'e1d7b9'])


def main():
    frames = [drone(0), drone(1)]
    write_png(SPR + 'drone.png', 44, 16, [sum((f[y] for f in frames), []) for y in range(16)])
    d = dock()
    write_png(SPR + 'dock.png', 40, 26, d)
    print('wrote drone.png, dock.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames + [d], 8)
        write_png(sys.argv[1] + '/drone_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
