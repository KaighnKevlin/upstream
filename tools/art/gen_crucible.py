"""Crucible: a fat clay pot sitting in the ring of an iron tripod, a tap
hole low on its +x side (the code mirrors the sprite for side -1).

    python3 tools/art/gen_crucible.py [preview_dir]

Writes (from the piece's origin, the middle of its feet):
- crucible.png  40x48, origin at (20, 46): the pot's rim at y -43..-39
  (+-15), its dark mouth at y -41 (+-12), the belly (+-15 at y -28) down
  to y -16, the tap hole at x 14..19, y -22..-18, the stand's ring at
  y -17..-14 and its legs splayed to the feet on y 0.
"""
import sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

CLAY_EXTRA = ['3b2419', '5e3624', '7f4a31', '9c6242', 'b87f58', 'd29f76']
CLAY = [_hex(h) for h in CLAY_EXTRA]


def pot():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 8, -15), (s * 14, -1), 1.3, STEEL, z=0.1)            # the tripod's legs
        fig.box((s * 14 - 2.5, -1.5, s * 14 + 2.5, 0), STEEL, z=0.2, bevel=0.5)
    fig.capsule((0, -14), (0, -2), 1.1, STEEL, z=0.05)                         # the back leg
    fig.ellipsoid((0, -28), (15, 12.5), CLAY, z=0.3)                           # the belly
    fig.box((-15.5, -43.5, 15.5, -38.5), CLAY, z=0.4, bevel=1.4)                # the rim
    fig.ellipsoid((0, -41), (12, 2.0), DARK, z=0.5)                            # the mouth
    fig.box((12.5, -22.5, 19, -17.5), CLAY, z=0.45, bevel=1.0)                  # the tap
    fig.ellipsoid((17.8, -20), (1.3, 1.8), DARK, z=0.5)                        # its hole
    fig.box((-13, -17.5, 13, -14), STEEL, z=0.6, bevel=0.8)                     # the stand's ring
    for x in (-9, 0, 9):
        fig.sphere((x, -15.8), 0.6, BRONZE, z=0.7)
    return fig.render(40, 48, (20, 46), extra=CLAY_EXTRA)


def main():
    img = pot()
    write_png(SPR + 'crucible.png', len(img[0]), len(img), img)
    print('wrote crucible.png')
    if len(sys.argv) > 1:
        big = side_by_side([img], 8)
        write_png(sys.argv[1] + '/crucible_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
