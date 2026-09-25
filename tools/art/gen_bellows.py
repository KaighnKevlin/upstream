"""Clockwork bellows fan: a brass housing with a crank, a leather bellows
pumping behind a steel nozzle. Blows a stream of air that carries ore.

    python3 tools/art/gen_bellows.py [preview_dir]

Writes assets/sprites/bellows.png: 4 frames of 36x24, nozzle pointing
right, pivot (the housing's centre) at (12, 12); the nozzle mouth is at
about (+22, 0) from it. The game rotates the sprite to the aim.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 36, 24, (12, 12)
N = 4
LEATHER = [(41, 38, 31), (60, 40, 34), (84, 54, 42), (110, 72, 52), (138, 94, 66), (160, 116, 84)]


def build(i):
    ph = i / N * 2 * math.pi
    squeeze = 0.5 + 0.5 * math.cos(ph)       # 1 open .. 0 squeezed
    fig = Figure()
    # housing: a squat brass drum with a crank wheel on its face
    fig.ellipsoid((-3, 0), (6.5, 7.5), BRONZE, z=2)
    fig.disc((-3, 0), 4.2, DARK, z=2.1)
    fig.gear((-3, 0), 3.8, 8, i * 22.5, STEEL, z=2.2)
    fig.sphere((-3, 0), 1.2, BRONZE, z=2.3)
    crank = (-3 + math.cos(ph) * 3.0, math.sin(ph) * 3.0)
    fig.capsule((-3, 0), crank, 0.6, BRONZE, z=2.4)
    fig.sphere(crank, 0.9, STEEL, z=2.5)
    # bellows: leather pleats between the housing and the nozzle plate
    length = 4 + 5 * squeeze
    x0 = 3
    pleats = 3
    for k in range(pleats + 1):
        x = x0 + length * k / pleats
        h = 5.5 if k % 2 == 0 else 4.2 + 1.3 * squeeze
        fig.capsule((x, -h), (x, h), 0.9, LEATHER, z=1.5 + k * 0.01)
    fig.poly([(x0, -5.5), (x0 + length, -5.5), (x0 + length, 5.5), (x0, 5.5)], LEATHER, z=1.4, shade=0.5)
    # nozzle plate and cone
    px = x0 + length + 1
    fig.capsule((px, -5.8), (px, 5.8), 1.1, BRONZE, z=3)
    fig.poly([(px + 0.5, -4.2), (px + 9, -1.6), (px + 9, 1.6), (px + 0.5, 4.2)], STEEL, z=3.1, shade=0.7)
    fig.capsule((px + 9, -1.8), (px + 9, 1.8), 0.7, DARK, z=3.2)   # mouth
    for y in (-3.2, 3.2):
        fig.sphere((px + 0.6, y), 0.5, STEEL, z=3.3)               # plate rivets
    return fig.render(FW, FH, O, extra=['2a261f', '3c2822', '54362a', '6e4834', '8a5e42', 'a07454'])


def main():
    frames = [build(i) for i in range(N)]
    write_png(SPR + 'bellows.png', FW * N, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote bellows.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/bellows_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
