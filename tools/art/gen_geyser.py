"""Ore geyser: a mound of crusted rock around a vent, mineral streaks of
copper and rust down its flanks, and a fissure that glows as it builds up
to an eruption.

    python3 tools/art/gen_geyser.py [preview_dir]

Writes assets/sprites/geyser.png: 3 frames of 44x24 (dormant, building,
erupting), bottom centre (22, 23) on the floor; the vent mouth is at
(0, -18) from there.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 44, 24, (22, 23)
CRUST = [(41, 38, 31), (70, 60, 56), (98, 86, 80), (126, 114, 104), (150, 140, 128)]
HOT = [(90, 30, 12), (170, 70, 24), (240, 140, 50), (255, 210, 130)]


def build(stage):
    fig = Figure()
    fig.poly([(-21, 0), (21, 0), (8, -16), (4, -18), (-4, -18), (-9, -15)], CRUST, z=0, shade=0.8)
    fig.poly([(-17, 0), (-9, -14), (-6, -13), (-12, 0)], CRUST, z=0.1, shade=0.5)
    # mineral streaks: copper green-blue and rust
    for (x0, y0, x1, y1, col) in ((-6, -15, -11, -4, [(40, 110, 100), (80, 170, 150)]),
                                  (5, -16, 10, -6, [(120, 50, 20), (180, 90, 40)]),
                                  (1, -17, 2, -8, [(40, 110, 100), (80, 170, 150)])):
        fig.capsule((x0, y0), (x1, y1), 0.8, col, z=0.3)
    # the vent mouth
    fig.ellipsoid((0, -17.5), (5, 1.8), DARK, z=0.5)
    if stage == 0:
        fig.ellipsoid((0, -17.3), (3, 0.8), [(60, 30, 16), (90, 44, 20)], z=0.6)
    else:
        glow = 3.2 if stage == 1 else 4.4
        fig.ellipsoid((0, -17.4), (glow, 1.2), HOT, z=0.6, emissive=True)
        for x in (-7, 6):
            fig.capsule((x * 0.5, -16), (x, -8 - stage * 2), 0.5, HOT, z=0.55)   # glowing cracks
    for x in (-15, 13):
        fig.sphere((x, -2), 1.4, CRUST, z=0.2)
    return fig.render(FW, FH, O, extra=['463c38', '625650', '7e7268', '968c80', '286e64', '50aa96', '783214', 'b45a28', '5a1e0c', 'aa4618', 'f08c32', 'ffd282'])


def main():
    frames = [build(s) for s in range(3)]
    write_png(SPR + 'geyser.png', FW * 3, FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote geyser.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/geyser_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
