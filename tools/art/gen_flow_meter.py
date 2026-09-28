"""Flow meter: a brass-bezelled gauge with an ivory face and its tick marks,
on a steel stem down to a bolted foot, and the feeler wire hanging from it
across the run. The needle, the numbers and the feeler's bob (it flashes)
stay in code.

    python3 tools/art/gen_flow_meter.py [preview_dir]

Writes flow_meter.png (30x64, the node origin at (15, 31)): the dial
centred on (0, -16) (r 11, bezel to 12.5), the foot bar at y -4 (x -5..5),
the feeler from y -4 down to its bob at y 30.
"""
import math
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

IVORY_EXTRA = ['b8ae94', 'd8d0b8', 'ece6d2', 'faf6ea']
IVORY = [(184, 174, 148), (216, 208, 184), (236, 230, 210), (250, 246, 234)]
DIAL = (0, -16)


def meter():
    fig = Figure()
    # the feeler: a thin steel wire from the foot down across the run
    fig.capsule((0, -3), (0, 29), 0.45, STEEL, z=0)
    # the stem and the bolted foot
    fig.box((-1.4, -6, 1.4, -3), STEEL, z=0.2, bevel=0.6)
    fig.box((-5.5, -5, 5.5, -2.6), STEEL, z=0.3, bevel=0.7)
    for x in (-4, 4):
        fig.sphere((x, -3.8), 0.6, BRONZE, z=0.4)
    # the gauge: brass bezel, a steel back ring, the ivory face
    fig.disc(DIAL, 12.6, BRONZE, z=1)
    fig.disc(DIAL, 9.4, IVORY, z=1.2)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        fig.sphere((DIAL[0] + math.cos(a) * 11, DIAL[1] + math.sin(a) * 11), 0.55, STEEL, z=1.1)
    # ticks: every sixth of the sweep (135 deg round 270), long ones at 0, 3, 6
    a0 = math.pi * 0.75
    for i in range(7):
        a = a0 + math.pi * 1.5 * i / 6
        u = (math.cos(a), math.sin(a))
        r1 = 8.8
        r0 = 6.4 if i % 3 == 0 else 7.4
        fig.capsule((DIAL[0] + u[0] * r0, DIAL[1] + u[1] * r0), (DIAL[0] + u[0] * r1, DIAL[1] + u[1] * r1), 0.6, DARK, z=1.3)
    return fig.render(30, 64, (15, 31), extra=IVORY_EXTRA)


def main():
    m = meter()
    write_png(SPR + 'flow_meter.png', 30, 64, m)
    print('wrote flow_meter.png')
    if len(sys.argv) > 1:
        big = side_by_side([m], 8)
        write_png(sys.argv[1] + '/flow_meter_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
