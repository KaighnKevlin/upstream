"""The base: brass plinth, glass dome with brass ribs, and the dome cannon.

    python3 tools/art/gen_dome.py [preview_dir]

All in world px around the dome centre on the ground (0, 0) = (1200, 96):
  dome_base.png   176x18  plinth, top at y=-12; centre it at (0, -4)
  dome_glass.png  152x46  glass hemisphere (drawn translucent in game); centre (0, -34)
  dome_ribs.png   152x46  brass ribs + crown ring, same placement as the glass
  cannon_base.png 20x12   pedestal on the crown; centre (0, -60)
  cannon_barrel.png 30x10 barrel pointing right, pivot at the breech (3, 5)
"""
import math, sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png
from titan_lib import SPR, side_by_side

GLASS = [_hex(h) for h in ('3a494a', '5f7c83', '709092', '90bcc4', 'abd3d4', 'cde3dc')]
R_X, R_Y, EQ = 72.0, 44.0, -12.0   # dome ellipse radii and the equator's y


def base():
    fig = Figure()
    fig.box((-86, -12, 86, 2), BRONZE, z=0, bevel=2.0)                        # plinth
    fig.box((-86, -12, 86, -9), BRONZE, z=0.5, bevel=1.0, grit=0.04)          # top rail
    for x in range(-80, 81, 10):                                              # rivets
        fig.sphere((x, -4), 0.8, STEEL, z=1)
    # intake grate over the shaft (ingots come up through here)
    fig.box((-40, -11, 40, -1), DARK, z=1.5, bevel=0.8)
    for x in range(-36, 37, 6):
        fig.capsule((x, -10), (x, -2), 0.8, STEEL, z=2)
    # vents with glowing windows either side
    for x in (-64, 64):
        fig.disc((x, -5.5), 4.0, DARK, z=1.5)
        fig.sphere((x, -5.5), 2.8, GLOW, z=1.6, emissive=True)
    return fig.render(176, 18, (88, 13))


def _meridians(fig, mat, r, z):
    for phi in (-90, -58, -28, 0, 28, 58, 90):
        sp = math.sin(math.radians(phi))
        prev = None
        for k in range(0, 19):
            lat = math.radians(k * 5)
            p = (R_X * sp * math.cos(lat), EQ - R_Y * math.sin(lat))
            if prev: fig.capsule(prev, p, r, mat, z=z)
            prev = p


def glass():
    fig = Figure()
    fig.ellipsoid((0, EQ), (R_X, R_Y), GLASS, z=0, grit=0.02)
    # specular streak on the upper left, so it reads as glass
    fig.ellipsoid((-30, EQ - 30), (16, 4), GLASS, z=1, emissive=True, tilt=-28)
    fig.ellipsoid((-44, EQ - 16), (5, 2), GLASS, z=1, emissive=True, tilt=-55)
    return fig.render(152, 46, (76, 57), outline=False)


def ribs():
    fig = Figure()
    _meridians(fig, BRONZE, 1.3, 1)
    fig.ellipsoid((0, EQ - R_Y + 1), (10, 3.5), BRONZE, z=2)                  # crown ring
    for k in range(0, 36):                                                    # equator band
        a0, a1 = math.radians(k * 5), math.radians(k * 5 + 5)
        fig.capsule((-R_X * math.cos(a0), EQ), (-R_X * math.cos(a1), EQ), 1.6, BRONZE, z=1.5)
    return fig.render(152, 46, (76, 57), outline=False)


def cannon_base():
    fig = Figure()
    fig.ellipsoid((0, 2), (9, 3), DARK, z=0)
    fig.box((-6, -4, 6, 3), BRONZE, z=1, bevel=1.5)
    fig.sphere((0, -3), 4.2, BRONZE, z=2)                                     # swivel ball
    fig.sphere((0, -3), 1.4, GLOW, z=3, emissive=True)
    return fig.render(20, 12, (10, 7))


def cannon_barrel():
    fig = Figure()
    fig.box((-2.5, -3.6, 5, 3.6), BRONZE, z=0, bevel=1.4)                    # breech block
    fig.sphere((1.2, 0), 1.3, GLOW, z=0.5, emissive=True)                    # pressure core
    fig.capsule((4, 0), (22, 0), 2.3, BRONZE, z=1)                           # barrel
    for k in range(4):                                                        # cooling fins
        fig.ellipsoid((7 + k * 2.2, 0), (0.7, 3.4), STEEL, z=1.5)
    fig.ellipsoid((17, 0), (0.8, 2.9), STEEL, z=1.5)                          # band
    fig.box((22, -3.4, 26, 3.4), STEEL, z=2, bevel=1.0)                       # muzzle brake
    for y in (-2.0, 2.0):
        fig.box((23.2, y - 0.5, 24.8, y + 0.5), DARK, z=2.1, bevel=0.2, grit=0.0)  # vent slots
    fig.disc((26.2, 0), 1.3, DARK, z=2.2)
    return fig.render(30, 10, (3, 5))


def main():
    parts = {'dome_base': base(), 'dome_glass': glass(), 'dome_ribs': ribs(),
             'cannon_base': cannon_base(), 'cannon_barrel': cannon_barrel()}
    for name, img in parts.items():
        write_png(SPR + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(parts))
    if len(sys.argv) > 1:
        # composite preview, roughly as in game
        W, H = 180, 110
        canvas = [[(24, 24, 30, 255)] * W for _ in range(H)]
        def put(img, cx, cy, alpha=1.0):
            h, w = len(img), len(img[0])
            for y in range(h):
                for x in range(w):
                    p = img[y][x]
                    if p[3]:
                        X, Y = int(cx - w / 2 + x), int(cy - h / 2 + y)
                        if 0 <= X < W and 0 <= Y < H:
                            b = canvas[Y][X]
                            canvas[Y][X] = tuple(int(b[i] * (1 - alpha) + p[i] * alpha) for i in range(3)) + (255,)
        ox, oy = 90, 100
        put(parts['dome_glass'], ox, oy - 34, 0.45)
        put(parts['dome_ribs'], ox, oy - 34)
        put(parts['dome_base'], ox, oy - 4)
        put(parts['cannon_base'], ox, oy - 60)
        put(parts['cannon_barrel'], ox + 12, oy - 63)
        big = side_by_side([canvas], 5)
        write_png(sys.argv[1] + '/dome_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
