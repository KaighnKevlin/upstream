"""Escapement: a brass escape wheel, the pallet fork that rocks under it
(two arms with steel pallets), and the steel gate pin that lifts to let a
marble through.

    python3 tools/art/gen_escapement.py [preview_dir]

Writes (each rotated/moved in code; the arbor is at (0, -24) in the piece):
- escapement_wheel.png  14x14, the arbor at the centre (7, 7), radius 5.
- escapement_fork.png   14x14, the arbor at (7, 3); the arms reach down to
  (+-3.8, 7) from it, as the fork hangs at rest.
- escapement_pin.png    7x22, the pin runs y -14..4 in the piece: (3, 16)
  is the piece's origin when the gate is shut.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def wheel():
    fig = Figure()
    fig.gear((0, 0), 4.6, 8, 0, BRONZE, z=0, hub_mat=STEEL)
    return fig.render(14, 14, (7, 7))


def fork():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((0, 0), (s * 3.8, 7), 0.9, BRONZE, z=0)
        fig.box((s * 3.8 - 1.2, 6.2, s * 3.8 + 1.2, 8.6), STEEL, z=0.1, bevel=0.5)
    fig.sphere((0, 0), 1.4, STEEL, z=0.2)
    return fig.render(14, 14, (7, 3))


def pin():
    fig = Figure()
    fig.box((-1, -13, 1, 4), STEEL, z=0, bevel=0.6)
    fig.box((-1.9, -15, 1.9, -12.5), BRONZE, z=0.1, bevel=0.6)
    return fig.render(7, 22, (3, 16))


def main():
    w, f, p = wheel(), fork(), pin()
    write_png(SPR + 'escapement_wheel.png', 14, 14, w)
    write_png(SPR + 'escapement_fork.png', 14, 14, f)
    write_png(SPR + 'escapement_pin.png', 7, 22, p)
    print('wrote escapement_wheel.png, escapement_fork.png, escapement_pin.png')
    if len(sys.argv) > 1:
        big = side_by_side([w, f, p], 10)
        write_png(sys.argv[1] + '/escapement_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
