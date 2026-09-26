"""Vault sentinel: a clockwork guardian eye hanging from a ruin's ceiling. A
riveted brass housing on a steel mount, gear crowns either side, a short
barrel under a big lens behind an iris shutter.

    python3 tools/art/gen_sentinel.py [preview_dir]

Writes assets/sprites/sentinel.png: 4 frames of 44x36, mount point at
(22, 0) (the ceiling): 0 = dormant (shutter shut, lens dark), 1 = waking
(half open), 2-3 = awake (lens burning, gears turned). The lens centre is
about (0, +18) from the mount; the muzzle about (0, +29).
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 44, 36, (22, 0)
LENS = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]


def build(i):
    fig = Figure()
    fig.box((-8, 0, 8, 4), DARK, z=0, bevel=0.8)                        # ceiling plate
    fig.capsule((0, 3), (0, 8), 2.2, STEEL, z=0.5)                      # mount stem
    for side in (-1, 1):                                                 # gear crowns
        fig.gear((side * 13, 15), 5.0, 10, i * 18 * side, STEEL, z=0.8, hub_mat=BRONZE)
    fig.ellipsoid((0, 17), (11, 9.5), BRONZE, z=1, grit=0.07)           # housing
    for a in range(0, 360, 45):
        r = math.radians(a)
        fig.sphere((math.cos(r) * 9.3, 17 + math.sin(r) * 8), 0.6, STEEL, z=1.1)
    fig.capsule((0, 24), (0, 29), 1.8, DARK, z=1.2)                     # barrel
    fig.disc((0, 17), 5.6, DARK, z=1.3)                                 # lens socket
    if i >= 1:
        rad = 2.6 if i == 1 else 4.4
        fig.sphere((0, 17), rad, LENS, z=1.4, emissive=True)
    if i <= 1:                                                           # iris shutter blades
        gap = 0.0 if i == 0 else 2.2
        for side in (-1, 1):
            fig.box((-5.4 if side < 0 else gap, 12.4, -gap if side < 0 else 5.4, 21.6), STEEL, z=1.5, bevel=0.5)
    return fig.render(W, H, O, extra=['460e0c', 'a01e18', 'e64632', 'ffa082'])


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'sentinel.png', W * 4, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote sentinel.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/sentinel_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
