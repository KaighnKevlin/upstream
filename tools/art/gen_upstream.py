"""Animates Kaighn's upstream shaft (assets/sprites/upstream-sprite.png).

    python3 tools/art/gen_upstream.py [preview_dir]

His drawing is kept as is; only the stream inside the column moves. Writes
assets/sprites/upstream_anim.png: 8 frames of 48x128. Bright current lines
and bubbles rise through the stream.
Everything moves 12px per frame and the stream is 96px tall, so the loop is
seamless, and at 10 fps it rises at ~120px/s, close to the shaft's lift speed.
"""
import random, sys
from pixtools import read_png, write_png, write_gif, upscale

SRC = __file__.rsplit('/', 1)[0] + '/../../assets/sprites/'
N, STEP = 8, 12
LIGHT = [(117, 207, 232), (166, 230, 239), (197, 247, 247)]


def is_stream(p):
    r, g, b, a = p
    return a and b > r + 60 and b > 150   # the blues, not the grey stone


def main():
    w, h, base = read_png(SRC + 'upstream-sprite.png')
    mask = [[is_stream(base[y][x]) for x in range(w)] for y in range(h)]
    ys = [y for y in range(h) if any(mask[y])]
    y0, y1 = ys[0], ys[-1] + 1
    period = STEP * N                     # 96: the loop length in px
    r = random.Random(4)
    # rising things: (x, y at frame 0, length, brightness 0-2)
    lines = [(r.randrange(w), r.randrange(period), r.randint(3, 8), r.choice((0, 1, 1, 2))) for _ in range(30)]
    bubbles = [(r.randrange(w), r.randrange(period)) for _ in range(9)]
    frames = []
    for f in range(N):
        img = [row[:] for row in base]

        def lit(x, y, k):
            if y0 <= y < y1 and 0 <= x < w and mask[y][x]:
                img[y][x] = LIGHT[k] + (255,)
        for x, yy, ln, k in lines:
            top = y0 + (yy - f * STEP) % period
            for d in range(ln):
                lit(x, top + d, max(0, k - (1 if d > ln // 2 else 0)))
        for x, yy in bubbles:
            cy = y0 + (yy - f * STEP) % period
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                lit(x + dx, cy + dy, 2)
        frames.append(img)
    rows = [sum((fr[y] for fr in frames), []) for y in range(h)]
    write_png(SRC + 'upstream_anim.png', w * N, h, rows)
    print('wrote upstream_anim.png (%d frames, stream rows %d-%d)' % (N, y0, y1))
    if len(sys.argv) > 1:
        write_gif(sys.argv[1] + '/upstream.gif', frames * 3, [10] * (N * 3), 3)


if __name__ == '__main__':
    main()
