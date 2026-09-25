"""Tesla coil: a brass plinth with an ingot hopper on its side, a copper
coil wound round a ceramic column, and a glass-caged sphere electrode on
top that glows with the charge.

    python3 tools/art/gen_tesla.py [preview_dir]

Writes assets/sprites/tesla.png: 4 frames of 40x70, feet at the bottom
centre (20, 69); the electrode's centre is at (0, -58) from the feet; the
hopper's mouth spans x -19..-9 at y -30. Frames: the coil's glow crawls
upward and the sphere pulses.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 40, 70, (20, 69)
N = 4
CERAMIC = [(41, 38, 31), (96, 92, 84), (150, 144, 130), (196, 190, 172), (232, 226, 206)]


def build(i):
    fig = Figure()
    # plinth on feet
    for x in (-10, 10):
        fig.ellipsoid((x, -1.5), (3.5, 1.5), BRONZE, z=0)
    fig.box((-11, -12, 11, -3), BRONZE, z=1, bevel=2.0)
    fig.box((-8, -10, 8, -5), DARK, z=1.1, bevel=0.8)
    fig.gear((0, -7.5), 2.4, 8, i * 20, STEEL, z=1.2)
    # ingot hopper on the left, piped in
    fig.poly([(-19, -30), (-9, -30), (-11, -22), (-17, -22)], STEEL, z=2, shade=0.7)
    fig.poly([(-18, -29.5), (-10, -29.5), (-12, -23), (-16, -23)], DARK, z=2.05, shade=0.3)
    fig.capsule((-19.5, -30), (-8.5, -30), 0.8, BRONZE, z=2.1)
    fig.capsule((-14, -22), (-6, -16), 1.2, STEEL, z=1.9)
    # ceramic column wound with copper
    fig.capsule((0, -13), (0, -48), 3.6, CERAMIC, z=2)
    for k in range(9):
        y = -16 - k * 3.6
        glow = ((k - i * 2) % 8) < 2      # a crawl of light up the winding
        fig.ellipsoid((0, y), (5.2, 1.2), COPPER if not glow else [(255, 214, 160)] * 3, z=2.2 + k * 0.01,
                      emissive=glow)
    # the electrode: a steel sphere in a brass cage, lit from inside
    fig.capsule((0, -48), (0, -52), 1.2, BRONZE, z=2.4)
    pulse = 0.8 + 0.25 * math.sin(i / N * math.tau)
    fig.sphere((0, -58), 6.0, STEEL, z=2.5)
    fig.sphere((0, -58), 4.0 * pulse, GLOW, z=2.6, emissive=True)
    for a in range(0, 180, 45):
        t = math.radians(a)
        fig.capsule((math.cos(t) * -6.4, -58 + math.sin(t) * -6.4), (math.cos(t) * 6.4, -58 + math.sin(t) * 6.4),
                    0.45, BRONZE, z=2.7)
    fig.sphere((-2, -60.5), 0.9, [(235, 250, 250)] * 2, z=2.8, emissive=True)
    return fig.render(FW, FH, O, extra=['605c54', '96907f', 'c4bea8', 'e8e2ce', 'ffd6a0'] + COPPER_EXTRA)


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'tesla.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote tesla.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 5)
        write_png(sys.argv[1] + '/tesla_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
