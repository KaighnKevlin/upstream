"""Rope bridge: a weathered oak post with a hemp lashing round its head and
an iron spike driven into the ground at its foot, deck planks (three
variants), and a hemp knot for where the ties meet the hand rope. The code
draws the two ropes and the ties as polylines along the simulated chain.

    python3 tools/art/gen_rope_bridge.py [preview_dir]

Writes:
- rope_bridge_post.png   7x32, its node origin (where the deck rope ties on)
  at (3, 24). The post runs from its knob at y -23 down to y +4, the hemp
  lashing where the hand rope ties on round y -20..-16, the spike to y +7.
- rope_bridge_plank_0..2.png  16x5, the segment's midpoint on the chain at
  (8, 1): a 14 px oak board on rows -1..3 (the side facing the chain's
  normal, i.e. down, is +y). The code rotates each by its segment's angle.
- rope_bridge_knot.png   3x3, centred at (1, 1).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
# weathered oak: greyer, for the posts that stand out in the damp
OLD_EXTRA = ['3d3226', '5c4a36', '7d6a50', '9c8a6c']
OLD = [(42, 34, 28), (61, 50, 38), (92, 74, 54), (125, 106, 80), (156, 138, 108)]
HEMP_EXTRA = ['4a3a22', '7a6440', 'b89c68', 'd8c090']
HEMP = [(74, 58, 34), (122, 100, 64), (184, 156, 104), (216, 192, 144)]
EXTRA = OAK_EXTRA + OLD_EXTRA + HEMP_EXTRA


def post():
    fig = Figure()
    fig.box((-2.4, -21, 2.4, 4.5), OLD, z=0, bevel=1.0, grit=0.12)
    # grain splits down the face
    fig.capsule((-0.6, -12), (-0.6, -4), 0.3, OLD[:2], z=0.05)
    fig.capsule((0.9, -3), (0.9, 2), 0.3, OLD[:2], z=0.05)
    fig.sphere((0, -21.2), 2.2, OLD, z=0.1)                          # the rounded knob
    for y in (-19.6, -18.2, -16.8):                                  # the hemp lashing
        fig.capsule((-3.2, y + 0.4), (3.2, y - 0.4), 0.75, HEMP, z=0.3)
    fig.capsule((2.8, -16.5), (3.2, -14.2), 0.55, HEMP, z=0.35)       # a loose end
    fig.box((-2.8, -0.6, 2.8, 1.2), STEEL[:5], z=0.2, bevel=0.5)     # the iron band at the deck tie
    fig.poly([(-1.8, 4.2), (1.8, 4.2), (0, 7.8)], STEEL[:6], z=0.2, shade=0.5)   # the spike
    return fig.render(7, 32, (3.5, 24), extra=EXTRA)


def plank(v):
    fig = Figure()
    x0, x1 = -7, 7
    if v == 1:
        x0, x1 = -6.8, 6.6
    fig.box((x0, -1, x1, 3), OAK, z=0, bevel=0.6, grit=0.1)
    # a knot or a split, and the nail heads where it sits on the ropes
    if v == 0:
        fig.capsule((-3, 1), (2, 1), 0.3, OAK[:2], z=0.1)
    elif v == 1:
        fig.sphere((1.5, 1.2), 0.7, OAK[:3], z=0.1)
    else:
        fig.capsule((-5, 0.5), (-1, 0.5), 0.3, OAK[:2], z=0.1)
        fig.capsule((2, 1.8), (5, 1.8), 0.3, OAK[:2], z=0.1)
    for x in (-5.5, 5.2):
        fig.sphere((x, 0.2), 0.45, STEEL, z=0.2)
    return fig.render(16, 5, (8, 1), extra=EXTRA)


def knot():
    fig = Figure()
    fig.sphere((0, 0), 1.0, HEMP, z=0)
    return fig.render(3, 3, (1.5, 1.5), outline=True, extra=EXTRA)


def main():
    parts = {'rope_bridge_post': post(), 'rope_bridge_knot': knot()}
    for v in range(3):
        parts['rope_bridge_plank_%d' % v] = plank(v)
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side([parts['rope_bridge_post'], parts['rope_bridge_plank_0'],
                            parts['rope_bridge_plank_1'], parts['rope_bridge_plank_2'],
                            parts['rope_bridge_knot']], 8)
        write_png(sys.argv[1] + '/rope_bridge_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
