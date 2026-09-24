"""Effect sprites.

    python3 tools/art/gen_fx.py [preview_dir]

assets/sprites/shockwave.png: 5 frames of 48x24, a ground wave of rock and
dust rolling right (flip for left), rising then breaking up. Bottom of the
frame = ground level. Spawned in pairs by the titan's stomp.
"""
import math, random, sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side

FW, FH = 48, 24
DUST = [(0x29, 0x26, 0x1f), (0x4b, 0x36, 0x2b), (0x63, 0x4c, 0x36), (0x86, 0x61, 0x3c), (0xa8, 0x8f, 0x67)]


def wave(k, n=5):
    t = k / (n - 1)
    h = 13 * math.sin(math.pi * min(1.0, 0.25 + t * 0.9))   # crest height
    fig = Figure()
    r = random.Random(7 + k)
    # the crest: a leaning ridge of clods, taller at the leading edge
    for i in range(16):
        u = i / 15
        x = -18 + u * 34
        top = h * (0.35 + 0.65 * u) * (1 - 0.8 * t * (1 - u))
        y = -top * r.uniform(0.5, 1.0)
        fig.ellipsoid((x + r.uniform(-1, 1), y), (r.uniform(1.6, 3.0), r.uniform(1.4, 2.4)),
                      DUST if r.random() < 0.6 else ROCK, z=u + r.random() * 0.1)
    # low skirt of dust along the ground
    fig.ellipsoid((-2, -0.8), (20, 1.8), DUST, z=-1, grit=0.12)
    # flying chips ahead and above, sparks of cyan off the leading edge early on
    for i in range(5 + k):
        a = r.uniform(-2.6, -1.0)
        d = r.uniform(4, 8 + k * 2)
        fig.sphere((16 + math.cos(a) * d * 0.6, -h + math.sin(a) * d * 0.5), r.uniform(0.6, 1.1), ROCK, z=3)
    if k < 3:
        bolt(fig, (15, -h * 0.9), (21, -h - 3), seed=k * 3 + 1, jag=1.0, segs=3, width=0.4)
    return fig.render(FW, FH, (24, 23))


def main():
    frames = [wave(k) for k in range(5)]
    rows = [sum((f[y] for f in frames), []) for y in range(FH)]
    write_png(SPR + 'shockwave.png', FW * len(frames), FH, rows)
    print('wrote shockwave.png')
    if len(sys.argv) > 1:
        big = side_by_side(frames, 8)
        write_png(sys.argv[1] + '/shockwave_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
