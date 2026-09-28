"""Caltrop spreader: a squat riveted iron drum on two feet with a hopper
funnel on top and, on its throwing side, a short spout ending in a vaned
spinner disc that flings the caltrops out. Plus the caltrops themselves.

    python3 tools/art/gen_caltrop_spreader.py [preview_dir]

Writes (all measured from the node origin, the ground surface at the
drum's centre):
- caltrop_spreader.png        28x34, the origin at (14, 32): the drum
  (x -11..11, y -14..-2) on its feet (to y 0), a brass band round it and
  the hopper funnel above (mouth x -7..7 at y -30, spout into the drum
  lid at y -15). The code's _hopper() is (0, -26).
- caltrop_spreader_spout.png  4 frames of 16x12 (hframes = 4), each with
  the pivot at (1, 6): placed at (10 * side, -7) and mirrored by
  scale.x = side. A tube out to x 8 and the spinner disc (centre x 11,
  r 3.5), its four vanes turned 22.5 deg a frame.
- caltrop.png                 3 frames of 9x7 (hframes = 3), each with
  the origin at (4, 6): the caltrop's resting point on the floor. Three
  ways a four-pointed caltrop lands; one spike always stands up.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]
SPIN_FRAMES = 4


def body():
    fig = Figure()
    for x in (-8, 5):
        fig.box((x, -3, x + 3, 0), IRON, z=0, bevel=0.6)                # feet
    fig.box((-11, -14, 11, -2), IRON, z=0.2, bevel=1.4, grit=0.08)      # the drum
    fig.box((-11.5, -15.5, 11.5, -13), IRON, z=0.3, bevel=0.7)          # lid rim
    fig.box((-11.5, -3.2, 11.5, -1.6), IRON, z=0.3, bevel=0.5)          # base rim
    fig.box((-11.2, -9.4, 11.2, -7.6), BRONZE, z=0.35, bevel=0.5)       # brass band
    for x in (-8, -3, 2, 7):
        fig.sphere((x + 0.5, -8.5), 0.55, STEEL, z=0.4)                 # band rivets
    fig.box((-7, -12.5, -5.8, -10), DARK, z=0.36, bevel=0.2)            # seams
    fig.box((5.8, -12.5, 7, -10), DARK, z=0.36, bevel=0.2)
    # hopper: a funnel standing on the lid
    fig.box((-2, -17, 2, -14.5), IRON, z=0.45, bevel=0.5)               # neck
    fig.poly([(-7.5, -29), (7.5, -29), (2.5, -17), (-2.5, -17)], IRON, z=0.5, shade=0.5)
    fig.poly([(-6.5, -29), (-3.5, -29), (-1.2, -18), (-2.2, -18)], IRON, z=0.55, shade=0.78)
    fig.box((-8.5, -31, 8.5, -28.5), IRON, z=0.6, bevel=0.6)            # mouth rim
    fig.box((-5.5, -30.6, 5.5, -29.2), DARK, z=0.65, bevel=0.2)         # the dark mouth
    return fig.render(28, 34, (14, 32), extra=COPPER_EXTRA)


def spout(k):
    """The spout pointing +x from its pivot; spinner vanes at angle k."""
    fig = Figure()
    fig.box((-1, -2.5, 2, 2.5), IRON, z=0, bevel=0.6)                   # collar on the drum
    fig.capsule((1, 0), (8, 0.5), 1.5, IRON, z=0.1)                     # tube
    fig.disc((11, 0.5), 3.6, IRON[1:], z=0.2)                           # spinner plate
    a = math.radians(k * 22.5)
    for i in range(4):
        t = a + i * math.pi / 2
        fig.capsule((11, 0.5), (11 + math.cos(t) * 3.4, 0.5 + math.sin(t) * 3.4), 0.55, BRONZE, z=0.3)
    fig.sphere((11, 0.5), 1.0, STEEL, z=0.4)                            # hub
    return fig.render(16, 12, (1, 6), extra=COPPER_EXTRA)


def caltrop(v):
    """Variant v: four spikes from a centre; one always points up."""
    fig = Figure()
    c = (0, -2.2)
    legs = [[(-3.5, 0.3), (3.4, 0.2), (0.2, -5.6)],
            [(-3.2, 0.2), (3.6, 0.0), (-0.8, -5.4), (1.8, -0.6)],
            [(-2.8, 0.3), (3.0, 0.3), (1.0, -5.5), (-1.6, -0.8)]][v]
    for i, p in enumerate(legs):
        fig.capsule(c, p, 0.75 if i < 2 else 0.7, STEEL, z=0.1 + i * 0.05)
    fig.sphere(c, 1.1, STEEL, z=0.4)
    return fig.render(9, 7, (4, 6), extra=COPPER_EXTRA)


def strip(frames):
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


def main():
    spins = [spout(i) for i in range(SPIN_FRAMES)]
    cals = [caltrop(v) for v in range(3)]
    parts = {'caltrop_spreader': body(), 'caltrop_spreader_spout': strip(spins),
             'caltrop': strip(cals)}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side([parts['caltrop_spreader']] + spins + cals, 8)
        write_png(sys.argv[1] + '/caltrop_spreader_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
