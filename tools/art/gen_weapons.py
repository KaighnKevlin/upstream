"""The prospector's blunderbuss, its muzzle flash, and the brass shot.

    python3 tools/art/gen_weapons.py [preview_dir]

assets/sprites/blunderbuss.png  28x12, pointing right; the grip is at (7, 7)
                                 (the game offsets the sprite so it's the pivot)
assets/sprites/muzzle_flash.png 3 frames of 20x16, the burst starts at x=0, y=8
assets/sprites/shot.png          8x4 brass slug with a short hot trail, moving +x
"""
import math, sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

WOOD = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c', '8d7051')]
FLASH_EXTRA = ['fff1c8', 'ffd27a', 'f5a55a']
FLASH = [_hex(h) for h in ('d27434', 'f5a55a', 'ffd27a', 'fff1c8')]


def gun():
    fig = Figure()
    # stock and grip (wood), steel trigger guard
    fig.capsule((1, 7.5), (8, 5.5), 2.0, WOOD, z=0, grit=0.12)
    fig.capsule((6.5, 6), (6, 9.5), 1.3, WOOD, z=0.5)
    fig.capsule((8, 8.5), (10.5, 8.5), 0.5, STEEL, z=0.6)
    # brass lock plate with a little cyan pressure gauge
    fig.box((7.5, 3.5, 13, 7.5), BRONZE, z=1, bevel=1.0)
    fig.disc((10.5, 5.5), 1.5, DARK, z=1.2)
    fig.sphere((10.5, 5.5), 1.0, GLOW, z=1.3, emissive=True)
    # barrel flaring into a bell, steel bands
    fig.capsule((12, 4.5), (22, 4.5), 1.5, BRONZE, z=2)
    for k in range(5):
        fig.ellipsoid((22 + k * 0.9, 4.5), (0.8, 1.6 + k * 0.45), BRONZE, z=2.1 + k * 0.01)
    fig.ellipsoid((26.2, 4.5), (0.9, 3.5), DARK, z=2.3, grit=0.0)          # bore
    fig.ellipsoid((15, 4.5), (0.7, 1.9), STEEL, z=2.4)
    fig.ellipsoid((19.5, 4.5), (0.7, 1.9), STEEL, z=2.4)
    return fig.render(28, 12, (0, 0))


def flash(k):
    fig = Figure()
    L = [9, 14, 11][k]
    rr = [3.5, 5.0, 4.0][k]
    if k < 2:
        fig.ellipsoid((L * 0.45, 8), (L * 0.5, rr), FLASH, z=0, emissive=True)
        for a in (-40, -15, 15, 40):  # spikes
            t = math.radians(a)
            fig.capsule((2, 8), (2 + math.cos(t) * L, 8 + math.sin(t) * L * 0.6), 0.8, FLASH, z=1)
        fig.sphere((2, 8), 2.5 - k * 0.5, [FLASH[-1]] * 2, z=2, emissive=True)
    else:  # smoke puff drifting off
        for dx, dy, r in ((5, 8, 3.2), (9, 6.5, 2.6), (12, 9, 2.2)):
            fig.sphere((dx, dy), r, ROCK, z=0, grit=0.1)
    return fig.render(20, 16, (0, 0), extra=FLASH_EXTRA, outline=(k == 2))


def shot():
    fig = Figure()
    fig.capsule((0.5, 2), (4, 2), 0.6, FLASH, z=0)           # hot trail
    fig.sphere((5.5, 2), 1.5, BRONZE, z=1)
    return fig.render(8, 4, (0, 0), extra=FLASH_EXTRA, outline=False)


def main():
    g = gun()
    write_png(SPR + 'blunderbuss.png', 28, 12, g)
    fl = [flash(k) for k in range(3)]
    rows = [sum((f[y] for f in fl), []) for y in range(16)]
    write_png(SPR + 'muzzle_flash.png', 60, 16, rows)
    write_png(SPR + 'shot.png', 8, 4, shot())
    print('wrote blunderbuss.png, muzzle_flash.png, shot.png')
    if len(sys.argv) > 1:
        big = side_by_side([g], 10)
        write_png(sys.argv[1] + '/blunderbuss_preview.png', len(big[0]), len(big), big)
        big = side_by_side(fl, 10)
        write_png(sys.argv[1] + '/flash_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
