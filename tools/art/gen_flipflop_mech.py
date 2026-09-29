"""Flip-flop, as a real marble-machine part: an oak A-frame with steel funnel
lips, a brass see-saw on a steel pin, and an over-centre detent: an iron cam
lobe hangs under the see-saw's hub and a brass leaf spring with a roller on
its tip presses up against it. Whichever way the see-saw lies, the roller
sits beside the lobe and holds it there; a marble landing on the raised side
tips it over, the lobe shoves the roller down as it swings past centre (the
spring bends) and the roller snaps back up behind it: click.

    python3 tools/art/gen_flipflop_mech.py [preview_dir]

Writes (all measured from the pivot, the node origin; y down):
- flipflop_frame.png   44x44, the pivot at (22, 28): the A-frame from the
  bearing at the pivot down to a foot plate on the row +14, the funnel lips
  (+-18, -24) -> (+-10, -12) on brass clamps, and the spring's clamp block
  on the left foot at (-9, 11).
- flipflop_rocker.png  36x18, the pivot at (18, 5): the see-saw beam
  x -15..15 whose top is the pivot's row (the code rotates it by its tilt),
  the steel end caps, the hub, and the iron cam lobe hanging to y +7.5.
- flipflop_spring.png  5 frames of 22x16 (hframes = 5), the pivot at
  (11, 0) in each: the leaf spring from its clamp at (-9, 11.5) to the
  roller, which sits at y 6.8 (frame 0, relaxed: the see-saw lies over)
  down to y 9.2 (frame 4, squashed: the lobe straight down, mid-tip).
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]
FRAMES = 5


def frame():
    fig = Figure()
    for s in (-1, 1):
        fig.capsule((s * 1.2, 2), (s * 7.5, 13), 1.4, OAK, z=0, grit=0.1)   # oak legs
    fig.box((-10, 12.3, 10, 14.8), IRON, z=0.2, bevel=0.6)               # foot plate
    for x in (-7, 7):
        fig.sphere((x, 13.5), 0.6, BRONZE, z=0.3)                        # bolts
    fig.box((-11, 10, -7.4, 12.6), IRON, z=0.35, bevel=0.5)              # the spring's clamp
    fig.sphere((-9.2, 11.2), 0.5, BRONZE, z=0.4)
    fig.disc((0, 1.5), 3.6, BRONZE, z=0.1)                               # the bearing block
    fig.disc((0, 1.5), 1.7, DARK, z=0.15)
    for s in (-1, 1):                                                    # funnel lips
        fig.capsule((s * 18, -24), (s * 10, -12), 1.5, STEEL, z=1)
        fig.box((s * 18 - 1.6, -26.2, s * 18 + 1.6, -23), BRONZE, z=1.1, bevel=0.6)
        fig.sphere((s * 18, -24.6), 0.55, STEEL, z=1.2)
    return fig.render(44, 44, (22, 28), extra=OAK_EXTRA)


def rocker():
    fig = Figure()
    # the cam lobe: an iron tongue under the hub, rounded at its tip
    fig.poly([(-3.2, 1.5), (3.2, 1.5), (1.1, 7.0), (-1.1, 7.0)], IRON, z=-0.2, shade=0.5)
    fig.sphere((0, 6.8), 1.3, IRON, z=-0.1)
    # the see-saw: a brass beam, a touch thicker at the middle, capped in steel
    fig.box((-15, -0.5, 15, 2.2), BRONZE, z=0, bevel=0.8)
    for x in (-15, 15):
        fig.box((x - 1.4, -0.8, x + 1.4, 2.6), STEEL, z=0.2, bevel=0.6)
    for x in (-9, 9):
        fig.sphere((x, 0.9), 0.6, STEEL, z=0.3)                          # rivets
    fig.disc((0, 1), 3.2, STEEL, z=0.5)                                  # the hub
    fig.sphere((0, 1), 1.3, BRONZE, z=0.6)                               # its pin
    return fig.render(36, 18, (18, 5))


def spring(k):
    """k 0 relaxed .. 1 squashed: a brass leaf from the clamp, bowing down
    toward the roller, which drops 2.4 px."""
    fig = Figure()
    ry = 6.8 + 2.4 * k
    a = (-9.0, 11.2)
    b = (-0.6, ry + 0.8)
    n = 6
    sag = 0.6 + 1.4 * k
    pts = []
    for i in range(n + 1):
        t = i / n
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t + math.sin(t * math.pi) * sag
        pts.append((x, y))
    for p, q in zip(pts, pts[1:]):
        fig.capsule(p, q, 0.75, BRONZE, z=0)
    fig.sphere((0, ry), 1.6, STEEL, z=0.2)                              # the roller
    fig.sphere((0, ry), 0.45, DARK, z=0.3)
    return fig.render(22, 16, (11, 0))


def main():
    f, r = frame(), rocker()
    frames = [spring(i / (FRAMES - 1)) for i in range(FRAMES)]
    strip = [sum((fr[y] for fr in frames), []) for y in range(len(frames[0]))]
    write_png(SPR + 'flipflop_frame.png', 44, 44, f)
    write_png(SPR + 'flipflop_rocker.png', 36, 18, r)
    write_png(SPR + 'flipflop_spring.png', len(strip[0]), len(strip), strip)
    print('wrote flipflop_frame.png, flipflop_rocker.png, flipflop_spring.png')
    if len(sys.argv) > 1:
        big = side_by_side([f, r] + frames, 8)
        write_png(sys.argv[1] + '/flipflop_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
