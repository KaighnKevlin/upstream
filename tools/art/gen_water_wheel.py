"""Water wheel: a wooden undershot wheel, the oak A-frame it stands on
straddling a flume, and the iron axle cap. The code turns the wheel and
draws the spray where the paddles bite the water.

    python3 tools/art/gen_water_wheel.py [preview_dir]

Writes (all measured from the axle, the node origin; paddle tips R = 20):
- water_wheel_frame.png  34x32, the axle at (17, 4): two oak legs splaying
  from an iron bearing block at the axle down to (+-14, 26) (R + 6), each
  on a little iron-shod foot, with a cross-brace between them at y 14 set
  wide enough to clear a trough under the wheel.
- water_wheel.png        44x44, centre (22, 22): the oak rim at r 15
  (R - 5), eight spokes in to an iron-banded hub, and eight flat oak
  paddles (6 px wide) standing out from r 13 to the tips at r 20, spoke k and paddle k
  along k * 45 degrees; the code rotates it.
- water_wheel_axle.png   8x8, centre (4, 4): the iron axle end and its pin.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
# the paddles: wetter, darker oak (as the flume floor)
WET_EXTRA = ['3a2c22', '523a28', '6a4c31']
WET = [(42, 34, 28), (58, 44, 34), (82, 58, 40), (106, 76, 49), (122, 84, 51)]
IRON = STEEL[:6]
EXTRA = OAK_EXTRA + WET_EXTRA
R = 20.0


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1.5, 0.5), (s * 13.6, 24.0), 1.5, OAK, z=0.1, grit=0.1)       # the leg
        fig.capsule((s * 5.2, 8.6), (s * 10.2, 18.4), 0.3, OAK[:2], z=0.15)           # grain
        fig.box((s * 14 - 2.8, 23.2, s * 14 + 2.8, 25.9), IRON, z=0.3, bevel=0.6)     # the iron shoe
        fig.sphere((s * 14, 24.6), 0.5, BRONZE, z=0.35)
    fig.box((-8.6, 13.2, 8.6, 15.0), OAK[:4], z=0.05, bevel=0.5)                     # the brace
    for s in (-1, 1):
        fig.sphere((s * 7.4, 14.1), 0.55, IRON, z=0.2)                               # its pegs
    fig.box((-4.2, -3.2, 4.2, 3.2), IRON, z=0.4, bevel=0.9)                          # the bearing block
    fig.disc((0, 0), 2.2, DARK, z=0.45)
    return fig.render(34, 32, (17, 4), extra=EXTRA)


def wheel():
    fig = Figure()
    for k in range(8):
        a = math.radians(k * 45)
        c, s = math.cos(a), math.sin(a)
        fig.capsule((c * 3, s * 3), (c * 14, s * 14), 0.85, OAK, z=0, grit=0.08)      # the spoke
    # the rim: a ring of short oak segments at r 15
    segs = 48
    for k in range(segs):
        a0, a1 = k / segs * math.tau, (k + 1.2) / segs * math.tau
        r = R - 5
        fig.capsule((math.cos(a0) * r, math.sin(a0) * r), (math.cos(a1) * r, math.sin(a1) * r), 1.25, OAK, z=1, grit=0.1)
    for k in range(8):
        a = math.radians(k * 45)
        c, s = math.cos(a), math.sin(a)
        # the paddle: a wet oak board along the radius, from inside the rim out to the tip
        cx, cy = c * (R - 3.5), s * (R - 3.5)
        fig.box((cx - 3.6, cy - 2.9, cx + 3.6, cy + 2.9), WET, z=2, bevel=0.7, tilt=k * 45, grit=0.1)
        fig.box((c * (R - 0.7) - 0.7, s * (R - 0.7) - 2.9, c * (R - 0.7) + 0.7, s * (R - 0.7) + 2.9),
                IRON, z=2.1, bevel=0.3, tilt=k * 45)                                  # its iron edge
        fig.sphere((c * (R - 5), s * (R - 5)), 0.55, IRON, z=2.2)                     # the nail through the rim
    fig.disc((0, 0), 4.2, OAK, z=3)                                                   # the hub
    fig.disc((0, 0), 3.1, IRON, z=3.05)                                               # its band
    return fig.render(44, 44, (22, 22), extra=EXTRA)


def axle():
    fig = Figure()
    fig.disc((0, 0), 2.8, IRON, z=0)
    fig.sphere((0, 0), 1.6, STEEL, z=0.1)
    fig.box((-0.4, -2.6, 0.4, 2.6), DARK, z=0.2, bevel=0.2, grit=0.0)                 # the pin
    return fig.render(8, 8, (4, 4))


def main():
    f, w, a = frame(), wheel(), axle()
    write_png(SPR + 'water_wheel_frame.png', 34, 32, f)
    write_png(SPR + 'water_wheel.png', 44, 44, w)
    write_png(SPR + 'water_wheel_axle.png', 8, 8, a)
    print('wrote water_wheel_frame.png, water_wheel.png, water_wheel_axle.png')
    if len(sys.argv) > 1:
        # and the three together, as the game shows them (axle at (22, 22))
        both = [[(0, 0, 0, 0)] * 44 for _ in range(50)]
        for img, ox, oy in ((f, 5, 18), (w, 0, 0), (a, 18, 18)):
            for y in range(len(img)):
                for x in range(len(img[0])):
                    if img[y][x][3]:
                        both[y + oy][x + ox] = img[y][x]
        big = side_by_side([f, w, a, both], 8)
        write_png(sys.argv[1] + '/water_wheel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
