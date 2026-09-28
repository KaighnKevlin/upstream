"""Flail: an iron post on a footing plate, the chain and spiked ball the
code whirls round the swivel on top, and the brass swivel cap.

    python3 tools/art/gen_flail.py [preview_dir]

Writes (all measured from the node origin, the ground under the post;
the swivel is HUB = (0, -30), the chain CHAIN = 30, the ball BALL = 5):
- flail_post.png   18x36, the origin at (9, 33): a riveted footing plate
  (x -7..7, y -3..1) on the ground, the iron post up to the bearing collar
  under the swivel at y -30.
- flail_chain.png  44x22, the swivel at (2, 11): six links along +x from
  the swivel to the spiked iron ball at (30, 0) (radius 5, six spikes out
  to r 8); the code rotates it to the whirl angle.
- flail_cap.png    10x10, centre (5, 5): the brass swivel cap.
"""
import math
import sys
from clockwork import *
from clockwork import _shade
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]                  # the ball: darker, no bright steel highlights


def ring(fig, c, r, t, mat, z=0):
    """A chain link seen face-on: an oval band r=(rx, ry) of thickness t."""
    cx, cy = c
    rx, ry = r

    def fn(x, y):
        dx, dy = (x - cx) / rx, (y - cy) / ry
        d = math.hypot(dx, dy)
        inner = 1 - t / min(rx, ry)
        if d > 1 or d < inner:
            return None
        k = ((d - inner) / (1 - inner)) * 2 - 1
        ux, uy = dx / (d or 1), dy / (d or 1)
        nx, ny = ux * k * 0.8, uy * k * 0.8
        return _shade((nx, ny, math.sqrt(max(0.05, 1 - nx * nx - ny * ny))), mat, 0.04, int(x * 3), int(y * 3))
    fig.prims.append((z, fn, (cx - rx, cy - ry, cx + rx, cy + ry)))


def post():
    fig = Figure()
    fig.box((-7.4, -3.2, 7.4, 1.0), STEEL, z=0, bevel=0.9)               # the footing plate
    for x in (-5, 5):
        fig.sphere((x, -1.2), 0.8, BRONZE, z=0.1)                        # its rivets
    fig.box((-3.2, -5.6, 3.2, -2.6), STEEL, z=0.2, bevel=0.7)            # the socket
    fig.capsule((0, -4), (0, -27), 1.9, STEEL, z=0.3)                    # the post
    fig.box((-2.4, -16.4, 2.4, -14.6), DARK, z=0.35, bevel=0.4)          # a band
    fig.box((-3.2, -29.8, 3.2, -26.4), STEEL, z=0.4, bevel=0.8)          # the bearing collar
    return fig.render(18, 36, (9, 33))


def chain():
    fig = Figure()
    # links alternate face-on (a band with a hole) and edge-on (a bar)
    xs = [3.5, 7.4, 11.3, 15.2, 19.1, 23.0]
    for i, x in enumerate(xs):
        if i % 2 == 0:
            ring(fig, (x, 0), (2.5, 1.9), 1.0, STEEL, z=0.1)
        else:
            fig.capsule((x - 2.2, 0), (x + 2.2, 0), 0.8, STEEL, z=0.2)
    fig.box((24.6, -1.3, 26.4, 1.3), DARK, z=0.3, bevel=0.4)             # the ball's eye
    # the spiked ball: spikes behind, the ball over them
    for s in range(6):
        a = s * math.tau / 6 + math.tau / 12
        c, n = math.cos(a), math.sin(a)
        px, py = -n, c
        fig.poly([(30 + c * 3.6 + px * 1.6, py * 1.6 + n * 3.6),
                  (30 + c * 8.2, n * 8.2),
                  (30 + c * 3.6 - px * 1.6, -py * 1.6 + n * 3.6)], IRON, z=0.4, shade=0.62)
    fig.sphere((30, 0), 5.0, IRON, z=0.5)
    return fig.render(44, 22, (2, 11))


def cap():
    fig = Figure()
    fig.disc((0, 0), 3.9, STEEL, z=0)
    fig.sphere((0, 0), 2.7, BRONZE, z=0.1)
    fig.sphere((-0.8, -0.8), 0.7, [BRONZE[5], BRONZE[6], BRONZE[7]], z=0.2)
    return fig.render(10, 10, (5, 5))


def main():
    p, c, h = post(), chain(), cap()
    write_png(SPR + 'flail_post.png', 18, 36, p)
    write_png(SPR + 'flail_chain.png', 44, 22, c)
    write_png(SPR + 'flail_cap.png', 10, 10, h)
    print('wrote flail_post.png, flail_chain.png, flail_cap.png')
    if len(sys.argv) > 1:
        # and the three together, as the game shows them (the chain level)
        both = [[(0, 0, 0, 0)] * 52 for _ in range(44)]
        for img, ox, oy in ((p, 0, 8), (c, 7, 0), (h, 4, 6)):
            for y in range(len(img)):
                for x in range(len(img[0])):
                    if img[y][x][3]:
                        both[y + oy][x + ox] = img[y][x]
        big = side_by_side([p, c, h, both], 8)
        write_png(sys.argv[1] + '/flail_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
