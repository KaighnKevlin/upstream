"""Stamp press: a mine's ore stamp. Two iron-banded oak posts on steel
feet, braced up into an oak crossbeam that carries the brass hopper and
the lifting cam; a heavy iron weight on a steel stem hangs between them.

    python3 tools/art/gen_stamp_press.py [preview_dir]

Writes (coordinates from the piece's origin, the middle of its feet):
- stamp_frame.png   84x156, origin at (42, 153): the posts at x +-34 from
  the floor up to the beam (y -150), braces, foot plates.
- stamp_beam.png    84x42, origin at (42, 184): the crossbeam along y -150,
  the cam's bearing at (0, -151), the hopper lips (+-15, -180) -> (+-8, -162)
  on struts. The code jolts it down a pixel when the weight lands.
- stamp_weight.png  50x26, the middle of its striking face at (25, 23):
  the block is +-23 wide, 19 tall; a collar on top takes the stem.
- stamp_rod.png     4x8, the stem, tiled down from the beam to the collar.
- stamp_cam.png     14x14, its axle at (7, 7); the code turns it.
- stamp_pawl.png    14x6, the latch; its post end at (1, 3), reaching
  +12 toward the weight. Shown while the weight is held up.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = [c for c in STEEL[:5]]      # the darker end of steel: cast iron


def frame():
    fig = Figure()
    for s in (-1, 1):
        x = s * 34
        fig.box((x - 3, -150, x + 3, -2), OAK, z=0, bevel=1.0)                   # the post
        fig.capsule((x + 1.2 * s, -148), (x + 1.2 * s, -4), 0.5, OAK[:2], z=0.05)   # its shaded edge
        for y in (-128, -96, -64, -32):
            fig.box((x - 3.6, y - 1.3, x + 3.6, y + 1.3), STEEL, z=0.3, bevel=0.5)   # iron bands
            fig.sphere((x, y), 0.6, BRONZE, z=0.4)
        fig.capsule((x, -124), (s * 15.3, -149), 1.4, OAK, z=0.1)             # the brace
        fig.sphere((x - s * 0.5, -124), 0.9, BRONZE, z=0.35)
        fig.box((x - 6, -4.5, x + 6, 0), STEEL, z=0.5, bevel=0.7)               # the foot plate
        for dx in (-4, 4):
            fig.sphere((x + dx, -2.2), 0.6, BRONZE, z=0.6)
        # the stem's guides, where the weight rides between the posts
        fig.box((x - s * 4.6 - 0.9, -146, x - s * 4.6 + 0.9, -6), STEEL[:4], z=-0.2, bevel=0.4)
    return fig.render(84, 156, (42, 153), extra=OAK_EXTRA)


def beam():
    fig = Figure()
    fig.box((-40, -153.5, 40, -146.5), OAK, z=0, bevel=1.1)                    # the crossbeam
    fig.capsule((-38, -147.6), (38, -147.6), 0.5, OAK[:2], z=0.05)
    for x in (-40, 40):
        fig.box((x - 2.4, -154.3, x + 2.4, -145.7), STEEL, z=0.2, bevel=0.6)   # end caps
    for x in (-34, 34):
        fig.box((x - 3.6, -154.5, x + 3.6, -145.5), STEEL, z=0.25, bevel=0.6)  # the post straps
        fig.sphere((x, -150), 0.7, BRONZE, z=0.3)
    for x in (-24, -14, 14, 24):
        fig.sphere((x, -150.3), 0.6, STEEL, z=0.3)
    fig.box((-4, -147, 4, -143.5), STEEL, z=0.3, bevel=0.6)                    # the stem guide collar
    fig.disc((0, -151), 7, BRONZE, z=0.4)                                        # the cam's bearing plate
    fig.disc((0, -151), 5, DARK, z=0.45)
    # the hopper: two brass cheeks on struts over the beam
    for s in (-1, 1):
        fig.capsule((s * 9, -161), (s * 6, -154), 1.3, STEEL, z=0.2)          # struts
        fig.poly([(s * 15, -180.5), (s * 20, -180.5), (s * 11.5, -161), (s * 8, -161)], BRONZE, z=0.5, shade=0.5)
        fig.capsule((s * 19.2, -179.5), (s * 11, -162), 0.6, BRONZE[:3], z=0.55)   # its shaded outer edge
        fig.capsule((s * 15, -180), (s * 8, -162), 0.9, BRONZE[2:], z=0.6)    # the lip that takes the ore
        fig.box((s * 17.5 - 3.5, -182.5, s * 17.5 + 3.5, -179.5), STEEL, z=0.7, bevel=0.6)   # the rolled rim
        fig.sphere((s * 13.5, -171), 0.6, STEEL, z=0.7)                       # rivets
        fig.box((s * 9.5 - 2.5, -163.5, s * 9.5 + 2.5, -160), STEEL, z=0.7, bevel=0.5)   # the clamp
    return fig.render(84, 42, (42, 184), extra=OAK_EXTRA)


def weight():
    fig = Figure()
    fig.box((-23, -19, 23, 0), IRON, z=0, bevel=1.4)                           # the iron block
    fig.box((-22, -5, 22, -0.5), IRON[:4], z=0.1, bevel=0.8)      # the worn striking shoe
    for y in (-16, -7.5):
        fig.box((-23.5, y - 1, 23.5, y + 1), BRONZE, z=0.2, bevel=0.5)          # brass bands
    for x in (-17, 17):
        fig.disc((x, -11.5), 2.2, STEEL, z=0.3)                                 # the bolt heads
        fig.sphere((x, -11.5), 1.0, BRONZE, z=0.4)
    fig.box((-4.5, -22.5, 4.5, -18.5), BRONZE, z=0.3, bevel=0.7)               # the stem collar
    fig.sphere((0, -20.5), 0.8, STEEL, z=0.4)
    return fig.render(50, 26, (25, 23))


def rod():
    fig = Figure()
    fig.box((-1.2, -2, 1.2, 12), STEEL, z=0, bevel=1.1, grit=0.0)
    img = fig.render(4, 8, (2, 0), outline=False)
    for row in img:     # dark sides, so it reads as a rod when tiled
        row[0] = (41, 38, 31, 255)
        row[3] = (41, 38, 31, 255)
    return img


def cam():
    fig = Figure()
    fig.ellipsoid((1.5, 0), (5.5, 4.2), BRONZE, z=0)                            # the lobe
    fig.disc((0, 0), 4.4, BRONZE, z=0.1)
    fig.disc((0, 0), 1.9, STEEL, z=0.2)
    fig.sphere((4.2, 0), 0.8, STEEL, z=0.3)                                      # the lobe's roller pin
    return fig.render(14, 14, (7, 7))


def pawl():
    fig = Figure()
    fig.poly([(0, -1.2), (11, -0.4), (12.5, 1.6), (0, 1.6)], BRONZE, z=0, shade=0.6)
    fig.capsule((0, 0.2), (11, 0.4), 0.9, BRONZE, z=0.1)
    fig.disc((0.5, 0.2), 1.9, STEEL, z=0.2)                                      # its pin on the post
    return fig.render(14, 6, (1, 3))


def main():
    parts = [('stamp_frame', frame()), ('stamp_beam', beam()), ('stamp_weight', weight()),
             ('stamp_rod', rod()), ('stamp_cam', cam()), ('stamp_pawl', pawl())]
    for name, img in parts:
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(n + '.png' for n, _ in parts))
    if len(sys.argv) > 1:
        big = side_by_side([p[1] for p in parts], 4)
        write_png(sys.argv[1] + '/stamp_press_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
