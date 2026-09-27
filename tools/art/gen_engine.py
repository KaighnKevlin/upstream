"""Steam engine: a horizontal brass boiler on iron feet, a firebox door
with a grate at one end, a chimney, a fuel funnel on top, and a big spoked
flywheel driven by a piston rod.

    python3 tools/art/gen_engine.py [preview_dir]

Writes assets/sprites/engine.png: 4 frames of 56x48, feet at (28, 47):
the flywheel turns and the piston strokes over the frames. The firebox
mouth is at about (-17, -12) from the feet, the chimney top (+9, -46), the
funnel mouth (-4, -40), the flywheel hub (+17, -16).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 56, 48, (28, 47)
FIRE = [(90, 20, 10), (180, 60, 20), (240, 130, 40), (255, 210, 110)]


def build(i):
    fig = Figure()
    a = i / 4 * math.tau
    for x in (-18, -4, 8):                                         # iron feet
        fig.box((x - 3, -6, x + 3, 0), DARK, z=0, bevel=0.6)
    fig.capsule((-20, -16), (6, -16), 9.0, BRONZE, z=1, grit=0.06)   # boiler
    for x in (-14, -5, 3):
        fig.capsule((x, -25), (x, -7), 0.7, STEEL, z=1.1)           # bands
    fig.box((-25, -18, -15, -6), DARK, z=1.2, bevel=0.8)           # firebox
    fig.box((-23, -15, -17, -9), FIRE, z=1.3, bevel=0.4)          # the glow
    for x in (-22, -20, -18):
        fig.capsule((x, -15), (x, -9), 0.35, DARK, z=1.35)          # grate
    fig.box((6, -45, 12, -24), DARK, z=0.9, bevel=0.5)             # chimney
    fig.box((5, -47, 13, -44), STEEL, z=0.95, bevel=0.4)
    fig.poly([(-10, -40), (2, -40), (-1, -26), (-7, -26)], BRONZE, z=1.4)   # fuel funnel
    fig.disc((-6.5, -26), 3.0, DARK, z=1.5)
    fig.disc((-4, -22), 2.4, DARK, z=1.6)                          # pressure gauge
    fig.disc((-4, -22), 1.7, [(225, 215, 185)] * 2, z=1.65)
    # flywheel and piston
    hub = (17, -16)
    fig.disc(hub, 11, DARK, z=2)
    fig.disc(hub, 9.5, STEEL, z=2.05)
    fig.disc(hub, 7.8, DARK, z=2.1)
    for k in range(6):
        sp = a + k * math.tau / 6
        fig.capsule(hub, (hub[0] + math.cos(sp) * 8.2, hub[1] + math.sin(sp) * 8.2), 0.8, BRONZE, z=2.2)
    fig.sphere(hub, 1.8, BRONZE, z=2.3)
    crank = (hub[0] + math.cos(a) * 5, hub[1] + math.sin(a) * 5)
    cyl = (6, -16)
    fig.capsule(cyl, crank, 1.0, STEEL, z=2.4)
    fig.sphere(crank, 1.3, BRONZE, z=2.45)
    return fig.render(W, H, O, extra=['5a140a', 'b43c14', 'f08228', 'ffd26e', 'e1d7b9'])


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'engine.png', W * 4, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote engine.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/engine_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
