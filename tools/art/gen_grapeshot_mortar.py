"""Grapeshot mortar: a squat iron pot with a flared funnel mouth, hung on
brass trunnions in iron cheeks on a brass sledge, and the steel loading
funnel over its mouth on a strut. Drawn aiming to +x (the code mirrors the
bed and funnel for side -1; the pot is symmetric and turns by its aim).

    python3 tools/art/gen_grapeshot_mortar.py [preview_dir]

Writes (from the piece's origin, the middle of the sledge's foot):
- grapeshot_bed.png     44x18, origin at (22, 16): the sledge along y -6..0,
  the trunnion cheeks up to y -14 round the pivot at (0, -12).
- grapeshot_pot.png     21 frames of 50x50, the trunnion (the pivot) at
  (25, 25) of each: the pot turned -50..50 degrees in steps of 5 (frame
  10 points straight up: the mouth's rim at y -20 from the pivot, the
  bulb's foot at +4). The code picks the frame nearest its aim.
- grapeshot_funnel.png  46x46, the catch point's x on the sledge's foot
  row at (24, 48) (8 from the piece's origin when unmirrored); lips run
  (+-14, -44) -> (+-7, -30), a strut runs down behind to the sledge.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:5]


def bed():
    fig = Figure()
    fig.box((-20, -6, 20, 0), BRONZE, z=0, bevel=1.0)                       # the sledge
    fig.capsule((-18.5, -1), (18.5, -1), 0.5, BRONZE[:3], z=0.05)
    for x in (-15, 15):
        fig.sphere((x, -3.2), 0.7, STEEL, z=0.3)
    for x in (-20.5, 20.5):
        fig.box((x - 1.5, -6.5, x + 1.5, 0), STEEL, z=0.2, bevel=0.5)        # iron shoes
    fig.poly([(-9, -6), (9, -6), (6, -15), (-6, -15)], IRON, z=0.2, shade=0.35)   # the trunnion cheeks
    fig.box((-9, -8, 9, -5.5), STEEL, z=0.25, bevel=0.6)
    return fig.render(44, 18, (22, 16))


STEP, TURNS = 5, 10          # pot frames: -50..50 degrees in 5s (21 frames)
POT_W = 50


def pot(deg=0):
    fig = Figure()
    fig.transform(deg, (0, 0))
    fig.ellipsoid((0, -3.5), (10.5, 8), STEEL[:6], z=0)                              # the squat bulb
    fig.poly([(-6.5, -9), (6.5, -9), (10.5, -19), (-10.5, -19)], IRON, z=0.1, shade=0.45)   # the flared mouth
    fig.capsule((-6, -10), (-10, -18.5), 0.6, STEEL[3:], z=0.15)              # its lit edge
    fig.capsule((6, -10), (10, -18.5), 0.5, IRON[:2], z=0.15)
    fig.box((-11, -21.5, 11, -18.5), BRONZE, z=0.3, bevel=0.7)               # the muzzle rim
    fig.ellipsoid((0, -21.3), (8, 0.9), DARK, z=0.35)                         # the bore, a dark slot
    fig.box((-8.2, -10.8, 8.2, -8.6), BRONZE, z=0.3, bevel=0.5)              # the neck hoop
    fig.box((-10.2, -4.2, 10.2, -2.2), BRONZE, z=0.3, bevel=0.5)             # the belly hoop
    fig.disc((0, 0), 3.4, BRONZE, z=0.4)                                        # the trunnion
    fig.sphere((0, 0), 1.3, STEEL, z=0.5)
    return fig.render(POT_W, POT_W, (POT_W // 2, POT_W // 2))


def funnel():
    fig = Figure()
    # the strut: from the rear lip down behind the pot to the sledge's end
    fig.capsule((-9, -36), (-22, -6), 0.9, STEEL[:5], z=0)
    fig.sphere((-22, -6.5), 1.0, BRONZE, z=0.1)
    for s in (-1, 1):
        fig.poly([(s * 14, -44.5), (s * 17.5, -44.5), (s * 9.5, -30), (s * 7, -30)], STEEL, z=0.5, shade=0.45)
        fig.capsule((s * 14, -44), (s * 7, -30), 0.8, STEEL[3:], z=0.55)     # the lip that takes the ore
        fig.box((s * 15.8 - 2.8, -46.5, s * 15.8 + 2.8, -43.5), BRONZE, z=0.6, bevel=0.6)   # rolled rim
        fig.sphere((s * 11, -37), 0.55, BRONZE, z=0.6)
    return fig.render(46, 46, (24, 48))


def main():
    frames = [pot(k * STEP) for k in range(-TURNS, TURNS + 1)]
    sheet = [sum((f[y] for f in frames), []) for y in range(POT_W)]
    parts = [('grapeshot_bed', bed()), ('grapeshot_pot', sheet), ('grapeshot_funnel', funnel())]
    for name, img in parts:
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(n + '.png' for n, _ in parts))
    if len(sys.argv) > 1:
        big = side_by_side([p[1] for p in parts], 8)
        write_png(sys.argv[1] + '/grapeshot_mortar_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
