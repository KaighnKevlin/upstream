"""Mortar crab: a squat, wide clockwork walker carrying a stubby mortar tube
on its back, a range-finder lens, and four short legs that splay out to
brace when it plants.

    python3 tools/art/gen_mortar.py [preview_dir]

Writes assets/sprites/mortar.png: 8 frames of 40x36, facing right, feet at
(18, 35): 0-5 walk, 6 planted (legs braced, tube raised), 7 firing (the
tube kicked back, flash at the muzzle). Planted muzzle: about (+3, -24)
from the feet.
"""
import math, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH, O = 40, 36, (18, 35)
FLASH = [(160, 60, 20), (230, 130, 40), (255, 210, 110), (255, 245, 200)]
EYE = [(70, 14, 12), (160, 30, 24), (230, 70, 50), (255, 160, 130)]


def leg(fig, hip, foot, near):
    knee = ((hip[0] + foot[0]) / 2 + (1.8 if foot[0] > hip[0] else -1.8), min(hip[1], foot[1]) - 2.5)
    mat, z = (STEEL, 6) if near else (DARK, 0.5)
    fig.capsule(hip, knee, 1.3, mat, z=z)
    fig.capsule(knee, foot, 1.1, mat, z=z + 0.1)
    fig.sphere(knee, 1.4, BRONZE if near else DARK, z=z + 0.2)
    fig.ellipsoid((foot[0], foot[1] - 0.4), (2.2, 1.0), BRONZE if near else DARK, z=z + 0.3)


def build(i):
    walk = i < 6
    ph = i / 6 * math.tau if walk else 0.0
    bob = abs(math.sin(ph)) * 0.8 if walk else 0.0
    plant = 0.0 if walk else 1.0
    fig = Figure()
    by = -13 + bob + plant * 2.0            # it squats down when planted
    for k, (hx, spread) in enumerate(((-7, -1), (-3, -1), (3, 1), (7, 1))):
        near = k % 2 == 1
        lift = max(0.0, math.sin(ph + k * math.pi / 2)) * 2.2 if walk else 0.0
        step = math.cos(ph + k * math.pi / 2) * 2.0 if walk else 0.0
        foot = (hx + spread * (2.5 + plant * 3.5) + step, -0.8 - lift)
        leg(fig, (hx * 0.8, by + 3), foot, near)
    # body: a wide riveted shell
    fig.ellipsoid((0, by), (10.5, 5.5), BRONZE, z=2, grit=0.07)
    fig.box((-10, by + 1.5, 10, by + 4.5), DARK, z=2.1, bevel=0.8)
    for x in (-7, -3.5, 0, 3.5, 7):
        fig.sphere((x, by + 3), 0.55, STEEL, z=2.2)
    # range-finder lens at the front
    fig.disc((9.5, by - 1), 2.4, DARK, z=2.3)
    fig.disc((9.8, by - 1), 1.6, EYE, z=2.4, emissive=True)
    # the mortar: a stubby tube on a trunnion, angled up and forward
    ang = math.radians(35 if walk else 62)
    kick = 1.8 if i == 7 else 0.0
    piv = (-2, by - 4.5)
    d = (math.cos(ang), -math.sin(ang))
    base = (piv[0] - d[0] * (3 + kick), piv[1] - d[1] * (3 + kick))
    tip = (piv[0] + d[0] * (9 - kick), piv[1] + d[1] * (9 - kick))
    fig.capsule(base, tip, 3.0, STEEL, z=3)
    fig.capsule((tip[0] - d[0] * 1.5, tip[1] - d[1] * 1.5), tip, 3.5, DARK, z=3.1)   # muzzle ring
    fig.disc(piv, 2.2, BRONZE, z=3.2)
    fig.gear(piv, 1.8, 6, i * 30, STEEL, z=3.3)
    if i == 7:
        m = (tip[0] + d[0] * 3.5, tip[1] + d[1] * 3.5)
        fig.sphere(m, 2.8, FLASH, z=4, emissive=True)
    return fig.render(FW, FH, O, extra=['460e0c', 'a01e18', 'e64632', 'ffa082', 'a03c14', 'e68228', 'ffd26e', 'fff5c8'])


def main():
    frames = [build(i) for i in range(8)]
    write_png(SPR + 'mortar.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote mortar.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/mortar_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
