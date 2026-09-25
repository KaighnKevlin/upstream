"""Troop airship: a canvas envelope ribbed with brass hoops, a propeller
turning at the stern, fins, and a riveted gondola slung underneath with
lit windows and a winch drum for lowering troops.

    python3 tools/art/gen_airship.py [preview_dir]

Writes assets/sprites/airship.png: 4 frames of 100x64, facing right, the
envelope centre at (50, 22); the winch (where the rope pays out) is at
(+4, +30) from that centre. The propeller turns across the frames.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 100, 64, (50, 22)
CANVAS = [(41, 38, 31), (96, 84, 70), (140, 124, 100), (178, 162, 132), (208, 196, 166)]
EXTRA = ['605446', '8c7c64', 'b2a284', 'd0c4a6']


def build(i):
    fig = Figure()
    # stern fins
    fig.poly([(-36, -2), (-46, -14), (-40, -1)], CANVAS, z=0.5, shade=0.8)
    fig.poly([(-36, 2), (-46, 14), (-40, 1)], CANVAS, z=0.5, shade=0.6)
    # the envelope
    fig.ellipsoid((0, 0), (40, 15), CANVAS, z=1, grit=0.03)
    for x in (-26, -13, 0, 13, 26):
        h = 15 * math.sqrt(max(0.0, 1 - (x / 40) ** 2))
        fig.capsule((x, -h + 1), (x, h - 1), 0.7, BRONZE, z=1.1)
    fig.capsule((-38, 0), (38, 0), 0.5, BRONZE, z=1.05)
    # propeller at the stern
    fig.sphere((-42, 0), 1.6, STEEL, z=1.2)
    ang = i * 45
    for k in (0, 180):
        a = math.radians(ang + k)
        fig.ellipsoid((-44, 0 + math.sin(a) * 5), (1.2, abs(math.cos(a)) * 1.5 + 3.5), STEEL, z=1.3)
    # rigging and gondola
    for (x0, x1) in ((-16, -10), (16, 12)):
        fig.capsule((x0, 12), (x1, 22), 0.4, DARK, z=0.9)
    fig.box((-14, 21, 16, 31), BRONZE, z=2, bevel=2.0, grit=0.05)
    fig.box((-15, 29, 17, 32), STEEL, z=2.1, bevel=0.8)
    for x in (-8, -1, 6):
        fig.box((x, 23, x + 4, 27), DARK, z=2.2, bevel=0.5)
        fig.box((x + 0.5, 23.5, x + 3.5, 26.5), GLOW, z=2.3, bevel=0.4)
    # winch drum under the gondola
    fig.disc((4, 33), 2.4, STEEL, z=2.4)
    fig.disc((4, 33), 1.0, DARK, z=2.5)
    return fig.render(FW, FH, O, extra=EXTRA)


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'airship.png', FW * 4, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote airship.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 4)
        write_png(sys.argv[1] + '/airship_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
