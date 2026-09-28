"""Flap sorter: a riveted steel-and-brass rail that tiles along any length,
brass trap flaps on steel hinge knuckles, and the stop post at its high end.

    python3 tools/art/gen_flaps.py [preview_dir]

Writes (all drawn along the rail's direction, rotated in code):
- flap_rail.png   16x8 tile, repeats along x: the running surface (steel)
  is on rows 1-3, the brass web below. The code puts row 2 on the rail line.
- flap_plate.png  22x8, the hinge pin at (3, 3); the plate runs +x from it
  for 18 px with its top face on row 1-2, like the rail's.
- flap_stop.png   7x12, the post that closes the high end, its foot (the
  rail line at the high end) at (3, 10).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def rail():
    fig = Figure()
    # run the parts past both edges so the tile's sides have no outline
    fig.box((-4, -1.2, 20, 1.2), STEEL, z=1, bevel=0.8, grit=0.03)          # running surface
    fig.box((-4, 1.2, 20, 4.2), BRONZE, z=0, bevel=0.7, grit=0.04)          # web
    fig.capsule((-4, 3.9), (20, 3.9), 0.5, DARK, z=0.1)                      # lower flange shadow
    for x in (4, 12):
        fig.sphere((x, 2.6), 0.65, STEEL, z=0.3)                            # rivets, period 8
    return fig.render(16, 8, (0, 2))


def plate():
    fig = Figure()
    fig.box((0, -1.4, 18, 1.8), BRONZE, z=0, bevel=0.8)
    fig.capsule((5, 0.2), (16, 0.2), 0.35, [(99, 76, 54)] * 2, z=0.1)      # a pressed stiffening rib
    fig.sphere((16.3, 0.2), 0.6, STEEL, z=0.2)
    fig.disc((0, 0), 2.4, STEEL, z=0.5)                                     # hinge knuckle
    fig.sphere((0, 0), 0.9, BRONZE, z=0.6)
    return fig.render(22, 8, (3, 3), extra=['634c36'])


def stop():
    fig = Figure()
    fig.box((-1.4, -8, 1.4, 1), STEEL, z=0, bevel=0.6)
    fig.box((-2.2, -9.2, 2.2, -7.2), BRONZE, z=0.1, bevel=0.5)
    fig.sphere((0, -3.5), 0.55, BRONZE, z=0.2)
    return fig.render(7, 12, (3, 10))


def main():
    r, p, s = rail(), plate(), stop()
    write_png(SPR + 'flap_rail.png', 16, 8, r)
    write_png(SPR + 'flap_plate.png', 22, 8, p)
    write_png(SPR + 'flap_stop.png', 7, 12, s)
    print('wrote flap_rail.png, flap_plate.png, flap_stop.png')
    if len(sys.argv) > 1:
        rr = [sum((row for _ in range(4)), []) for row in r]   # the rail tiled x4
        big = side_by_side([rr, p, s], 8)
        write_png(sys.argv[1] + '/flaps_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
