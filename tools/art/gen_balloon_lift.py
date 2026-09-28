"""Balloon lift: a green gas bottle with a brass valve whose nozzle pipe
bends over to a little wicker basket on the ground, the balloons (one per
colour) the code ties to each rising piece, and the brass pin with its red
flag at the pop height.

    python3 tools/art/gen_balloon_lift.py [preview_dir]

Writes (all measured from the node origin, the basket's foot):
- balloon_lift.png   32x33, the origin at (20, 30): the bottle (x -19..-9,
  y -22..0) with its brass valve on top (y -26), the iron pipe along y -25
  over to x -4 and down to the nozzle at y -20; the wicker basket (rim
  y -14, x -10..10, foot y 2) in front of the bottle's foot.
- balloon_lift_balloon.png  4 frames of 16x20 (red, yellow, blue, green,
  the code's COLORS order), the balloon's centre at (8, 8) in each: a 7 px
  balloon with a highlight, the tied knot at (8, 16..17) where the string
  hangs from.
- balloon_lift_pin.png  12x13, the pin's point at (3, 11): a brass pin
  with a crossbar at y 0, the stem to y -8 with a knob, and the red flag
  pointing +x (the code mirrors it for side < 0).
"""
import sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

GAS_EXTRA = ['1c3324', '284a33', '366344', '4a7f58', '65a072', '8cc496']
GAS = [_hex(h) for h in GAS_EXTRA]
WICKER_EXTRA = ['4a3a22', '7a5433', 'a07844', 'c49a62', 'dcc088']
WICKER = [_hex(h) for h in WICKER_EXTRA]
FLAG_EXTRA = ['5a1a14', '9a2c22', 'd24a3a', 'f07a64']
FLAG = [_hex(h) for h in FLAG_EXTRA]
BALLOONS = [
    ['4a1410', '8a2a20', 'c24434', 'e06a54', 'f8a894', 'fff0e8'],      # red
    ['5a3e10', '9a7020', 'd4a238', 'f2c050', 'fce08a', 'fff8e0'],      # yellow
    ['142a4a', '24487a', '3c6eaa', '5a96d4', '90bce8', 'eef6ff'],      # blue
    ['1c3a1a', '2e6a2c', '4a9444', '6cbc5e', 'a0dc8c', 'f0ffe8'],      # green
]
EXTRA = GAS_EXTRA + WICKER_EXTRA + FLAG_EXTRA + [c for b in BALLOONS for c in b]


def base():
    fig = Figure()
    # the gas bottle: a rounded cylinder, its shoulder and neck
    fig.box((-19, -21, -9, 0), GAS, z=0, bevel=2.2, grit=0.05)
    fig.ellipsoid((-14, -20), (5, 2.4), GAS, z=0.05)
    fig.box((-16.2, -23.4, -11.8, -20.6), STEEL, z=0.1, bevel=0.6)     # the neck collar
    fig.box((-18.4, -12.6, -9.6, -10.6), GAS[:4], z=0.08, bevel=0.5)   # a painted band
    # the brass valve and its hand-wheel
    fig.box((-16, -26.2, -12, -23), BRONZE, z=0.2, bevel=0.7)
    fig.capsule((-17.6, -27.2), (-10.4, -27.2), 0.6, BRONZE, z=0.25)
    fig.sphere((-14, -27.2), 0.9, BRONZE, z=0.3)
    # the pipe over to the nozzle above the basket
    fig.capsule((-12, -25), (-5, -25), 0.8, STEEL, z=0.15)
    fig.sphere((-4.2, -24.6), 1.0, STEEL, z=0.16)                       # the elbow
    fig.capsule((-4, -24.4), (-4, -20.8), 0.8, STEEL, z=0.15)
    fig.box((-5.4, -21.4, -2.6, -19.6), BRONZE, z=0.2, bevel=0.5)       # the nozzle
    # the wicker basket: a tapered tub, woven bands, a rolled rim
    fig.poly([(-9.4, -13), (9.4, -13), (6.6, 1.6), (-6.6, 1.6)], WICKER, z=0.4, shade=0.5)
    for k, y in enumerate((-10, -6.5, -3, 0.2)):
        w = 9.0 - (y + 13) * 0.19
        fig.capsule((-w + 0.4, y), (w - 0.4, y), 0.55, WICKER, z=0.45)
    for x in (-5, 0, 5):
        fig.capsule((x, -12.4), (x * 0.7, 1.2), 0.45, WICKER[:3], z=0.47)
    fig.capsule((-9.8, -13.6), (9.8, -13.6), 1.1, WICKER, z=0.5)        # the rim
    return fig.render(32, 33, (20, 30), extra=EXTRA)


def balloon(i):
    mat = [_hex(h) for h in BALLOONS[i]]
    fig = Figure()
    fig.ellipsoid((0, -0.4), (6.8, 7.0), mat, z=0, grit=0.03)
    fig.ellipsoid((-2.6, -3.0), (1.3, 1.7), mat[3:], z=0.1, emissive=True)   # the shine
    fig.ellipsoid((0, 5.6), (2.6, 2.2), mat, z=-0.1, grit=0.03)       # the neck, tapering
    fig.poly([(-1.6, 7.0), (1.6, 7.0), (0.9, 9.2), (-0.9, 9.2)], mat[:4], z=0.2, shade=0.35)   # the knot
    return fig.render(16, 20, (8, 8), extra=EXTRA)


def pin():
    fig = Figure()
    fig.capsule((-2.8, 0), (2.8, 0), 0.7, BRONZE, z=0)                 # the crossbar
    fig.capsule((0, 0), (0, -8), 0.6, BRONZE, z=0.1)                   # the stem
    fig.sphere((0, -8.4), 1.1, BRONZE, z=0.2)                          # its knob
    fig.poly([(0.5, -7.4), (7.4, -5.4), (0.5, -3.2)], FLAG, z=0.15, shade=0.6)   # the flag
    fig.capsule((0.8, -6.6), (5.0, -5.4), 0.35, FLAG[1:], z=0.16)      # a fold in it
    return fig.render(12, 13, (3, 11), extra=EXTRA)


def main():
    b = base()
    bs = [balloon(i) for i in range(4)]
    p = pin()
    write_png(SPR + 'balloon_lift.png', 32, 33, b)
    write_png(SPR + 'balloon_lift_balloon.png', 64, 20, [sum((f[y] for f in bs), []) for y in range(20)])
    write_png(SPR + 'balloon_lift_pin.png', 12, 13, p)
    print('wrote balloon_lift.png, balloon_lift_balloon.png, balloon_lift_pin.png')
    if len(sys.argv) > 1:
        big = side_by_side([b] + bs + [p], 8)
        write_png(sys.argv[1] + '/balloon_lift_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
