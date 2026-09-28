"""Spring trap: an iron frame sunk in the ground round a pit, the oak plate
hinged at its left end with a yellow/black warning edge on its free end,
the coiled spring under it, and the little iron hopper on its stalk that
re-cocks it. The code draws the hopper's two brass load lights.

    python3 tools/art/gen_spring_trap.py [preview_dir]

Writes (all measured from the node origin, the ground surface at the
trap's centre; the plate is W = 26 wide, x -13..13):
- spring_trap_base.png    34x10, the origin at (17, 3): the pit (x -13..13,
  y 1.5..5) in an iron frame whose jambs stand at x +-13..15.5, a brass catch
  on the right jamb and the linkage lug the hopper's rod hooks into.
- spring_trap_plate.png   30x7, the hinge at (2, 3): placed at (-13, 0) and
  rotated by the code (0 flat .. -0.9 sprung). An oak board on rows -1..2
  from the hinge knuckle out to x 26, the last 7 px barred yellow/black.
- spring_trap_spring.png  8 frames of 12x24 (hframes = 8), each with the
  origin at (6, 18): the coil stands on the pit floor at y 5 and reaches up
  to y 2 - 14*k for frame k/7 (squashed cocked .. stretched sprung).
- spring_trap_hopper.png  16x20, the hopper mouth centre at (8, 11): placed
  at the code's _hopper() = (22, -8). Funnel, spout, a stalk down to the
  ground (y +8 from it), the rod to the catch, and the seat the two load
  lights (x -5..-1 and 1..5, y -9..-7) sit on.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
HAZ_EXTRA = ['8a6a18', 'd8a82c', 'f0d050']
HAZ = [(138, 106, 24), (216, 168, 44), (240, 208, 80)]
EXTRA = OAK_EXTRA + HAZ_EXTRA
IRON = STEEL[:6]
PIT = [OUTLINE, OUTLINE, (53, 60, 66)]

FRAMES = 8


def base():
    fig = Figure()
    fig.box((-13, 1.5, 13, 5), PIT, z=0, bevel=0.3, grit=0.02)           # the dark pit
    fig.box((-15.5, 4.6, 15.5, 6.5), IRON, z=0.1, bevel=0.6)             # the sill under it
    for x0 in (-15.5, 13):
        fig.box((x0, -1, x0 + 2.5, 6), IRON, z=0.2, bevel=0.7)           # the jambs
        fig.sphere((x0 + 1.25, 3.2), 0.6, BRONZE, z=0.3)                 # rivets
    fig.box((-15.5, -2, -12, 1), IRON, z=0.25, bevel=0.6)                # the hinge bracket
    # the catch: a brass tooth on the right jamb hooking over the plate end
    fig.poly([(13, -2.2), (15.5, -2.2), (15.5, -0.6), (12.2, -0.6)], BRONZE, z=0.3, shade=0.7)
    return fig.render(34, 10, (17, 3), extra=EXTRA)


def plate():
    fig = Figure()
    fig.box((0, -1, 26, 2), OAK, z=0, bevel=0.6, grit=0.1)               # the board
    fig.capsule((5, 0.5), (11, 0.5), 0.3, OAK[:2], z=0.05)               # grain
    fig.capsule((13, 0.2), (17, 0.2), 0.3, OAK[:2], z=0.05)
    fig.box((8.5, -1.2, 10.5, 2.2), IRON, z=0.1, bevel=0.5)              # an iron strap
    # the warning edge: yellow/black bars on the free end
    fig.box((18.6, -1, 26, 2), [(41, 38, 31), (53, 60, 66)], z=0.15, bevel=0.3, grit=0.02)
    for x in (18.6, 22.2):
        fig.box((x, -1, x + 1.9, 2), HAZ, z=0.2, bevel=0.3)
    fig.box((25.6, -1, 26, 2), HAZ, z=0.2, bevel=0.1)
    fig.sphere((0, 0.5), 1.8, IRON, z=0.3)                               # the hinge knuckle
    return fig.render(30, 7, (2, 3), extra=EXTRA)


def spring(k):
    """Frame for tilt k (0 cocked .. 1 sprung): the coil from the pit floor
    y 5 up to y 2 - 14k, five turns, front strokes lit and back ones dark."""
    fig = Figure()
    yb, yt = 4.6, 2 - 14 * k + 0.4
    turns = 5
    p = (yb - yt) / turns
    fig.box((-4.8, yb - 0.2, 4.8, yb + 0.6), IRON, z=0.5, bevel=0.3)     # seat
    for i in range(turns):
        y0 = yb - i * p
        fig.capsule((-3.8, y0), (3.8, y0 - p * 0.5), 0.7, DARK, z=0.1)          # back
        fig.capsule((3.8, y0 - p * 0.5), (-3.8, y0 - p), 0.75, STEEL, z=0.3)    # front
    fig.box((-4.6, yt - 0.6, 4.6, yt + 0.4), IRON, z=0.4, bevel=0.3)     # top cap
    return fig.render(12, 24, (6, 18), extra=EXTRA)


def hopper():
    fig = Figure()
    fig.capsule((0, 5.5), (0, 8), 0.9, IRON, z=0)                        # stalk
    fig.box((-3, 7.2, 3, 8.6), IRON, z=0.1, bevel=0.4)                   # its foot
    fig.capsule((-1, 5.5), (-8.5, 7.4), 0.45, STEEL, z=0.05)             # rod to the catch
    fig.poly([(-6, -5), (6, -5), (2.5, 4), (-2.5, 4)], IRON, z=0.2, shade=0.5)   # funnel
    fig.poly([(-5, -5), (-2, -5), (-1, 3), (-2, 3)], IRON, z=0.25, shade=0.75)   # its lit side
    fig.box((-1.6, 3.5, 1.6, 6), IRON, z=0.3, bevel=0.5)                 # spout
    fig.box((-6.8, -7, 6.8, -4.6), IRON, z=0.4, bevel=0.6)               # rim, seat for the lights
    fig.box((-0.9, -9.2, 0.9, -7), DARK, z=0.35, bevel=0.3)              # divider between lights
    for x in (-6.4, 5.4):
        fig.box((x, -9.6, x + 1, -7), DARK, z=0.35, bevel=0.3)           # end posts
    img = fig.render(16, 20, (8, 11), extra=EXTRA)
    # leave the lights' windows clear: the code draws them under its sprites
    for lx in (-5, 1):
        for y in (-9, -8):
            for x in range(lx, lx + 4):
                img[y + 11][x + 8] = (0, 0, 0, 0)
    return img


def main():
    frames = [spring(i / (FRAMES - 1)) for i in range(FRAMES)]
    strip = [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]
    parts = {'spring_trap_base': base(), 'spring_trap_plate': plate(),
             'spring_trap_spring': strip, 'spring_trap_hopper': hopper()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side([parts['spring_trap_base'], parts['spring_trap_plate'],
                            parts['spring_trap_hopper']] + frames, 6)
        write_png(sys.argv[1] + '/spring_trap_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
