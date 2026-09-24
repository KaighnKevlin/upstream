"""Trap parts: drop hopper, pressure plate, spikes.

    python3 tools/art/gen_traps.py [preview_dir]

Hopper coordinates (match scenes/hopper.gd): origin = centre of the bin.
Funnel mouth at y=-34 (x +/-26) narrowing to the bin at y=-18 (x +/-11);
bin walls x=+/-11 from y=-18 to y=26; trapdoor along y=26.
  hopper_back.png  64x72, origin (32, 38): dark interior, drawn behind the ore
  hopper_front.png 64x72, origin (32, 38): brass funnel lip, cage bars and
                   bands (ore shows between them), drawn over the ore
  trapdoor.png     12x4: one leaf, hinge at its left end (0, 2)
  plate.png        2 frames of 28x8 (up, pressed); origin bottom-centre
  spikes.png       16x15, sits on the floor (bottom edge)
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

HW, HH, HO = 64, 72, (32, 38)
FUNNEL = [(-26, -34), (-11, -18), (11, -18), (26, -34)]


def hopper_back():
    fig = Figure()
    fig.poly([(-25, -33), (-10, -17), (-10, 25), (10, 25), (10, -17), (25, -33)], DARK, z=0, shade=0.15)
    for x, y in ((-6, -8), (6, -8), (-6, 12), (6, 12)):
        fig.sphere((x, y), 0.8, DARK, z=0.5)                                   # back-plate rivets
    return fig.render(HW, HH, HO, outline=False)


def hopper_front():
    fig = Figure()
    # funnel lips (thick brass edges), mouth rim
    fig.capsule((-26, -34), (-11, -18), 1.8, BRONZE, z=1)
    fig.capsule((26, -34), (11, -18), 1.8, BRONZE, z=1)
    fig.capsule((-27, -35), (-22, -35), 1.6, BRONZE, z=1.1)
    fig.capsule((27, -35), (22, -35), 1.6, BRONZE, z=1.1)
    # cage: side posts, bands across the front, top collar
    for x in (-11, 11):
        fig.capsule((x, -18), (x, 26), 1.7, BRONZE, z=1)
    for y in (-4, 12):
        fig.box((-11, y - 1, 11, y + 1), BRONZE, z=1.2, bevel=0.6)
    fig.box((-13, -20, 13, -16.5), STEEL, z=1.3, bevel=0.8)
    fig.box((-13, 25, -9, 28), STEEL, z=1.3, bevel=0.6)                          # hinge blocks
    fig.box((9, 25, 13, 28), STEEL, z=1.3, bevel=0.6)
    fig.sphere((13.5, 2), 1.4, GLOW, z=1.4, emissive=True)                      # armed lamp
    return fig.render(HW, HH, HO)


def trapdoor():
    fig = Figure()
    fig.box((0, -1.3, 11, 1.3), BRONZE, z=0, bevel=0.6)
    fig.sphere((0.8, 0), 0.7, STEEL, z=1)
    return fig.render(12, 4, (0, 2))


def plate(pressed):
    fig = Figure()
    fig.box((-13, -3, 13, 0), DARK, z=0, bevel=0.8)                             # frame
    top = -4.5 + (1.5 if pressed else 0)
    fig.box((-11, top, 11, top + 2.2), BRONZE, z=1, bevel=0.7)
    for x in (-8, 0, 8):
        fig.sphere((x, top + 1.1), 0.5, STEEL, z=1.1)
    return fig.render(28, 8, (14, 7))


def spikes():
    fig = Figure()
    fig.box((-8, -2.5, 8, 0), BRONZE, z=0, bevel=0.7)
    for x in (-5, 0, 5):
        fig.poly([(x - 2.2, -2), (x, -13), (x + 2.2, -2)], STEEL, z=1, shade=0.8)
        fig.poly([(x, -13), (x + 2.2, -2), (x + 0.3, -2)], STEEL, z=1.1, shade=0.35)  # shaded side
    return fig.render(16, 15, (8, 15))


def main():
    parts = {'hopper_back': hopper_back(), 'hopper_front': hopper_front(),
             'trapdoor': trapdoor(), 'spikes': spikes()}
    for name, img in parts.items():
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    plates = [plate(False), plate(True)]
    write_png(SPR + 'plate.png', 56, 8, [plates[0][y] + plates[1][y] for y in range(8)])
    print('wrote', ', '.join(parts), 'plate')
    if len(sys.argv) > 1:
        comp = [row[:] for row in parts['hopper_back']]
        for y, row in enumerate(parts['hopper_front']):
            for x, p in enumerate(row):
                if p[3]:
                    comp[y][x] = p
        big = side_by_side([comp], 6)
        write_png(sys.argv[1] + '/hopper_preview.png', len(big[0]), len(big), big)
        big = side_by_side(plates + [parts['spikes'], parts['trapdoor']], 8)
        write_png(sys.argv[1] + '/traps_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
