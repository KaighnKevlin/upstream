"""Chime bar: a tuned bar that tiles along any length, its two rounded
ends, the brass posts with felt pads it rests on, and the steel stop at
its high end. The bar is cast in greys so the code can tint it with the
note's colour (modulate) and keep one sprite for every note.

    python3 tools/art/gen_chime.py [preview_dir]

Writes (the bar ones drawn along the bar's direction, rotated in code):
- chime_bar.png    16x8 tile, repeats along x; the bar's centre line on
  row 4 (between rows 3 and 4), its face rows 1-6.
- chime_caps.png   12x8: the low-x end in x 0..5 (the bar's end at x 1),
  the high-x end in x 6..11 (the end at x 10); same rows as the tile.
- chime_post.png   7x11, unrotated: the felt pad's top at (3, 0), the
  foot at the bottom.
- chime_stop.png   5x16, unrotated: the stop's foot (the bar's high end)
  at (2, 15), its top 14 px above.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

GREY_EXTRA = ['2e2e30', '58585a', '8a8a8a', 'b4b4b2', 'dcdcd8', 'f6f6f2']
GREY = [(46, 46, 48), (88, 88, 90), (138, 138, 138), (180, 180, 178), (220, 220, 216), (246, 246, 242)]
FELT_EXTRA = ['5a1e1e', '8a3030', 'b04a40']
FELT = [(90, 30, 30), (138, 48, 48), (176, 74, 64)]


def greyify(img):
    """Snap every pixel but the outline to the grey ramp, by brightness, so
    the tint reads as the note's colour and nothing else."""
    def lum(c): return 0.3 * c[0] + 0.55 * c[1] + 0.15 * c[2]
    out = []
    for row in img:
        line = []
        for px in row:
            if px[3] and px[:3] != OUTLINE:
                g = min(GREY, key=lambda q: abs(lum(q) - lum(px)))
                px = g + (255,)
            line.append(px)
        out.append(line)
    return out


def bar():
    fig = Figure()
    fig.box((-4, -3, 20, 3), GREY, z=0, bevel=1.6, grit=0.03)
    fig.capsule((-4, -1.3), (20, -1.3), 0.35, GREY[3:], z=0.1, grit=0)   # the lit edge
    return greyify(fig.render(16, 8, (0, 4), extra=GREY_EXTRA))


def caps():
    # the low end at x 1 (the bar runs on to the right), the high end at x 10
    lo, hi = Figure(), Figure()
    lo.box((1, -3, 14, 3), GREY, z=0, bevel=1.6, grit=0.03)
    lo.capsule((2, -1.3), (14, -1.3), 0.35, GREY[3:], z=0.1, grit=0)
    hi.box((-4, -3, 10, 3), GREY, z=0, bevel=1.6, grit=0.03)
    hi.capsule((-4, -1.3), (9, -1.3), 0.35, GREY[3:], z=0.1, grit=0)
    l = lo.render(12, 8, (0, 4), extra=GREY_EXTRA)
    h = hi.render(12, 8, (0, 4), extra=GREY_EXTRA)
    return greyify([l[y][:6] + h[y][6:] for y in range(8)])


def post():
    fig = Figure()
    fig.box((-0.9, 1, 0.9, 9.5), BRONZE, z=0, bevel=0.5)
    fig.ellipsoid((0, 1.2), (2.4, 1.2), FELT, z=0.2)                    # felt pad
    fig.box((-2.4, 8.4, 2.4, 10), STEEL, z=0.1, bevel=0.5)              # foot
    return fig.render(7, 11, (3, 0), extra=FELT_EXTRA)


def stop():
    fig = Figure()
    fig.box((-1.0, -13, 1.0, 0), STEEL, z=0, bevel=0.5)
    fig.box((-1.7, -14, 1.7, -12.2), BRONZE, z=0.1, bevel=0.5)
    fig.sphere((0, -6), 0.5, BRONZE, z=0.2)
    return fig.render(5, 16, (2, 15))


def main():
    b, c, p, s = bar(), caps(), post(), stop()
    write_png(SPR + 'chime_bar.png', 16, 8, b)
    write_png(SPR + 'chime_caps.png', 12, 8, c)
    write_png(SPR + 'chime_post.png', 7, 11, p)
    write_png(SPR + 'chime_stop.png', 5, 16, s)
    print('wrote chime_bar.png, chime_caps.png, chime_post.png, chime_stop.png')
    if len(sys.argv) > 1:
        full = [c[y][:6] + b[y] * 3 + c[y][6:] for y in range(8)]
        big = side_by_side([full, p, s], 8)
        write_png(sys.argv[1] + '/chime_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
