"""Domino slab: a tall thin brass plate with a dark edge and two rivet pips.

    python3 tools/art/gen_domino.py

Writes assets/sprites/domino.png: 8x28, centred (the body's centre).
"""
from clockwork import *
from pixtools import write_png
from titan_lib import SPR


def build():
    fig = Figure()
    fig.box((-3, -13.5, 3, 13.5), BRONZE, z=0, bevel=0.9, grit=0.05)
    fig.box((-3, -0.5, 3, 0.5), DARK, z=0.1, bevel=0.2)
    for y in (-7, 7):
        fig.sphere((0, y), 1.0, STEEL, z=0.2)
    return fig.render(8, 28, (4, 14))


if __name__ == '__main__':
    write_png(SPR + 'domino.png', 8, 28, build())
    print('wrote domino.png')
