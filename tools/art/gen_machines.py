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
    fig.box((-8, -5.5, 8, -3), DARK, z=1.1, bevel=0.8)                     # top band
    # funnel on top, its lip bobbing with the pump
    bob = 0.8 * math.sin(a)
    fig.capsule((0, -5), (0, -10 + bob), 1.8, BRONZE, z=2)
    fig.ellipsoid((0, -11 + bob), (3.4, 1.1), STEEL, z=2.1)
    fig.ellipsoid((0, -11.3 + bob), (2.2, 0.6), DARK, z=2.2, grit=0.0)
    # flywheel with a crank pin, driving a piston on the right
    fw = (-3.5, 2.5)
    fig.disc(fw, 5.0, DARK, z=2.8)
    fig.gear(fw, 4.4, 9, math.degrees(a), STEEL, z=3, hub_mat=BRONZE)
    pin = (fw[0] + 2.6 * math.cos(a), fw[1] + 2.6 * math.sin(a))
    fig.sphere(pin, 0.9, BRONZE, z=3.3)
    head = (5.5, -1.5 + 2.2 * math.sin(a))                                   # crosshead
    fig.capsule((5.5, -6), (5.5, 7), 0.9, DARK, z=2.9)                        # cylinder slot
    fig.capsule(pin, head, 0.6, BRONZE, z=3.4)                                # connecting rod
    fig.box((4.2, head[1] - 1.2, 6.8, head[1] + 1.2), STEEL, z=3.5, bevel=0.5)
    # pressure gauge, needle sweeping up as the stroke builds
    g = (4.8, 5.3)
    fig.disc(g, 2.2, BRONZE, z=3.6)
    fig.disc(g, 1.5, [(173, 198, 184)] * 2, z=3.7)
    t = math.radians(200 + 140 * (i / (n - 1)))
    fig.capsule(g, (g[0] + 1.4 * math.cos(t), g[1] + 1.4 * math.sin(t)), 0.3, DARK, z=3.8)
    fig.sphere((-3.5, -3.2), 0.9, GLOW, z=3.9, emissive=True)                 # status lamp
    return fig.render(MW, MH, MO)


TW, TH, TO = 40, 46, (20, 30)   # vein tapper: figure (0,0) = top face of the ore cell


def tapper(i, n=8):
    """Vein tapper: bores a spinning drill screw down into the ore vein,
    a flywheel and twin pistons pump, a mortar ring on top (the barrel is
    a separate sprite so the game can aim it)."""
    a = i / n * 2 * math.pi
    fig = Figure()
    # drill screw into the cell below: helical bands scroll down as it turns
    fig.capsule((0, 0), (0, 13), 2.4, STEEL, z=0)
    for k in range(-1, 5):
        y = k * 3.2 + (i % 4) * 0.8
        if 0 <= y <= 13:
            fig.capsule((-2.4, y), (2.4, y + 1.6), 0.5, DARK, z=0.1)
    fig.capsule((0, 13), (0, 15.5), 1.2, STEEL, z=0.2)                     # bit tip
    # flange clamped onto the rock
    fig.box((-12, -3, 12, 1.5), DARK, z=1, bevel=1.0)
    for x in (-10, -5, 5, 10):
        fig.sphere((x, -0.8), 0.8, STEEL, z=1.1)
    # twin pistons, out of phase
    for side, ph in ((-1, 0.0), (1, math.pi)):
        ext = 2.2 * math.sin(a + ph)
        fig.capsule((side * 11, -3), (side * 11, -12 - ext), 1.1, STEEL, z=1.2)
        fig.box((side * 11 - 1.8, -13.5 - ext, side * 11 + 1.8, -11.5 - ext), BRONZE, z=1.3, bevel=0.5)
    # housing
    fig.box((-9, -18, 9, -3), BRONZE, z=2, bevel=1.8)
    fig.box((-9, -19.5, 9, -17), DARK, z=2.1, bevel=0.6)
    # flywheel window
    fw = (-3.5, -9.5)
    fig.disc(fw, 4.6, DARK, z=2.2)
    fig.gear(fw, 4.0, 9, math.degrees(a) * 1.5, STEEL, z=2.3, hub_mat=BRONZE)
    # pressure gauge, needle sweeping
    g = (4.5, -10)
    fig.disc(g, 2.4, BRONZE, z=2.4)
    fig.disc(g, 1.6, [(173, 198, 184)] * 2, z=2.5)
    t = math.radians(200 + 70 * (1 + math.sin(a)))
    fig.capsule(g, (g[0] + 1.4 * math.cos(t), g[1] + 1.4 * math.sin(t)), 0.3, DARK, z=2.6)
    fig.sphere((4.5, -5.5), 0.8, GLOW, z=2.6, emissive=True)                # status lamp
    # turret ring the mortar sits in
    fig.ellipsoid((0, -20.5), (6, 2.2), STEEL, z=3)
    fig.ellipsoid((0, -21), (3.6, 1.2), DARK, z=3.1, grit=0.0)
    return fig.render(TW, TH, TO)


def mortar():
    """Tapper barrel, pointing +x, pivot at the breech (3, 5)."""
    fig = Figure()
    fig.sphere((1, 0), 3.4, BRONZE, z=0)                                   # breech ball
    fig.capsule((1, 0), (14, 0), 2.6, BRONZE, z=1)
    for x in (6, 10):
        fig.ellipsoid((x, 0), (0.8, 3.1), STEEL, z=1.5)
    fig.ellipsoid((15.5, 0), (1.6, 3.8), STEEL, z=2)                       # flared mouth
    fig.ellipsoid((16.6, 0), (0.8, 2.4), DARK, z=2.1, grit=0.0)
    return fig.render(22, 10, (3, 5))


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
    tap = [tapper(i) for i in range(8)]
    write_png(SPR + 'tapper.png', TW * 8, TH, [sum((f[y] for f in tap), []) for y in range(TH)])
    write_png(SPR + 'tapper_mortar.png', 22, 10, mortar())
    rig = [miner2(i) for i in range(8)]
    write_png(SPR + 'miner_rig.png', MW * 8, MH, [sum((f[y] for f in rig), []) for y in range(MH)])
    e = electrode(); write_png(SPR + 'electrode.png', 16, 20, e)
    print('wrote miner.png, electrode.png')
    if len(sys.argv) > 1:
        big = side_by_side(tap + [mortar()], 6)
        write_png(sys.argv[1] + '/tapper_preview.png', len(big[0]), len(big), big)
        big = side_by_side(rig, 10)
        write_png(sys.argv[1] + '/rig_preview.png', len(big[0]), len(big), big)
        big = side_by_side(frames + [e], 10)
        write_png(sys.argv[1] + '/machines_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
