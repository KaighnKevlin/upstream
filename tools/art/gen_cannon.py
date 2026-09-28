"""Marble cannon: a squat brass gun on an oak carriage with two iron-tyred
wheels, a steel hopper funnel on its back and a magazine tray under the
funnel (the code draws the loaded marbles in it); and the barrel, which
recoils on its own.

    python3 tools/art/gen_cannon.py [preview_dir]

Writes (drawn facing right, side = +1; the code mirrors both for side -1):
- marble_cannon_carriage.png  48x48, the node origin (the floor under the wheels'
  centre line) at (24, 44). Wheels at (+-10, -4) r 6, the carriage cheek
  y -14..-6, the hopper lips (-20, -40) -> (-7, -18) and (8, -40) ->
  (7, -18), the magazine tray's slot on the row y -18, x -16..15.
- marble_cannon_barrel.png    50x18, the node origin at (16, 20): breech at
  (-10, -12), muzzle at (28, -10), as the code's old line ran. The code
  slides it back along x as the gun kicks.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]


def wheel(fig, c, z):
    cx, cy = c
    fig.disc(c, 6.2, STEEL, z=z)                                   # iron tyre
    fig.disc(c, 4.7, OAK, z=z + 0.1)                               # felloe
    fig.disc(c, 3.6, DARK, z=z + 0.2)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        fig.capsule((cx + math.cos(a) * 1.2, cy + math.sin(a) * 1.2),
                    (cx + math.cos(a) * 4.0, cy + math.sin(a) * 4.0), 0.65, OAK, z=z + 0.3)
    fig.sphere(c, 1.7, BRONZE, z=z + 0.4)                          # hub
    fig.sphere((cx - 0.3, cy - 0.3), 0.6, STEEL, z=z + 0.5)        # axle pin


def carriage():
    fig = Figure()
    # the hopper: a dark funnel back, steel lip plates on brass clamps
    fig.poly([(-20, -40), (8, -40), (7, -19), (-7, -19)], DARK, z=-1, shade=0.35)
    for a, b in (((-20, -40), (-7, -18)), ((8, -40), (7, -18))):
        fig.capsule(a, b, 1.5, STEEL, z=1)
        fig.box((a[0] - 1.8, a[1] - 2.2, a[0] + 1.8, a[1] + 1.0), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((a[0], a[1] - 0.6), 0.55, STEEL, z=1.2)
    fig.capsule((-13, -29), (7.5, -29), 0.7, BRONZE, z=0.5)       # a brace band
    # the magazine tray the funnel feeds, with its dark slot (the load shows in it)
    fig.box((-18, -21.5, 17, -14.5), STEEL, z=2, bevel=0.8)
    fig.box((-16.8, -20.2, 15.8, -15.8), DARK, z=2.1, bevel=0.3, grit=0.02)
    for x in (-17.2, 16.2):
        fig.sphere((x, -18), 0.5, BRONZE, z=2.2)
    # the carriage cheek: oak, iron-strapped, stepped up to the trunnion
    fig.poly([(-17, -14), (-2, -14), (0, -17), (10, -17), (12, -14), (16, -14), (16, -6), (-17, -6)], OAK, z=3, shade=0.55, grit=0.08)
    fig.box((-17, -14.5, 16, -12.8), OAK, z=3.1, bevel=0.6, grit=0.08)
    fig.box((-17, -7.4, 16, -5.6), OAK, z=3.1, bevel=0.6, grit=0.06)
    for x in (-5, 13):
        fig.box((x - 0.8, -14.2, x + 0.8, -5.8), STEEL, z=3.2, bevel=0.4)
        fig.sphere((x, -10), 0.5, BRONZE, z=3.3)
    fig.box((-19, -11, -16.5, -7), STEEL, z=3.2, bevel=0.5)       # the trail's ring
    wheel(fig, (-10, -4), 4)
    wheel(fig, (10, -4), 4)
    return fig.render(48, 48, (24, 44), extra=OAK_EXTRA)


def barrel():
    fig = Figure()
    a, b = (-8.5, -12.2), (26.5, -10.1)
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L

    deg = math.degrees(math.atan2(uy, ux))

    def at(t):
        return (a[0] + ux * t, a[1] + uy * t)

    def tube(t0, t1, r, z, mat=BRONZE):
        cx, cy = at((t0 + t1) / 2)
        h = (t1 - t0) / 2
        fig.box((cx - h, cy - r, cx + h, cy + r), mat, z=z, bevel=r * 0.95, grit=0.04, tilt=deg)

    tube(0, L, 3.9, 0)                                             # the chase
    tube(0, 13, 4.6, 0.1)                                          # the reinforce at the breech
    tube(-0.6, 1.4, 5.2, 0.3)                                      # base ring
    tube(12, 13.6, 5.0, 0.3)                                       # reinforce ring
    tube(22, 23.2, 4.5, 0.3)                                       # chase band
    tube(L - 3.4, L, 4.8, 0.3)                                     # the muzzle swell
    fig.ellipsoid(at(L + 0.2), (0.9, 2.4), DARK, z=0.5)            # the bore
    fig.sphere(at(-3.0), 1.9, BRONZE, z=0.2)                       # cascabel knob
    tube(-2.4, -0.4, 1.1, 0.15)
    fig.disc(at(8.5), 2.3, STEEL, z=0.6)                           # trunnion
    fig.sphere(at(8.5), 0.8, BRONZE, z=0.7)
    return fig.render(50, 18, (16, 20))


def main():
    c, b = carriage(), barrel()
    write_png(SPR + 'marble_cannon_carriage.png', 48, 48, c)
    write_png(SPR + 'marble_cannon_barrel.png', 50, 18, b)
    print('wrote marble_cannon_carriage.png, marble_cannon_barrel.png')
    if len(sys.argv) > 1:
        # the barrel over the carriage, as the game layers them (origins aligned)
        big = [[(0, 0, 0, 0)] * 60 for _ in range(48)]
        for y in range(48):
            for x in range(48):
                big[y][x] = c[y][x]
        for y in range(18):
            for x in range(50):
                if b[y][x][3]:
                    X, Y = x - 16 + 24, y - 20 + 44
                    if 0 <= X < 60 and 0 <= Y < 48:
                        big[Y][X] = b[y][x]
        out = side_by_side([c, b, big], 6)
        write_png(sys.argv[1] + '/cannon_preview.png', len(out[0]), len(out), out)


if __name__ == '__main__':
    main()
