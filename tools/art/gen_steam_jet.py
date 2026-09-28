"""Steam jet: a little riveted steel boiler on splayed legs, brass-banded,
with a firebox door (dark: the code draws its glow), a pressure gauge on
its shoulder (ivory face; the code draws the needle) and a brass rose of
six nozzles on a stem on top.

    python3 tools/art/gen_steam_jet.py [preview_dir]

Writes steam_jet.png (26x33, the node origin at (11, 31): the drum x -8..8,
y -22..-4, legs to y 0; the firebox door's glass x -2..2, y -11..-9; the
gauge's centre (8, -15) radius 4; the nozzle rose's centre (0, -24)).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]
NOZZLE = (0, -24)


def body():
    fig = Figure()
    # legs, splayed, with little feet
    for s in (-1, 1):
        fig.capsule((s * 4.5, -5), (s * 7.2, -0.8), 0.9, STEEL, z=0)
        fig.box((s * 7.2 - 1.6, -1.2, s * 7.2 + 1.6, 0.4), STEEL, z=0.1, bevel=0.4)
    # the drum: rounded sides read as a cylinder
    fig.box((-8, -22, 8, -4), STEEL, z=1, bevel=3.2, grit=0.05)
    fig.ellipsoid((0, -22), (8, 1.6), STEEL, z=0.9)                   # the domed top
    for y in (-19.5, -7):
        fig.box((-8.3, y - 0.9, 8.3, y + 0.9), BRONZE, z=1.2, bevel=0.5)
        for x in (-5.5, -1.8, 1.8, 5.5):
            fig.sphere((x, y), 0.45, BRONZE, z=1.3)
    # the firebox door: a steel frame round dark glass
    fig.box((-3.4, -12.6, 3.4, -8), STEEL, z=1.4, bevel=0.6)
    fig.box((-2.2, -11.4, 2.2, -9.2), DARK, z=1.5, bevel=0.2, grit=0.01)
    fig.sphere((2.8, -10.3), 0.5, BRONZE, z=1.6)                       # its latch
    # the stem and the nozzle rose
    fig.box((-1.1, -24, 1.1, -21), BRONZE, z=1.6, bevel=0.4)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        c, s = math.cos(a), math.sin(a)
        fig.capsule(NOZZLE, (c * 4.6, NOZZLE[1] + s * 4.6), 0.7, BRONZE, z=1.7)
        fig.sphere((c * 4.8, NOZZLE[1] + s * 4.8), 0.6, DARK, z=1.75)
    fig.disc(NOZZLE, 2.8, BRONZE, z=1.8)
    fig.sphere(NOZZLE, 1.0, STEEL, z=1.9)
    # the pressure gauge on its shoulder
    fig.disc((8, -15), 4.2, BRONZE, z=2)
    fig.disc((8, -15), 3.0, IVORY, z=2.1)
    for k in range(4):
        a = math.pi * 0.75 + k * math.pi * 1.5 / 3
        fig.sphere((8 + math.cos(a) * 2.5, -15 + math.sin(a) * 2.5), 0.35, DARK, z=2.2)
    return fig.render(26, 33, (11, 31), extra=IVORY_EXTRA)


def main():
    b = body()
    write_png(SPR + 'steam_jet.png', 26, 33, b)
    print('wrote steam_jet.png')
    if len(sys.argv) > 1:
        big = side_by_side([b], 8)
        write_png(sys.argv[1] + '/steam_jet_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
