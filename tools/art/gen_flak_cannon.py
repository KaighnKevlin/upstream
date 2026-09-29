"""Flak cannon: a squat anti-air mortar on a brass turntable, a riveted
iron plinth under it with a rack of six load sockets along its front, and
a side hopper funnel that feeds pieces down into the breech.

    python3 tools/art/gen_flak_cannon.py [preview_dir]

Writes (all measured from the node origin, the ground surface under the
turntable's centre):
- flak_base.png    40x26, the origin at (20, 24): the plinth (x -16..16,
  y -7..0) with six dark sockets along its front (x -12.5 + 5 i, y -3.5,
  where the code draws the load's pips), the brass turntable ring (y -11
  ..-7) and the trunnion yoke up to the pivot at PIVOT = (0, -16).
- flak_barrel.png  16x24, the pivot at (8, 18): the squat mortar standing
  straight up from its trunnion hub (r 4) to the flared muzzle at y -17
  (MUZZLE = 16 px from the pivot). The code rotates it about PIVOT to the
  aim, 0 = straight up.
- flak_hopper.png  16x26, the origin at (8, 24): placed at (-20, -3),
  behind the plinth. A funnel whose mouth (x -6..6) is at y -22, necking
  down to a feed pipe that elbows into the plinth's side; the code's
  HOPPER (the mouth's centre) is (-20, -25).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IRON = STEEL[:6]


def base():
    fig = Figure()
    fig.box((-16, -7.5, 16, 0), IRON, z=0.1, bevel=1.2, grit=0.08)       # plinth
    fig.box((-16.5, -8.5, 16.5, -6.5), IRON, z=0.2, bevel=0.6)           # top rim
    for i in range(6):
        fig.sphere((-12.5 + 5 * i, -3.5), 1.7, DARK, z=0.25)             # load sockets
    for x in (-15, 15):
        fig.sphere((x, -3.8), 0.6, STEEL, z=0.3)                         # corner rivets
    fig.box((-11, -11.5, 11, -7.2), BRONZE, z=0.35, bevel=1.0)           # turntable ring
    for x in (-8, -4, 0, 4, 8):
        fig.box((x - 0.4, -11, x + 0.4, -8), BRONZE[:4], z=0.4, bevel=0.2)   # ring teeth
    # the trunnion yoke: two cheeks rising to the pivot
    for x in (-7.5, 4.5):
        fig.poly([(x, -11), (x + 3, -11), (x + 3 - 0.5, -18), (x + 0.5, -18)], IRON, z=0.45, shade=0.55)
    return fig.render(40, 26, (20, 24), extra=COPPER_EXTRA)


def barrel():
    fig = Figure()
    fig.capsule((0, -2), (0, -12), 4.6, IRON, z=0.2)                     # the fat tube
    fig.box((-5.4, -8, 5.4, -6.2), BRONZE, z=0.3, bevel=0.6)             # reinforcing band
    fig.box((-6, -17, 6, -13.5), IRON, z=0.35, bevel=0.8)                # flared muzzle
    fig.box((-3.6, -16.6, 3.6, -15.4), DARK, z=0.4, bevel=0.2)           # the bore
    fig.sphere((0, 0), 4.0, BRONZE, z=0.5)                               # trunnion hub
    fig.sphere((0, 0), 1.3, STEEL, z=0.6)
    return fig.render(16, 24, (8, 18), extra=COPPER_EXTRA)


def hopper():
    fig = Figure()
    fig.capsule((0, -8), (0, -2), 1.8, IRON, z=0.1)                      # feed pipe down
    fig.capsule((0, -1.5), (5.5, -1.5), 1.8, IRON, z=0.12)               # elbow into the plinth
    fig.poly([(-6.5, -21), (6.5, -21), (2.2, -9), (-2.2, -9)], IRON, z=0.3, shade=0.5)
    fig.poly([(-5.6, -21), (-3, -21), (-1, -10), (-2, -10)], IRON, z=0.35, shade=0.78)
    fig.box((-7.5, -23, 7.5, -20.5), IRON, z=0.4, bevel=0.6)             # mouth rim
    fig.box((-5, -22.6, 5, -21.2), DARK, z=0.45, bevel=0.2)              # the dark mouth
    fig.box((-7.2, -15.5, -5.5, -14), BRONZE, z=0.42, bevel=0.3)         # a bracket
    return fig.render(16, 26, (8, 24), extra=COPPER_EXTRA)


def main():
    parts = {'flak_base': base(), 'flak_barrel': barrel(), 'flak_hopper': hopper()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side(list(parts.values()), 8)
        write_png(sys.argv[1] + '/flak_cannon_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
