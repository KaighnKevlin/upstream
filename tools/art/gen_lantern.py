"""Miner's lantern: a brass cage lantern hanging from an iron hook on a short
bracket, glass panes, a carbide flame inside.

    python3 tools/art/gen_lantern.py [preview_dir]

Writes assets/sprites/lantern.png: 3 frames of 16x22, the hook point at
(8, 0): the flame flickers between them. The flame's centre is about
(0, +13) from the hook.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 16, 22, (8, 0)
FLAME = [(200, 90, 30), (240, 150, 50), (255, 215, 120), (255, 248, 210)]


def build(i):
    fig = Figure()
    fig.capsule((0, 0.5), (0, 3.5), 0.6, DARK, z=0)                 # hook
    fig.box((-3.5, 3.5, 3.5, 5.5), BRONZE, z=1, bevel=0.5)          # cap
    fig.box((-4.5, 5.2, 4.5, 6.4), BRONZE, z=1.1, bevel=0.3)
    fig.box((-3.8, 6.3, 3.8, 17.5), DARK, z=0.5, bevel=0.5)         # the glass (dark behind the flame)
    for x in (-3.9, 3.9):
        fig.capsule((x, 6.3), (x, 17.5), 0.55, BRONZE, z=1.2)       # cage bars
    fig.capsule((0, 6.3), (0, 17.5), 0.35, BRONZE, z=1.25)
    fig.box((-4.5, 17.3, 4.5, 19.5), BRONZE, z=1.1, bevel=0.5)      # base
    fig.box((-2.5, 19.3, 2.5, 20.8), DARK, z=1.0, bevel=0.3)
    h = [2.9, 3.4, 2.6][i]
    fig.ellipsoid((0.15 * (i - 1), 13.2 - h * 0.3), (1.7, h), FLAME, z=1.15, emissive=True)
    return fig.render(W, H, O, extra=['c85a1e', 'f09632', 'ffd778', 'fff8d2'])


def main():
    frames = [build(i) for i in range(3)]
    write_png(SPR + 'lantern.png', W * 3, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote lantern.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 10)
        write_png(sys.argv[1] + '/lantern_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
