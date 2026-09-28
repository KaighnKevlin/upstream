"""Counterweight lift: an iron beam with the pulley's hanger fork, a big
grooved oak pulley (iron-tyred, brass hub; it turns as the ropes run),
and the oak bucket that hangs from each rope (iron bands, a bail handle,
its dark inside showing so the pieces in it read as in it). The ropes are
drawn in code.

    python3 tools/art/gen_counterweight.py [preview_dir]

Writes (the node is the pulley's axle):
- counterweight_beam.png    64x10, the axle at (32, 13): the beam y -11..-5.
- counterweight_pulley.png  44x44, the axle at the centre (22, 22); the
  ropes leave its groove at x +-18 (radius 20 overall).
- counterweight_fork.png    12x16, the axle at (6, 11): the strap from the
  beam down to the axle nut, drawn over the pulley.
- counterweight_bucket.png  24x22, the bucket's point (the code's c) at
  (12, 19): the rim y -16 (+-10), the floor y 0 (+-8), the bail's top at
  (0, -17) where the rope ties on.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]


def beam():
    fig = Figure()
    fig.box((-31, -11, 31, -5), IRON, z=0, bevel=1.0)
    fig.box((-31, -8.8, 31, -7.2), IRON[:4], z=0.1, bevel=0.4)          # the web between flanges
    for x in (-27, -13, 13, 27):
        fig.sphere((x, -8), 0.6, BRONZE, z=0.2)
    return fig.render(64, 10, (32, 13))


def pulley():
    fig = Figure()
    fig.disc((0, 0), 20.3, IRON, z=0)                                     # iron tyre
    fig.disc((0, 0), 18.6, DARK, z=0.1)                                   # the rope groove
    fig.disc((0, 0), 17.4, OAK, z=0.2)                                    # oak web
    for k in range(4):
        a = math.radians(k * 90 + 45)
        c, s = math.cos(a), math.sin(a)
        fig.disc((c * 10.2, s * 10.2), 3.4, DARK[:3], z=0.3)                # lightening holes
    for k in range(8):
        a = math.radians(k * 45)
        fig.sphere((math.cos(a) * 15.5, math.sin(a) * 15.5), 0.6, IRON, z=0.35)
    fig.disc((0, 0), 5.0, BRONZE, z=0.4)                                  # hub
    return fig.render(44, 44, (22, 22), extra=OAK_EXTRA)


def fork():
    fig = Figure()
    fig.box((-2.4, -9, 2.4, 1.5), IRON, z=0, bevel=0.8)
    fig.sphere((0, -6.5), 0.6, BRONZE, z=0.1)
    fig.disc((0, 0), 3.0, IRON, z=0.2)                                    # the axle nut
    fig.sphere((-0.3, -0.3), 1.2, BRONZE, z=0.3)
    return fig.render(12, 16, (6, 11))


def bucket():
    fig = Figure()
    fig.poly([(-9.3, -15.5), (9.3, -15.5), (7.4, -1), (-7.4, -1)], DARK, z=0, shade=0.25)   # the inside
    fig.poly([(-10, -16), (-8.5, -16), (-6.6, -0.5), (-8, -0.5)], OAK, z=0.5, shade=0.7)    # staves, lit side
    fig.poly([(8.5, -16), (10, -16), (8, -0.5), (6.6, -0.5)], OAK, z=0.5, shade=0.35)       # shade side
    fig.box((-8.5, -2.2, 8.5, 0.8), OAK, z=0.6, bevel=0.8)                                  # the floor
    fig.box((-10.8, -17, 10.8, -14.6), IRON, z=0.7, bevel=0.6)                             # rim band
    fig.box((-8.6, -1.8, 8.6, 0.4), IRON, z=0.7, bevel=0.5)                                # foot band
    # the bail: a thin iron hoop from the rim's ears up to the rope
    for s in (-1, 1):
        fig.capsule((s * 10.3, -15.6), (s * 5, -17.4), 0.5, IRON, z=0.8)
        fig.sphere((s * 10.3, -15.6), 0.8, BRONZE, z=0.9)
    fig.capsule((-5, -17.4), (5, -17.4), 0.5, IRON, z=0.8)
    return fig.render(24, 22, (12, 19), extra=OAK_EXTRA)


def main():
    b, p, f, k = beam(), pulley(), fork(), bucket()
    write_png(SPR + 'counterweight_beam.png', 64, 10, b)
    write_png(SPR + 'counterweight_pulley.png', 44, 44, p)
    write_png(SPR + 'counterweight_fork.png', 12, 16, f)
    write_png(SPR + 'counterweight_bucket.png', 24, 22, k)
    print('wrote counterweight_beam.png, counterweight_pulley.png, counterweight_fork.png, counterweight_bucket.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, p, f, k], 6)
        write_png(sys.argv[1] + '/counterweight_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
