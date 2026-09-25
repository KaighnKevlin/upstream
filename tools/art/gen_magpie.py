"""Clockwork magpie: a thief. Snatches loose ore out of the air and off the
ground and flies off with it.

    python3 tools/art/gen_magpie.py [preview_dir]

Writes assets/sprites/magpie.png: 8 frames of 40x28, facing right, body
centre at (19, 13):
  0-5  flight, one wingbeat (blade feathers fan open on the downstroke)
  6-7  dive, wings swept back
The grapple claw hangs under the body at about (+1, +8) from the centre;
carried ore is drawn there by the game.
"""
import math, sys
from clockwork import *
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side

FW, FH, O = 40, 28, (19, 13)
N_FLY = 6


def wing(fig, flap, z, far, swept=0.0):
    """Wing of overlapping steel blade feathers. flap > 0 lifts the tip;
    swept (0..1) folds the wing back along the body for a dive."""
    root = (2, -2.5)
    shade = 0.3 if far else 0.6
    col = STEEL
    dx = 1 if far else 0
    for k in range(5):  # primaries, front to back
        base_ang = -125 - k * 12            # degrees: fanning up and back
        ang = math.radians(base_ang + flap * 70 - swept * (45 - k * 6))
        length = 11 - k * 1.1 - swept * 3
        tip = (root[0] + dx + math.cos(ang) * length - k * 1.2, root[1] + math.sin(ang) * length * 0.85)
        base = (root[0] + dx - k * 1.8, root[1] + 0.5)
        fig.capsule(base, tip, 1.1 - k * 0.08, col, z=z + k * 0.01)
    # brass shoulder plate with a rivet
    fig.ellipsoid((root[0] + dx - 2, root[1] + 0.5), (3.2, 2.0), BRONZE if not far else DARK, z=z + 0.2)
    fig.disc((root[0] + dx - 2, root[1] + 0.3), 0.6, DARK, z=z + 0.3)


def build(i):
    dive = i >= N_FLY
    if dive:
        flap, bob, swept, tilt = 0.1, 0.0, 1.0, 22 if i == N_FLY else 28
    else:
        ph = i / N_FLY * 2 * math.pi
        flap, bob, swept, tilt = math.sin(ph), -1.0 * math.cos(ph), 0.0, 0
    fig = Figure()
    fig.transform(tilt, (0, 0), (0, bob))
    wing(fig, flap, 0, True, swept)                                         # far wing
    # tail: three long steel blades, the middle one longest
    for k, (L, a) in enumerate([(12, 8), (15, 2), (11, -5)]):
        t = math.radians(180 + a)
        fig.capsule((-6, 0.5), (-6 + math.cos(t) * L, 0.5 + math.sin(t) * L * 0.6), 0.9 - k * 0.1, STEEL if k != 1 else DARK, z=1 + k * 0.01)
    fig.ellipsoid((0, 0), (8, 4.0), BRONZE, z=2)                            # body
    fig.ellipsoid((1, 2.2), (5.5, 1.8), STEEL, z=2.1)                       # breast plate
    fig.disc((-1.5, 0), 2.3, DARK, z=2.2)
    fig.gear((-1.5, 0), 2.0, 6, i * 40, BRONZE, z=2.3)                      # clockwork heart
    fig.ellipsoid((7.5, -1.6), (3.2, 2.8), BRONZE, z=2.4)                   # head
    fig.poly([(9.8, -2.4), (14.5, -0.8), (9.8, -0.4)], STEEL, z=2.5, shade=0.8)  # beak
    fig.sphere((8.4, -2.3), 1.1, GLOW, z=2.6, emissive=True)                # eye
    fig.capsule((1, 3.5), (1, 6.5), 0.5, DARK, z=1.8)                       # grapple arm
    fig.capsule((1, 6.5), (-0.8, 8.2), 0.45, STEEL, z=1.9)                  # claws
    fig.capsule((1, 6.5), (2.8, 8.2), 0.45, STEEL, z=1.9)
    wing(fig, flap, 3, False, swept)                                        # near wing
    return fig.render(FW, FH, O)


def main():
    frames = [build(i) for i in range(N_FLY + 2)]
    write_png(SPR + 'magpie.png', FW * len(frames), FH, [sum((f[y] for f in frames), []) for y in range(FH)])
    print('wrote magpie.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 6)
        write_png(sys.argv[1] + '/magpie_preview.png', len(big[0]), len(big), big)
        write_gif(sys.argv[1] + '/magpie.gif', frames[:N_FLY] * 4, [6] * (N_FLY * 4), 6)


if __name__ == '__main__':
    main()
