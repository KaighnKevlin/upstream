"""Portcullis: the stone gateway with its iron-banded posts, lintel and the
pulley arm out over the counterweight; the iron grille the code slides up
and down in it; the oak counterweight bucket; and the pulley wheel.

    python3 tools/art/gen_portcullis.py [preview_dir]

Writes (measured from the node origin, the middle of the gateway's foot):
- portcullis_frame.png   52x114, origin (34, 112): stone posts x -14..-10
  and 10..14 (y -96..0, grooved on the inside, three iron bands), the
  lintel x -17..17, y -100..-92 (a dark slot x -8..8, y -98..-96 behind the
  code's four load lights), the pulley stand on it at x 0, and the iron arm
  out to the second stand at x -24 (both axles at y -105).
- portcullis_grille.png  22x52, origin (11, 50): the grille, bottom centre
  at the origin: five iron bars x -9..9 down to spiked tips at y 0, six
  riveted cross-bars, a lifting eye on top (y -50..-47). The code moves it
  by position.y (0 down, -44 fully raised).
- portcullis_bucket.png  16x17, origin (8, 6): the counterweight bucket, the
  middle of its rim at the origin (x -7..7), the bail's eye at y -5, foot
  y 10; banded oak staves.
- portcullis_pulley.png  11x11, centre (5.5, 5.5): a spoked iron sheave,
  the code turns it as the chain runs.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]


def frame():
    fig = Figure()
    # the arm out to the counterweight's pulley, and its stand
    fig.box((-29, -104.2, 0, -100.4), IRON, z=0, bevel=0.6)
    fig.box((-26.2, -107.5, -21.8, -101), IRON, z=0.2, bevel=0.6)
    fig.box((-30, -101.5, -27, -95), IRON, z=0.1, bevel=0.5)          # its end bracket, down
    # the posts: dressed stone, grooved inside, three iron bands each
    for s in (-1, 1):
        x0, x1 = (s * 10, s * 14) if s > 0 else (s * 14, s * 10)
        fig.box((x0, -96, x1, 0), ROCK, z=1, bevel=0.9, grit=0.1)
        gx = s * 10.4
        fig.box((gx - 0.5, -92, gx + 0.5, 0), DARK[:2], z=1.2, bevel=0.1, grit=0.0)   # the groove
        for y in (-80, -48, -14):
            fig.box((x0 - 0.4, y - 1.3, x1 + 0.4, y + 1.3), IRON, z=1.4, bevel=0.5)
            fig.sphere((s * 12, y), 0.6, BRONZE, z=1.5)
        fig.box((x0 - 1, -3, x1 + 1, 0.8), ROCK, z=1.3, bevel=0.7, grit=0.1)          # plinth
    # the lintel: a stone beam capped in iron, the lights' slot in front
    fig.box((-17, -100, 17, -92), ROCK, z=2, bevel=1.0, grit=0.1)
    fig.box((-17.4, -101.2, 17.4, -99), IRON, z=2.2, bevel=0.5)
    fig.box((-8.3, -98.2, 8.3, -95.8), DARK[:2], z=2.4, bevel=0.2, grit=0.0)
    for x in (-13, 13):
        fig.sphere((x, -97), 0.8, BRONZE, z=2.5)
    # the gate pulley's stand on the lintel
    fig.box((-2.2, -107.5, 2.2, -100.5), IRON, z=2.3, bevel=0.6)
    return fig.render(52, 114, (34, 112), extra=OAK_EXTRA)


def grille():
    fig = Figure()
    for x in (-9, -4.5, 0, 4.5, 9):
        fig.box((x - 0.9, -48, x + 0.9, -3), IRON, z=0.2, bevel=0.6)
        fig.poly([(x - 1.1, -3.2), (x + 1.1, -3.2), (x, 0)], IRON, z=0.2, shade=0.5)   # spike
    for y in (-46, -37, -28, -19, -10):
        fig.box((-10.5, y - 0.9, 10.5, y + 0.9), DARK[2:] + IRON[3:4], z=0.4, bevel=0.5)
        for x in (-9, -4.5, 0, 4.5, 9):
            fig.sphere((x, y), 0.55, STEEL[3:], z=0.5)
    fig.box((-1.6, -50.2, 1.6, -46.5), IRON, z=0.3, bevel=0.5)             # lifting eye
    fig.box((-0.5, -49.5, 0.5, -48.3), DARK[:2], z=0.35, bevel=0.1, grit=0.0)
    # no outline: the bars are close, and a dark rim would fill the gaps between
    return fig.render(22, 52, (11, 50), outline=False)


def bucket():
    fig = Figure()
    fig.capsule((-6.3, 0.2), (0, -4.6), 0.45, IRON, z=0.1)                  # bail
    fig.capsule((6.3, 0.2), (0, -4.6), 0.45, IRON, z=0.1)
    fig.poly([(-7, 0), (7, 0), (5.2, 10.2), (-5.2, 10.2)], OAK, z=1, shade=0.55, grit=0.08)
    fig.poly([(-7, -0.3), (7, -0.3), (6.7, 1.2), (-6.7, 1.2)], DARK[:2], z=1.1, shade=0.5, grit=0.0)
    for x in (-3.5, 0, 3.5):
        fig.capsule((x, 1.8), (x * 0.78, 9.4), 0.25, OAK[:2], z=1.05)
    fig.box((-6.9, 1.4, 6.9, 2.8), IRON, z=1.2, bevel=0.4)
    fig.box((-5.8, 7.2, 5.8, 8.5), IRON, z=1.2, bevel=0.4)
    for s in (-1, 1):
        fig.sphere((s * 6.6, 0.4), 0.7, BRONZE, z=1.3)                     # bail lugs
    return fig.render(16, 17, (8, 6), extra=OAK_EXTRA)


def pulley():
    fig = Figure()
    fig.disc((0, 0), 5.0, IRON, z=0)
    fig.disc((0, 0), 3.6, DARK[:3], z=0.1)
    for a in (0, 60, 120):
        fig.box((-3.6, -0.55, 3.6, 0.55), IRON, z=0.2, bevel=0.3, tilt=a)
    fig.sphere((0, 0), 1.3, BRONZE, z=0.3)
    return fig.render(11, 11, (5.5, 5.5))


def main():
    f, g, b, p = frame(), grille(), bucket(), pulley()
    write_png(SPR + 'portcullis_frame.png', 52, 114, f)
    write_png(SPR + 'portcullis_grille.png', 22, 52, g)
    write_png(SPR + 'portcullis_bucket.png', 16, 17, b)
    write_png(SPR + 'portcullis_pulley.png', 11, 11, p)
    print('wrote portcullis_frame.png, portcullis_grille.png, portcullis_bucket.png, portcullis_pulley.png')
    if len(sys.argv) > 1:
        # assembled as the game draws it, the gate half raised
        W, H = 52, 116
        img = [[(0, 0, 0, 0)] * W for _ in range(H)]

        def paste(src, ox, oy):
            for y in range(len(src)):
                for x in range(len(src[0])):
                    if src[y][x][3] and 0 <= y + oy < H and 0 <= x + ox < W:
                        img[y + oy][x + ox] = src[y][x]
        ox, oy = 34, 113
        paste(g, ox - 11, oy - 22 - 50)
        paste(b, ox - 24 - 8, oy - 34 - 6)
        paste(f, ox - 34, oy - 112)
        paste(p, ox - 5, oy - 105 - 5)
        paste(p, ox - 24 - 5, oy - 105 - 5)
        big = side_by_side([img, f, g, b, p], 6)
        write_png(sys.argv[1] + '/portcullis_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
