"""Steam borer: a squat brass boiler drum on a tracked chassis, a smokestack,
and a spiral-fluted steel drill cone out front.

    python3 tools/art/gen_borer.py [preview_dir]

Writes assets/sprites/borer.png: 4 frames of 40x28, facing right, the
machine's centre at (18, 16) (the middle of the 2-tile-high tunnel it cuts
when facing sideways): the drill's flutes and the tracks advance each frame.
The drill tip reaches about (+20, 0) from the centre.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

W, H, O = 40, 28, (18, 16)


def build(i):
    fig = Figure()
    # tracks: a rounded belt with lugs that crawl along
    fig.capsule((-12, 8), (8, 8), 3.4, DARK, z=0)
    for k in range(7):
        x = -13 + ((k * 3.6 + i * 0.9) % 23)
        fig.box((x - 0.6, 10.2, x + 0.6, 11.6), STEEL, z=0.1, bevel=0.2)
    for x in (-10, -2, 6):
        fig.disc((x, 8), 2.2, STEEL, z=0.2)
    # boiler drum
    fig.ellipsoid((-3, -1), (11, 7), BRONZE, z=1, grit=0.07)
    for x in (-10, -3, 4):
        fig.capsule((x, -7.5), (x, 5.5), 0.55, STEEL, z=1.1)   # bands
    fig.disc((-6, -1), 2.2, DARK, z=1.2)                        # pressure gauge
    fig.disc((-6, -1), 1.5, GLOW, z=1.3, emissive=True)
    # smokestack
    fig.box((-11, -13, -8, -6), DARK, z=0.9, bevel=0.4)
    fig.box((-12, -14, -7, -12.5), STEEL, z=0.95, bevel=0.3)
    # drill: a cone with spiral flutes
    base_x, tip_x = 7.0, 21.0
    for k in range(10):
        t = k / 9
        x = base_x + (tip_x - base_x) * t
        r = 6.2 * (1 - t) + 0.6
        fig.ellipsoid((x, 0), (1.2, r), STEEL, z=2 + t * 0.01, grit=0.04)
    for k in range(5):
        ph = k * 0.8 + i * 0.4
        for s in range(6):
            t = (s + (ph % 1.0)) / 6
            x = base_x + (tip_x - base_x) * t
            r = 6.2 * (1 - t) + 0.6
            y = math.sin(ph * 2 + t * 9) * r * 0.85
            fig.sphere((x, y), 0.55, DARK, z=2.1)
    fig.disc((base_x - 0.5, 0), 3.0, BRONZE, z=2.2)                # collar
    fig.gear((base_x - 0.5, 0), 2.6, 8, i * 22, STEEL, z=2.3)
    return fig.render(W, H, O)


def main():
    frames = [build(i) for i in range(4)]
    write_png(SPR + 'borer.png', W * 4, H, [sum((f[y] for f in frames), []) for y in range(H)])
    print('wrote borer.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/borer_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
