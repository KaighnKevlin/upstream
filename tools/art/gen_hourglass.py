"""Hourglass: a brass-framed sand-glass on a steel stand, the code flips it.

    python3 tools/art/gen_hourglass.py [preview_dir]

Writes (all measured from the node origin, the pivot at the glass's neck):
- hourglass_stand.png 36x38, the origin at (18, 5): a steel yoke, a pivot
  boss at (+-13, 0) each side, the uprights down to a riveted foot plate
  at y 28..31. Stays still, behind the glass.
- hourglass_frame.png 26x52, the origin at (13, 26): brass end caps
  (y +-20..+-24, x +-11, a dark funnel slot x +-2.5 in each), two brass
  posts at x +-9.5 and the glass between them, dark inside (the code draws
  the grit over it). The inside, per bulb, has half-width 1 at the neck
  (d 0..1 from y 0), widening to 6 by d 9, 6 to d 18, 4 at the cap (d 20):
  the code's _half_w(d). Point-symmetric, so a half-turn looks the same.
- hourglass_front.png  26x52, same origin: the glints on the glass, drawn
  over the grit.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 26, 52, (13, 26)
# (d, half-width) down one bulb from the neck to the cap
PROFILE = [(0, 1.0), (1, 1.0), (9, 6.0), (18, 6.0), (20, 4.0)]


def _bulb(s, grow):
    """The bulb's outline as a polygon: s = -1 the top bulb, 1 the bottom."""
    left = [(-(w + grow), s * d) for d, w in PROFILE]
    right = [((w + grow), s * d) for d, w in reversed(PROFILE)]
    return left + right


def stand():
    fig = Figure()
    fig.box((-16.5, 27.5, 16.5, 31.5), STEEL, z=0, bevel=0.9)            # the foot plate
    for x in (-13, 13):
        fig.sphere((x, 29.5), 0.7, BRONZE, z=0.1)                        # its rivets
        fig.capsule((x, 0), (x, 28), 1.5, STEEL, z=0.2)                  # the uprights
        fig.box((x - 2.2, 24.5, x + 2.2, 28), STEEL, z=0.25, bevel=0.6)  # sockets
        fig.disc((x, 0), 3.0, STEEL, z=0.3)                              # pivot bosses
        fig.sphere((x, 0), 1.3, BRONZE, z=0.4)
    return fig.render(36, 38, (18, 5))


def frame():
    fig = Figure()
    for s in (-1, 1):
        # the glass: a pale rim, dark inside
        fig.poly(_bulb(s, 1.0), GLOW, z=0, shade=0.25, grit=0.02)
        fig.poly(_bulb(s, 0.0), DARK, z=0.1, shade=0.3, grit=0.02)
    for x in (-9.5, 9.5):
        fig.capsule((x, -21), (x, 21), 1.2, BRONZE, z=0.3)               # the posts
    for s in (-1, 1):
        y0, y1 = sorted((s * 20, s * 24.6))
        fig.box((-11.5, y0, 11.5, y1), BRONZE, z=0.5, bevel=0.8)          # the caps
        fig.box((-2.6, y0 + 0.6, 2.6, y1 - 0.6), DARK, z=0.6, bevel=0.3)  # funnel slot
        for x in (-7.5, 7.5):
            fig.sphere((x, s * 22.3), 0.6, STEEL, z=0.7)                 # cap rivets
    fig.sphere((-9.5, 0), 1.0, STEEL, z=0.8)                             # axle ends
    fig.sphere((9.5, 0), 1.0, STEEL, z=0.8)
    return fig.render(W, H, O)


def front():
    g = Figure()
    for s in (-1, 1):
        g.poly([(-4.6, s * 17), (-3.8, s * 17), (-3.8, s * 11), (-4.6, s * 11)], STEEL, z=0, shade=0.95, grit=0)
        g.poly([(3.8, s * 16), (4.6, s * 16), (4.6, s * 14), (3.8, s * 14)], STEEL, z=0, shade=0.85, grit=0)
    return g.render(W, H, O, outline=False)


def main():
    st, fr, fn = stand(), frame(), front()
    write_png(SPR + 'hourglass_stand.png', 36, 38, st)
    write_png(SPR + 'hourglass_frame.png', W, H, fr)
    write_png(SPR + 'hourglass_front.png', W, H, fn)
    print('wrote hourglass_stand.png, hourglass_frame.png, hourglass_front.png')
    if len(sys.argv) > 1:
        comp = [[(0, 0, 0, 0)] * 36 for _ in range(60)]
        for img, ox, oy in ((st, 0, 21), (fr, 5, 0), (fn, 5, 0)):
            for y in range(len(img)):
                for x in range(len(img[0])):
                    if img[y][x][3] and 0 <= y + oy < 60:
                        comp[y + oy][x + ox] = img[y][x]
        big = side_by_side([st, fr, fn, comp], 6)
        write_png(sys.argv[1] + '/hourglass_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
