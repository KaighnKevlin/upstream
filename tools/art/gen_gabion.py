"""Gabion: a 20x48 wire cage on the ground, drawn in two layers so the fill
of marbles the code stacks inside shows through the mesh, plus the marbles.

    python3 tools/art/gen_gabion.py [preview_dir]

Writes (all measured from the node origin, the middle of the cage's foot;
the cage spans x -10..10, y -48..0):
- gabion_back.png    20x48, origin (10, 48): the far side's mesh, a dark
  diamond weave half a cell out of step with the front, drawn behind the fill.
- gabion_front.png   24x52, origin (12, 50): the near side, drawn over the
  fill: a steel diamond mesh, iron corner posts, a riveted top rim
  (x -11..11, y -50..-47) and a base plate (y -3..0) with brass rivets.
- gabion_copper.png, gabion_iron.png  9x9, centre (4.5, 4.5): one piece of
  the fill; the code draws them two abreast (centres x -4.5 / 4.5), 8 px a row.
"""
import math
import sys
from clockwork import *
from clockwork import _ramp, _hash
from pixtools import write_png
from titan_lib import SPR, side_by_side, load_palette, nearest

P = 8            # diamond mesh pitch, px


def mesh(w, h, box, mat, phase, dx=0, dy=0, base=0.5):
    """A diamond weave of 1 px wires (both diagonals every P px), drawn
    straight in pixels so the lines stay clean, into a w x h image; box is
    the (px0, py0, px1, py1) it fills. The pattern is set in the front
    sprite's pixel frame (dx, dy shift into it) and mirror-symmetric about
    the cage's centre line; phase moves it half a cell for the far side.
    Knots, where the wires cross, are brighter; the / wires catch the light."""
    pal = load_palette()
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]
    a = (3 + phase) % P
    b = (23 - a) % P
    for py in range(box[1], box[3] + 1):
        for px in range(box[0], box[2] + 1):
            fx, fy = px + dx, py + dy
            on_a = (fx + fy) % P == a
            on_b = (fx - fy) % P == b
            if not (on_a or on_b):
                continue
            t = base + (0.2 if on_a and on_b else 0.08 if on_a else -0.06)
            t += (_hash(px, py, 3) - 0.5) * 0.08
            img[py][px] = nearest(pal, _ramp(mat, t)) + (255,)
    return img


def overlay(under, over):
    out = [row[:] for row in under]
    for y in range(len(over)):
        for x in range(len(over[0])):
            if over[y][x][3]:
                out[y][x] = over[y][x]
    return out


def back():
    return mesh(20, 48, (1, 1, 18, 46), DARK, P // 2, dx=2, dy=2, base=0.62)


def front():
    w = mesh(24, 52, (4, 3, 19, 47), STEEL, 0, base=0.42)

    fig = Figure()
    for s in (-1, 1):
        fig.box((s * 9 - 1.2, -47.5, s * 9 + 1.2, -2), STEEL, z=0.1, bevel=0.7)     # corner posts
        fig.box((s * 9 - 1.3, -25.4, s * 9 + 1.3, -22.6), STEEL, z=0.15, bevel=0.6)  # post collars
        fig.sphere((s * 9, -24), 0.6, BRONZE, z=0.2)
    fig.box((-11.2, -50.2, 11.2, -46.8), STEEL, z=0.3, bevel=0.8)                  # the top rim
    for x in (-8.5, -3, 3, 8.5):
        fig.sphere((x, -48.5), 0.7, BRONZE, z=0.35)                                  # its rivets
    fig.box((-11.2, -3.2, 11.2, 0), DARK + STEEL[3:6], z=0.3, bevel=0.8)           # the base plate
    for x in (-8.5, 8.5):
        fig.sphere((x, -1.6), 0.7, BRONZE, z=0.35)
    f = fig.render(24, 52, (12, 50))
    return overlay(w, f)


def marble(mat, extra=()):
    fig = Figure()
    fig.sphere((0, 0), 3.55, mat, z=0)
    return fig.render(9, 9, (4.5, 4.5), extra=extra)


def main():
    b, f = back(), front()
    cu, fe = marble(COPPER, COPPER_EXTRA), marble(STEEL)
    write_png(SPR + 'gabion_back.png', 20, 48, b)
    write_png(SPR + 'gabion_front.png', 24, 52, f)
    write_png(SPR + 'gabion_copper.png', 9, 9, cu)
    write_png(SPR + 'gabion_iron.png', 9, 9, fe)
    print('wrote gabion_back.png, gabion_front.png, gabion_copper.png, gabion_iron.png')
    if len(sys.argv) > 1:
        # and assembled as the game draws it, 9 pieces in
        comp = [[(0, 0, 0, 0)] * 24 for _ in range(52)]
        for y in range(48):
            for x in range(20):
                if b[y][x][3]:
                    comp[y + 2][x + 2] = b[y][x]
        kinds = ['copper', 'iron', 'copper', 'copper', 'iron', 'copper', 'copper', 'iron', 'copper']
        for i, k in enumerate(kinds):
            m = cu if k == 'copper' else fe
            cx, cy = -4.5 + (i % 2) * 9, -3.5 - (i // 2) * 8
            ox, oy = int(cx - 4.5) + 12, int(cy - 4.5) + 50
            for y in range(9):
                for x in range(9):
                    if m[y][x][3]:
                        comp[y + oy][x + ox] = m[y][x]
        comp = overlay(comp, f)
        big = side_by_side([b, f, cu, fe, comp], 8)
        write_png(sys.argv[1] + '/gabion_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
