"""Check valve: a steel hinge bracket (a bolted cross-bar with two cheeks
round the hinge pin) and the brass flap that hangs from it and swings open.

    python3 tools/art/gen_check_valve.py [preview_dir]

Writes (all measured from the hinge pin, which the code puts at (0, -16)):
- check_valve_bracket.png  18x9, the pin at (9, 6): the bar across y -4..-1
  (the node's y -20..-17), the cheeks down round the pin.
- check_valve_flap.png     8x24, the pin at (4, 3): the plate hangs +y from
  it 18 px to a leather lip at its foot; the code swings it about the pin.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def bracket():
    fig = Figure()
    fig.box((-8, -4.6, 8, -1.4), STEEL, z=0, bevel=0.8)                 # the cross-bar
    fig.capsule((-8, -1.8), (8, -1.8), 0.4, DARK, z=0.1)                 # its shadowed lower edge
    for x in (-6, 6):
        fig.sphere((x, -3.1), 0.8, BRONZE, z=0.3)                        # bolts
    fig.box((-3, -2.5, 3, 1.6), STEEL, z=0.2, bevel=0.9)                 # the cheeks round the pin
    fig.disc((0, 0), 1.9, DARK, z=0.4)
    return fig.render(18, 9, (9, 6))


def flap():
    fig = Figure()
    fig.box((-2.1, 0, 2.1, 17.2), BRONZE, z=0, bevel=0.9)                # the plate
    fig.capsule((0, 4), (0, 14), 0.35, [(99, 76, 54)] * 2, z=0.1)       # a pressed rib
    fig.box((-2.1, 16, 2.1, 18.4), DARK, z=0.2, bevel=0.6, grit=0.02)   # the leather lip
    for y in (8, 12):
        fig.sphere((0, y), 0.5, STEEL, z=0.3)
    fig.disc((0, 0), 2.3, STEEL, z=0.5)                                  # the knuckle
    fig.sphere((-0.2, -0.2), 0.8, BRONZE, z=0.6)                         # the pin
    return fig.render(8, 24, (4, 3), extra=['634c36'])


def main():
    b, f = bracket(), flap()
    write_png(SPR + 'check_valve_bracket.png', 18, 9, b)
    write_png(SPR + 'check_valve_flap.png', 8, 24, f)
    print('wrote check_valve_bracket.png, check_valve_flap.png')
    if len(sys.argv) > 1:
        big = side_by_side([b, f], 8)
        write_png(sys.argv[1] + '/check_valve_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
