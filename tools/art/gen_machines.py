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


MW, MH, MO = 24, 28, (12, 15)   # rig v2 frame; figure (0,0) is 1px under the centre, as v1


def miner2(i, n=8):
    """Drill rig v2: flywheel + crank driving a piston, gauge needle sweeping,
    funnel on top that the ore comes out of."""
    a = i / n * 2 * math.pi
    fig = Figure()
    fig.box((-10, 8, 10, 12), DARK, z=0, bevel=1.0)                        # flange
    for x in (-8, -3, 3, 8):
        fig.sphere((x, 10), 0.7, STEEL, z=0.2)                             # bolts
    fig.box((-8, -4, 8, 8.5), BRONZE, z=1, bevel=1.8)                      # housing
    fig.box((-8, -5.5, 8, -3), STEEL, z=1.1, bevel=0.8)                    # top band
    # funnel on top, its lip bobbing with the pump
    bob = 0.8 * math.sin(a)
    fig.capsule((0, -5), (0, -10 + bob), 1.8, STEEL, z=2)
    fig.ellipsoid((0, -11 + bob), (3.4, 1.1), BRONZE, z=2.1)
    fig.ellipsoid((0, -11.3 + bob), (2.2, 0.6), DARK, z=2.2, grit=0.0)
    # flywheel with a crank pin, driving a piston on the right
    fw = (-3.5, 2.5)
    fig.disc(fw, 5.0, DARK, z=2.8)
    fig.gear(fw, 4.4, 9, math.degrees(a), STEEL, z=3)
    pin = (fw[0] + 2.6 * math.cos(a), fw[1] + 2.6 * math.sin(a))
    fig.sphere(pin, 0.9, BRONZE, z=3.3)
    head = (5.5, -1.5 + 2.2 * math.sin(a))                                   # crosshead
    fig.capsule((5.5, -6), (5.5, 7), 0.9, DARK, z=2.9)                        # cylinder slot
    fig.capsule(pin, head, 0.6, BRONZE, z=3.4)                                # connecting rod
    fig.box((4.2, head[1] - 1.2, 6.8, head[1] + 1.2), STEEL, z=3.5, bevel=0.5)
    # pressure gauge, needle sweeping up as the stroke builds
    g = (4.8, 5.3)
    fig.disc(g, 2.2, STEEL, z=3.6)
    fig.disc(g, 1.6, [(205, 227, 220)] * 2, z=3.7)
    t = math.radians(200 + 140 * (i / (n - 1)))
    fig.capsule(g, (g[0] + 1.4 * math.cos(t), g[1] + 1.4 * math.sin(t)), 0.3, DARK, z=3.8)
    fig.sphere((-3.5, -3.2), 0.9, GLOW, z=3.9, emissive=True)                 # status lamp
    return fig.render(MW, MH, MO)


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
    rig = [miner2(i) for i in range(8)]
    write_png(SPR + 'miner_rig.png', MW * 8, MH, [sum((f[y] for f in rig), []) for y in range(MH)])
    e = electrode(); write_png(SPR + 'electrode.png', 16, 20, e)
    print('wrote miner.png, electrode.png')
    if len(sys.argv) > 1:
        big = side_by_side(rig, 10)
        write_png(sys.argv[1] + '/rig_preview.png', len(big[0]), len(big), big)
        big = side_by_side(frames + [e], 10)
        write_png(sys.argv[1] + '/machines_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
