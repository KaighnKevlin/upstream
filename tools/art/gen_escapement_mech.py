"""Escapement, as a real marble-machine part: a two-pin pallet worked by a
metronome. A brass pallet bar rocks on a pin on an oak post; an upright
steel metronome rod is fixed to it, with a brass weight you slide along the
rod (higher: slower, like any metronome). From each end of the pallet hangs
a steel stop pin through an iron guide bar over the track: the exit pin B
over the pin point, the entry pin A one marble upstream. As the metronome
swings, one pin rises while the other drops: B up lets the lead marble go
while A drops behind it into the gap and holds the rest; back again, A
lifts and the next marble rolls down to B. One per swing.

    python3 tools/art/gen_escapement_mech.py [preview_dir]

Drawn for a track running left to right (the code mirrors it with
scale.x = side). Measured from the node origin, the pin point on the rail;
y down. The pallet pivot is P = (-6.5, -28).
- escapement_frame.png   26x22, the origin at (20, 36): the oak post from
  the guide bar up to a brass pivot bracket at P, the iron guide bar
  x -17..4 on rows -19..-16 with guide holes at x 0 and x -13.
- escapement_pallet.png  22x34, P at (11, 28): the pallet bar from x -9 to
  +9 about P (eyes along it: the pins ride in its slots), the metronome rod
  from P up to y -24 (from P), with notches at 9, 14 and 19 px (the weight's
  three places). The code rotates it about P.
- escapement_bob.png     7x6, its centre at (3, 3): the sliding weight.
- escapement_stop.png    5x22, the eye at (2, 1): a stop pin hanging from
  its eye, 19.5 px long (the code shortens A's by lifting it 3 px).
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

OAK_EXTRA = ['2a221c', '46301f', '5e4028', '7a5433', '946a42']
OAK = [(42, 34, 28), (70, 48, 31), (94, 64, 40), (122, 84, 51), (148, 106, 66)]
IRON = STEEL[:6]


def frame():
    fig = Figure()
    fig.box((-8.2, -30, -4.8, -17), OAK, z=0, bevel=0.6, grit=0.1)       # oak post
    fig.box((-17, -19.2, 4, -16), IRON, z=0.2, bevel=0.6)                # guide bar
    for x in (0, -13):
        fig.box((x - 1.3, -19.2, x + 1.3, -16), DARK, z=0.25, bevel=0.3)   # guide holes
    for x in (-15.5, 2.5):
        fig.sphere((x, -17.6), 0.55, BRONZE, z=0.3)
    fig.disc((-6.5, -28), 2.8, BRONZE, z=0.3)                            # pivot bracket
    fig.disc((-6.5, -28), 1.2, DARK, z=0.35)
    return fig.render(26, 22, (20, 36), extra=OAK_EXTRA)


def pallet():
    fig = Figure()
    fig.capsule((0, 0), (0, -24), 0.8, STEEL, z=0)                       # metronome rod
    for d in (9, 14, 19):
        fig.box((-1.3, -d - 0.4, 1.3, -d + 0.4), DARK, z=0.05, bevel=0.2)   # notches
    fig.sphere((0, -24), 1.1, STEEL, z=0.1)                              # its finial
    fig.box((-9, -1.3, 9, 1.3), BRONZE, z=0.2, bevel=0.6)                # pallet bar
    for x in (-6.5, 6.5):
        fig.box((x - 2.2, -0.5, x + 2.2, 0.5), DARK, z=0.25, bevel=0.2)   # slots
    fig.disc((0, 0), 2.4, STEEL, z=0.3)                                  # hub
    fig.sphere((0, 0), 0.9, BRONZE, z=0.4)
    return fig.render(22, 34, (11, 28))


def bob():
    fig = Figure()
    fig.box((-3, -2.2, 3, 2.2), BRONZE, z=0, bevel=0.9)
    fig.box((-3.2, -0.4, 3.2, 0.4), [BRONZE[2], BRONZE[3]], z=0.1, bevel=0.2)
    return fig.render(7, 6, (3, 3))


def stop():
    fig = Figure()
    fig.capsule((0, 1.5), (0, 19.5), 0.75, STEEL, z=0)
    fig.disc((0, 0.6), 1.6, BRONZE, z=0.1)                               # the eye
    fig.sphere((0, 0.6), 0.5, DARK, z=0.2)
    return fig.render(5, 22, (2, 1))


def main():
    parts = {'escapement_frame': frame(), 'escapement_pallet': pallet(),
             'escapement_bob': bob(), 'escapement_stop': stop()}
    for n, img in parts.items():
        write_png(SPR + n + '.png', len(img[0]), len(img), img)
    print('wrote ' + ', '.join(n + '.png' for n in parts))
    if len(sys.argv) > 1:
        big = side_by_side(list(parts.values()), 8)
        write_png(sys.argv[1] + '/escapement_mech_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
