"""Trommel: a perforated steel drum that tiles along any length and turns.
The drum's shell is split in two so the tumbling pieces show inside it: the
far wall (drawn under the ore) and the near side's staves, rims and holes
(drawn over it, open between). The turning is six frames of the staves and
hole rows sliding round the drum (the pattern repeats every quarter turn).

    python3 tools/art/gen_trommel.py [preview_dir]

Writes (all drawn along the drum's axis, rotated in code; x along the
axis, y across it, +y the side it hangs down to; the axis on row 12 of a
24-row tile, row 13 of a 26-row one):
- trommel_inner.png   12x24 tile: the far wall, a dim steel trough.
- trommel_back.png    12x144: 6 frames of 12x24, the far wall's holes.
- trommel_front.png   12x156: 6 frames of 12x26, the near staves and the
  drum's top and bottom rims.
- trommel_holes.png   12x156: 6 frames of 12x26, the near side's holes (a
  hole every 12 along each row at x 3, the odd rows' at x 9); the code
  starts this tile 3 px before the first ring of holes.
- trommel_hoop.png    5x26, a brass hoop round the drum, centred (2, 13).
- trommel_stand.png   14x19, a roller on a post to its foot, the roller's
  centre (the drum's underside) at (7, 4).
- trommel_mouth.png   10x12, the brass feed lip, the drum's top edge at the
  mouth at (8, 1).
- trommel_gear.png    11x11, the drive gear on the mouth hoop, centred.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

R = 11
FRAMES = 6
W = 12
WALL = [STEEL[0], STEEL[1], STEEL[1], STEEL[2], STEEL[2], STEEL[3]]


def _turn(f):
    return f * (math.pi / 2) / FRAMES


def _px(fig, x, y, mat, z, shade=None):
    """One pixel at the pixel holding (x, y)."""
    cx, cy = math.floor(x) + 0.5, math.floor(y) + 0.5
    if shade is None:
        fig.box((cx - 0.55, cy - 0.55, cx + 0.55, cy + 0.55), mat, z=z, bevel=0.1, grit=0.0)
    else:
        fig.poly([(cx - 0.55, cy - 0.55), (cx + 0.55, cy - 0.55), (cx + 0.55, cy + 0.55), (cx - 0.55, cy + 0.55)], mat, z=z, shade=shade, grit=0.0)


def inner():
    fig = Figure()
    # a trough lit from above: darker toward the rims
    for y in range(-R, R):
        t = 1 - abs(y + 0.5) / R
        fig.poly([(-4, y), (W + 4, y), (W + 4, y + 1), (-4, y + 1)], WALL, z=0, shade=0.1 + 0.7 * t * t, grit=0.05)
    return fig.render(W, 24, (0, 12), outline=False)


def _rows(f, near):
    """(x, y) of the hole rows on the near or far side for frame f."""
    out = []
    for k in range(8):
        th = _turn(f) + k * math.tau / 8
        if (math.sin(th) > 0) != near:
            continue
        y = math.cos(th) * (R - 1.5)
        out.append((9 if k % 2 else 3, y, abs(math.sin(th))))
    return out


def back(f):
    fig = Figure()
    for x, y, s in _rows(f, False):
        _px(fig, x, y, DARK, 1, shade=0.0)
    img = fig.render(W, 24, (0, 12), outline=False)
    return img


def front(f):
    fig = Figure()
    # the rims: the drum's silhouette top and bottom
    fig.poly([(-4, -R - 1), (W + 4, -R - 1), (W + 4, -R + 1), (-4, -R + 1)], DARK, z=0, shade=0.0, grit=0.0)
    fig.poly([(-4, -R + 1), (W + 4, -R + 1), (W + 4, -R + 2), (-4, -R + 2)], STEEL, z=0, shade=0.8, grit=0.03)
    fig.poly([(-4, R - 1), (W + 4, R - 1), (W + 4, R + 1), (-4, R + 1)], DARK, z=0, shade=0.0, grit=0.0)
    fig.poly([(-4, R - 2), (W + 4, R - 2), (W + 4, R - 1), (-4, R - 1)], STEEL, z=0, shade=0.3, grit=0.03)
    # the staves on the near side, brighter facing us
    for k in range(4):
        th = _turn(f) + k * math.tau / 4 + math.tau / 16
        if math.sin(th) <= 0:
            continue
        y = math.floor(math.cos(th) * (R - 1.5)) + 0.5
        s = math.sin(th)
        fig.poly([(-4, y - 0.55), (W + 4, y - 0.55), (W + 4, y + 0.55), (-4, y + 0.55)], STEEL, z=1, shade=0.35 + 0.5 * s, grit=0.04)
    return fig.render(W, 26, (0, 13), outline=False)


def holes(f):
    fig = Figure()
    for x, y, s in _rows(f, True):
        _px(fig, x, y, DARK, 1, shade=0.0)
    return fig.render(W, 26, (0, 13), outline=False)


def hoop():
    fig = Figure()
    fig.box((-1.2, -R - 0.8, 1.2, R + 0.8), BRONZE, z=0, bevel=0.8)
    for y in (-6, 0, 6):
        fig.sphere((0, y), 0.5, STEEL, z=0.1)
    return fig.render(5, 26, (2.5, 13))


def stand():
    fig = Figure()
    fig.box((-1.3, 0, 1.3, 12.5), STEEL, z=0, bevel=0.6)                # the post
    fig.box((-6, 11.5, 6, 13.8), STEEL, z=0.1, bevel=0.6)               # the foot
    for x in (-4.5, 4.5):
        fig.sphere((x, 12.6), 0.55, BRONZE, z=0.2)
    fig.disc((0, 0), 3.2, STEEL, z=0.3)                                  # the roller
    fig.disc((0, 0), 2.0, BRONZE, z=0.4)
    fig.sphere((0, 0), 0.7, DARK, z=0.5)
    return fig.render(14, 19, (7, 4))


def mouth():
    fig = Figure()
    fig.capsule((0, 0), (-6, -8), 1.2, BRONZE, z=0)
    fig.capsule((-5.8, -8), (-7, -8.6), 1.0, BRONZE, z=0.1)             # a rolled lip
    return fig.render(10, 12, (8, 10))


def gear():
    fig = Figure()
    fig.gear((0, 0), 4.2, 8, 0, BRONZE, z=0, hub_mat=STEEL)
    return fig.render(11, 11, (5.5, 5.5))


def _stack(frames):
    return [row for fr in frames for row in fr]


def main():
    ins = inner()
    bk = _stack([back(f) for f in range(FRAMES)])
    fr = _stack([front(f) for f in range(FRAMES)])
    ho = _stack([holes(f) for f in range(FRAMES)])
    parts = {'trommel_inner': ins, 'trommel_back': bk, 'trommel_front': fr, 'trommel_holes': ho,
             'trommel_hoop': hoop(), 'trommel_stand': stand(), 'trommel_mouth': mouth(), 'trommel_gear': gear()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        # each frame composed: inner + back holes, then front + near holes, a hoop
        comp = []
        for f in range(FRAMES):
            img = [[(0, 0, 0, 0)] * (W * 4) for _ in range(26)]
            for y in range(24):
                for x in range(W * 4):
                    for layer in (ins[y], bk[f * 24 + y]):
                        if layer[x % W][3]:
                            img[y + 1][x] = layer[x % W]
            for y in range(26):
                for x in range(W * 4):
                    for layer in (fr[f * 26 + y], ho[f * 26 + y]):
                        if layer[x % W][3]:
                            img[y][x] = layer[x % W]
            comp.append(img)
        big = side_by_side(comp + [parts['trommel_hoop'], parts['trommel_stand'], parts['trommel_mouth'], parts['trommel_gear']], 4)
        write_png(sys.argv[1] + '/trommel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
