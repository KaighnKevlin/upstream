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


# Funnel turret (match scenes/funnel_turret.gd): origin = barrel pivot.
# Funnel mouth y=-74 (x +/-24) narrowing to the magazine at y=-60 (x +/-9);
# magazine x=+/-9 from y=-60 to y=-10 (gate); pedestal around the pivot.
TW, TH, TO = 60, 92, (30, 80)


def turret_back():
    fig = Figure()
    fig.poly([(-23, -73), (-8, -59), (-8, -10), (8, -10), (8, -59), (23, -73)], DARK, z=0, shade=0.15)
    return fig.render(TW, TH, TO, outline=False)


def turret_front():
    fig = Figure()
    fig.capsule((-24, -74), (-9, -60), 1.8, BRONZE, z=1)
    fig.capsule((24, -74), (9, -60), 1.8, BRONZE, z=1)
    for x in (-9, 9):
        fig.capsule((x, -60), (x, -10), 1.6, BRONZE, z=1)
    for y in (-46, -30):
        fig.box((-9, y - 0.9, 9, y + 0.9), BRONZE, z=1.2, bevel=0.5)
    fig.box((-11, -62, 11, -58.5), STEEL, z=1.3, bevel=0.8)                 # collar
    fig.box((-11, -11, 11, -7), STEEL, z=1.3, bevel=0.8)                     # breech gate
    # pedestal around the pivot, with the ammo feed chute into the breech
    fig.ellipsoid((0, 2), (11, 5.5), BRONZE, z=1.5)
    fig.box((-8, 2, 8, 9), BRONZE, z=1.4, bevel=1.4)
    fig.disc((0, 1.5), 3.2, DARK, z=1.6)
    fig.sphere((0, 1.5), 2.0, GLOW, z=1.7, emissive=True)
    return fig.render(TW, TH, TO)


def turret_barrel():
    """Ore cannon, pointing +x, pivot at the breech (5, 6)."""
    fig = Figure()
    fig.sphere((1, 0), 4.2, BRONZE, z=0)
    fig.capsule((1, 0), (18, 0), 3.4, BRONZE, z=1)
    for x in (8, 13):
        fig.ellipsoid((x, 0), (0.9, 3.9), STEEL, z=1.5)
    fig.ellipsoid((19.5, 0), (1.8, 4.6), STEEL, z=2)
    fig.ellipsoid((20.8, 0), (0.9, 3.1), DARK, z=2.1, grit=0.0)
    return fig.render(28, 12, (5, 6))


def main():
    parts = {'hopper_back': hopper_back(), 'hopper_front': hopper_front(),
             'trapdoor': trapdoor(), 'spikes': spikes(),
             'turret_back': turret_back(), 'turret_front': turret_front(), 'turret_barrel': turret_barrel()}
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
        tc = [row[:] for row in parts['turret_back']]
        for y, row in enumerate(parts['turret_front']):
            for x, p in enumerate(row):
                if p[3]:
                    tc[y][x] = p
        for y, row in enumerate(parts['turret_barrel']):
            for x, p in enumerate(row):
                if p[3]:
                    tc[TO[1] - 6 + y][TO[0] - 5 + x] = p
        big = side_by_side([tc], 6)
        write_png(sys.argv[1] + '/turret_preview.png', len(big[0]), len(big), big)
        big = side_by_side(plates + [parts['spikes'], parts['trapdoor']], 8)
        write_png(sys.argv[1] + '/traps_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
