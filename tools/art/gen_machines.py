"""Production machines: the miner drill rig and the arc-smelter electrode.

    python3 tools/art/gen_machines.py [preview_dir]

Writes assets/sprites/miner.png (4 frames of 20x22, tile centre at (10, 12);
the nozzle pumps) and electrode.png (16x20, faces right: the glowing tip is on
the right edge at y=10; mirror it for the left side of the beam).
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side


def miner(i):
    pump = (0, 1, 2, 1)[i]
    fig = Figure()
    fig.box((-8, 6, 8, 9.5), DARK, z=0, bevel=1.0)                       # flange
    for x in (-6.5, 6.5):
        fig.sphere((x, 7.8), 0.7, STEEL, z=0.2)                          # bolts
    fig.box((-6, -3, 6, 7), BRONZE, z=1, bevel=1.6)                      # housing
    fig.ellipsoid((0, -3), (6, 2.8), BRONZE, z=1.2)                      # domed cap
    fig.capsule((0, -4), (0, -9 + pump), 1.6, STEEL, z=2)                # nozzle
    fig.ellipsoid((0, -9.5 + pump), (2.5, 0.9), STEEL, z=2.1)            # nozzle lip
    fig.capsule((6.6, -1), (6.6, 5 - pump), 0.8, STEEL, z=2.2)           # side piston
    fig.disc((-2.4, 2.4), 3.4, DARK, z=2.9)
    fig.gear((-2.4, 2.4), 2.9, 7, i * 22, STEEL, z=3)                    # turning gear
    fig.disc((3.2, 1.8), 2.1, DARK, z=3)
    fig.sphere((3.2, 1.8), 1.4, GLOW, z=3.1, emissive=True)              # pressure window
    return fig.render(20, 22, (10, 12))


def electrode():
    fig = Figure()
    fig.box((-7, -3.5, 0, 3.5), BRONZE, z=0, bevel=1.4)                  # housing
    for x in (-5.5, -3.5, -1.5):
        fig.ellipsoid((x, 0), (0.8, 4.3), BRONZE, z=0.5, grit=0.02)      # cooling fins
    fig.ellipsoid((1.5, 0), (2.2, 3.4), STEEL, z=1)                      # collar
    fig.capsule((1.5, 0), (5, 0), 1.2, STEEL, z=1.2)                     # electrode rod
    fig.sphere((5.5, 0), 1.9, GLOW, z=1.5, emissive=True)                # glowing tip
    fig.capsule((-4, 3.5), (-4, 8), 0.8, DARK, z=-1)                     # mounting strut
    fig.box((-7, 7.5, -1, 9.5), DARK, z=-0.5, bevel=0.6)                 # clamp
    return fig.render(16, 20, (8, 10))


def main():
    frames = [miner(i) for i in range(4)]
    rows = [sum((f[y] for f in frames), []) for y in range(22)]
    write_png(SPR + 'miner.png', 80, 22, rows)
    e = electrode(); write_png(SPR + 'electrode.png', 16, 20, e)
    print('wrote miner.png, electrode.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames + [e], 10)
        write_png(sys.argv[1] + '/machines_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
