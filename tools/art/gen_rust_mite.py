"""Rust mite: a clockwork tick the size of a rivet. A pitted copper dome
flecked with rust, a steel rivet on top, six iron legs and a red eye.

    python3 tools/art/gen_rust_mite.py [preview_dir]

Writes assets/sprites/rust_mite.png: 4 frames of 14x10 in a row, the node
origin (the dome's centre) at (7, 5) in each, facing +x:
frames 0-1 crawling (the legs step in turn), 2-3 clinging and feeding
(legs splayed above and below, working).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O, N = 14, 10, (7, 5), 4
RED_EXTRA = ['460e0c', 'a01e18', 'e64632', 'ffa082']
RED = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]
LEG = STEEL[1:4]
RUST = [COPPER[0], COPPER[1], COPPER[1]]


def frame(k):
    fig = Figure()
    feeding = k >= 2
    wig = 0.9 if k % 2 == 0 else -0.9
    for i in range(3):
        x = -2.5 + i * 2.5
        w = wig if i % 2 == 0 else -wig      # alternate legs step in turn
        fig.capsule((x, 0.5), (x - 1.8 + w, 3.6), 0.45, LEG, z=-1)
        if feeding:
            fig.capsule((x, -0.5), (x + 1.8 - w, -3.8), 0.45, LEG, z=-1)
        else:
            fig.capsule((x, 0.5), (x + 1.8 - w, 3.6), 0.45, LEG, z=-1.1)
    fig.ellipsoid((0, 0), (3.6, 3.2), COPPER, z=0, grit=0.12)
    for (x, y) in ((-1.8, 1.2), (0.9, 1.6), (-0.6, -1.9)):
        fig.sphere((x, y), 0.55, RUST, z=0.1, grit=0.0)   # rust pits
    fig.sphere((-0.4, -2.6), 0.5, STEEL, z=0.2)            # a rivet on top
    fig.sphere((3.0, -0.8), 1.0, [(255, 40, 30), (255, 40, 30)], z=0.3, emissive=True)
    return fig.render(FW, FH, O, extra=COPPER_EXTRA + RED_EXTRA + ['ff281e', 'ff9678'])


def main():
    frames = [frame(k) for k in range(N)]
    sheet = [sum((fr[y] for fr in frames), []) for y in range(FH)]
    write_png(SPR + 'rust_mite.png', FW * N, FH, sheet)
    print('wrote rust_mite.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 12)
        write_png(sys.argv[1] + '/rust_mite_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
