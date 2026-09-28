"""Pellet press: a brass hopper over a small screw press. Two steel cheeks
under a brass crosshead, a threaded screw driving a ram down onto the die,
a brass spout on the out side. Drawn sending to +x (the code mirrors the
body for side -1).

    python3 tools/art/gen_pellet_press.py [preview_dir]

Writes (from the piece's origin, the middle of its feet):
- pellet_body.png   38x54, origin at (19, 52): the frame (+-12 wide, from
  the throat at y -34 down to the base on y -4..0), the die at y -12..-6,
  the spout at x 12..17, y -10..-5, and the hopper's dark inside
  (+-16 at the rim, y -50, to +-6 at the throat).
- pellet_front.png  40x36, origin at (20, 66): the hopper's brass walls
  (+-16, -50) -> (+-6, -34) and upright collar to y -62, drawn over the
  grit the code fills it with.
- pellet_ram.png    12x6, the middle of its top at (6, 1): the ram head,
  4 tall.
- pellet_screw.png  4x4, the screw, tiled down from the throat to the ram.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def body():
    fig = Figure()
    fig.poly([(-16, -50), (16, -50), (6, -34), (-6, -34)], DARK, z=0, shade=0.2)   # the hopper's inside
    fig.box((-8, -32, 8, -4), DARK, z=0.1, bevel=0.5)                              # the window, in shadow
    for s in (-1, 1):
        fig.box((s * 10 - 2.2, -34, s * 10 + 2.2, -3), STEEL, z=0.3, bevel=0.8)  # the cheeks
        for y in (-28, -18):
            fig.sphere((s * 10, y), 0.6, BRONZE, z=0.4)
    fig.box((-13, -35.5, 13, -31), BRONZE, z=0.4, bevel=0.8)                     # the crosshead (the screw's nut)
    fig.box((-3, -35, 3, -31.5), STEEL, z=0.45, bevel=0.6)
    fig.box((-6, -12.5, 6, -5.5), STEEL, z=0.3, bevel=0.8)                       # the die
    fig.box((-3.5, -12.8, 3.5, -11.6), DARK, z=0.35, bevel=0.3)                  # its cavity
    fig.box((12, -10.5, 17, -4.5), BRONZE, z=0.2, bevel=0.8)                     # the spout
    fig.ellipsoid((16.5, -7.5), (0.8, 2), DARK, z=0.25)                           # its mouth
    fig.box((-15, -4.5, 15, 0), BRONZE, z=0.5, bevel=0.9)                        # the base
    for x in (-11, 11):
        fig.sphere((x, -2.2), 0.6, STEEL, z=0.6)
    return fig.render(38, 54, (19, 52))


def front():
    fig = Figure()
    for s in (-1, 1):
        fig.poly([(s * 16, -50.5), (s * 19, -50.5), (s * 8.5, -33), (s * 6, -33)], BRONZE, z=0.2, shade=0.5)
        fig.capsule((s * 16, -50), (s * 6, -34), 0.9, BRONZE[2:], z=0.3)      # the inner lip
        fig.box((s * 17.3 - 1.6, -63, s * 17.3 + 1.6, -49), BRONZE, z=0.35, bevel=0.6)   # the upright collar
        fig.box((s * 17.3 - 2.2, -64.5, s * 17.3 + 2.2, -61.5), STEEL, z=0.4, bevel=0.6)
        fig.sphere((s * 12.5, -43), 0.6, STEEL, z=0.4)
        fig.box((s * 17.3 - 2, -51.5, s * 17.3 + 2, -49), STEEL, z=0.4, bevel=0.5)
    return fig.render(40, 36, (20, 66))


def ram():
    fig = Figure()
    fig.box((-5, 0, 5, 4), BRONZE, z=0, bevel=0.8)
    fig.box((-4, 2.8, 4, 4), STEEL, z=0.1, bevel=0.4)                             # the steel face
    return fig.render(12, 6, (6, 1))


def screw():
    fig = Figure()
    fig.box((-1.2, -2, 1.2, 6), STEEL, z=0, bevel=1.0, grit=0.0)
    img = fig.render(4, 4, (2, 0), outline=False)
    dark = (41, 38, 31, 255)
    for y in range(4):
        img[y][0] = img[y][3] = dark
    img[1][1] = img[2][2] = (95, 124, 131, 255)    # the thread, slanting
    return img


def main():
    parts = [('pellet_body', body()), ('pellet_front', front()), ('pellet_ram', ram()), ('pellet_screw', screw())]
    for name, img in parts:
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(n + '.png' for n, _ in parts))
    if len(sys.argv) > 1:
        big = side_by_side([p[1] for p in parts], 8)
        write_png(sys.argv[1] + '/pellet_press_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
