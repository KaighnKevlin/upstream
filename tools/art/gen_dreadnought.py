"""The Dreadnought (boss): a flying fortress. A vast brass-ribbed envelope
with twin stern propellers and fins, slung over a long armoured gondola
with gun ports, lit windows, a bomb bay and a hangar door underneath.

    python3 tools/art/gen_dreadnought.py [preview_dir]

Writes assets/sprites/dreadnought.png: 4 frames of 200x96, facing right,
the envelope centre at (100, 34). Propellers turn across the frames. The
bomb bay is at (+10, +50) from the centre, the hangar door at (-30, +50).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 200, 96, (100, 34)
CANVAS = [(41, 38, 31), (80, 70, 62), (118, 104, 88), (150, 136, 112), (180, 168, 140)]
HULL = [(41, 38, 31), (53, 60, 66), (66, 80, 86), (92, 110, 116), (120, 140, 144)]


def prop(fig, c, ang, z):
    fig.sphere(c, 2.2, STEEL, z=z)
    for k in (0, 120, 240):
        a = math.radians(ang + k)
        fig.ellipsoid((c[0], c[1] + math.sin(a) * 7), (1.4, abs(math.cos(a)) * 2 + 5), STEEL, z=z + 0.1)


def build(i):
    fig = Figure()
    ang = i * 40
    # fins
    fig.poly([(-80, -4), (-96, -24), (-86, -3)], CANVAS, z=0.4, shade=0.8)
    fig.poly([(-80, 4), (-96, 22), (-86, 3)], CANVAS, z=0.4, shade=0.6)
    fig.poly([(-78, 0), (-98, -2), (-98, 2)], BRONZE, z=0.45, shade=0.7)
    # the envelope
    fig.ellipsoid((0, 0), (86, 28), CANVAS, z=1, grit=0.03)
    for x in range(-70, 75, 14):
        h = 28 * math.sqrt(max(0.0, 1 - (x / 86) ** 2))
        fig.capsule((x, -h + 1.5), (x, h - 1.5), 0.9, BRONZE, z=1.1)
    fig.capsule((-84, 0), (84, 0), 0.7, BRONZE, z=1.05)
    fig.capsule((-80, -12), (80, -12), 0.5, DARK, z=1.02)
    # twin stern propellers on outriggers
    for y in (-16, 16):
        fig.capsule((-70, y * 0.7), (-88, y), 1.2, DARK, z=1.2)
        prop(fig, (-90, y), ang + (60 if y > 0 else 0), 1.3)
    # rigging
    for x in (-50, -20, 20, 50):
        fig.capsule((x, 24), (x * 0.9, 38), 0.5, DARK, z=0.9)
    # the gondola: an armoured hull with gun ports and windows
    fig.box((-62, 36, 62, 54), HULL, z=2, bevel=3.0, grit=0.05)
    fig.box((-64, 52, 64, 56), BRONZE, z=2.1, bevel=1.0)
    fig.box((-62, 35, 62, 38), BRONZE, z=2.1, bevel=0.8)
    for x in range(-52, 56, 12):
        fig.box((x, 40, x + 5, 44), DARK, z=2.2, bevel=0.5)
        fig.box((x + 0.6, 40.6, x + 4.4, 43.4), GLOW, z=2.3, bevel=0.3)
    for x in (-40, 0, 40):                                  # gun ports
        fig.disc((x + 6, 48), 2.4, DARK, z=2.3)
        fig.capsule((x + 6, 48), (x + 12, 49), 1.2, STEEL, z=2.35)
    fig.box((6, 55, 14, 58), DARK, z=2.4, bevel=0.5)       # bomb bay
    fig.box((-40, 55, -20, 58), BRONZE, z=2.4, bevel=0.5)  # hangar door
    fig.poly([(62, 38), (74, 44), (62, 52)], HULL, z=2.05, shade=0.7)   # prow
    fig.sphere((68, 45), 1.4, GLOW, z=2.5, emissive=True)
    return fig.render(FW, FH, O, extra=['50463e', '76685a', '968870', 'b4a88c', '353c42', '42505a', '5c6e74', '788c90'])


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'dreadnought.png', FW * 4, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote dreadnought.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames[:2], 3)
        write_png(sys.argv[1] + '/dreadnought_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
