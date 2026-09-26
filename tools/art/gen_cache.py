"""Salvage cache: a strapped brass strongbox left in a cave, locked. Touch
it and the lid springs open on a glowing haul.

    python3 tools/art/gen_cache.py [preview_dir]

Writes assets/sprites/cache.png: 2 frames of 36x28 (closed, open), the
bottom centre (18, 27) sitting on the floor.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 36, 28, (18, 27)
AMBER = [(120, 60, 20), (200, 120, 40), (255, 190, 90), (255, 236, 170)]


def build(open_):
    fig = Figure()
    for x in (-10, 10):
        fig.ellipsoid((x, -1.2), (3.2, 1.2), DARK, z=0)
    # the strongbox body
    fig.box((-13, -12, 13, -2), BRONZE, z=1, bevel=1.5, grit=0.08)
    fig.box((-13.5, -3.5, 13.5, -1.5), DARK, z=1.1, bevel=0.5)
    for x in (-8, 8):
        fig.box((x - 1.2, -12, x + 1.2, -2), STEEL, z=1.2, bevel=0.4)   # straps
        fig.sphere((x, -5), 0.55, BRONZE, z=1.3)
    if open_:
        # lid tipped back, contents glowing
        fig.poly([(-13, -12), (-11, -22), (11, -24), (13, -13)], BRONZE, z=0.5, shade=0.55)
        fig.capsule((-11, -22), (11, -24), 0.8, STEEL, z=0.6)
        fig.box((-11, -13, 11, -10), AMBER, z=1.4, bevel=0.5)
        for x in (-6, -1, 5):
            fig.sphere((x, -13), 1.6, AMBER, z=1.5, emissive=True)
    else:
        # domed lid, strapped, with a lock plate
        fig.ellipsoid((0, -12), (13.5, 4.5), BRONZE, z=1.4, grit=0.05)
        for x in (-8, 8):
            fig.capsule((x, -16), (x, -11), 1.2, STEEL, z=1.5)
        fig.box((-2.5, -12, 2.5, -6.5), STEEL, z=1.6, bevel=0.6)
        fig.capsule((0, -10.5), (0, -8.5), 0.5, DARK, z=1.7)                 # keyhole
        fig.sphere((-10.5, -14.5), 0.7, [(255, 240, 200)] * 2, z=1.7, emissive=True)   # glint
    return fig.render(FW, FH, O, extra=['783c14', 'c87828', 'ffbe5a', 'ffecaa'])


def main():
    frames = [build(False), build(True)]
    write_png(SPR + 'cache.png', FW * 2, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote cache.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/cache_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
