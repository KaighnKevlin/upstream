"""Clockwork sapper: a brass drill-mole. It burrows under your works toward
the dome and bursts up beneath it.

    python3 tools/art/gen_sapper.py [preview_dir]

Writes assets/sprites/sapper.png: 6 frames of 44x30, facing right, body
centre at (20, 13). The drill bit spins across the frames and the digging
claws paddle. The game rotates the sprite to dive and rise.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 44, 30, (20, 13)
N = 6


def build(i):
    ph = i / N * math.tau
    fig = Figure()
    # rear: exhaust stack and a tail of segmented plates
    fig.capsule((-13, -3), (-16, -8), 1.1, DARK, z=0)
    fig.ellipsoid((-16.3, -8.6), (1.8, 0.8), BRONZE, z=0.1)
    for k in range(3):
        fig.ellipsoid((-11 + k * 2.2, 1), (3.2 - k * 0.3, 4.6 - k * 0.4), STEEL if k % 2 else BRONZE, z=0.5 + k * 0.05)
    # far digging claw
    a = math.sin(ph + math.pi) * 0.8
    fig.capsule((3, 4), (3 + math.cos(a + 1.2) * 6, 4 + math.sin(a + 1.2) * 6), 1.1, DARK, z=0.8)
    # body: a riveted brass barrel with a steel belly band
    fig.ellipsoid((-1, 0), (12, 7), BRONZE, z=1, grit=0.08)
    fig.ellipsoid((-1, 3.6), (10, 2.6), STEEL, z=1.1)
    for x in (-8, -3, 2, 7):
        fig.sphere((x, -4.8 + abs(x) * 0.08), 0.6, STEEL, z=1.2)
    # clockwork porthole with a turning gear
    fig.disc((-3, -0.5), 3.2, DARK, z=1.3)
    fig.gear((-3, -0.5), 2.6, 7, i * 360 / N / 2, BRONZE, z=1.4)
    # head collar and eye
    fig.ellipsoid((9, -0.5), (3.2, 5.8), STEEL, z=1.5)
    fig.sphere((8.6, -3.2), 1.2, GLOW, z=1.6, emissive=True)
    # the drill: a steel cone with spiral flutes that travel with the frame
    fig.poly([(11, -5), (23, 0), (11, 5)], STEEL, z=2, shade=0.75)
    for k in range(4):
        u = ((k / 4 + i / N / 4) % 1.0)
        x = 11.5 + u * 10
        h = 5 * (1 - u / 1.05)
        fig.capsule((x, -h), (x + 1.8, h * 0.6), 0.45, DARK, z=2.1)
    fig.sphere((23, 0), 0.8, [(235, 250, 250)] * 2, z=2.2, emissive=True)
    # near digging claw, paddling
    a = math.sin(ph) * 0.8
    tip = (4 + math.cos(a + 1.1) * 7, 5 + math.sin(a + 1.1) * 6)
    fig.capsule((3, 5), tip, 1.3, BRONZE, z=2.5)
    for d in (-0.5, 0.5):
        fig.capsule(tip, (tip[0] + math.cos(a + 1.1 + d) * 2.5, tip[1] + math.sin(a + 1.1 + d) * 2.5), 0.5, STEEL, z=2.6)
    return fig.render(FW, FH, O)


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'sapper.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote sapper.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/sapper_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/sapper.gif', frames * 4, [6] * (N * 4), 6)


if __name__ == '__main__':
    main()
