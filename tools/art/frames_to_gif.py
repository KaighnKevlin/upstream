"""Turn a folder of PNG frames (e.g. from the playtest recorder) into a GIF.

    python3 tools/art/frames_to_gif.py <frames_dir> <out.gif> [delay_cs] [prefix]
"""
import glob, os, sys
from pixtools import read_png, write_gif


def median_cut(hist, n):
    """hist: {rgb: count} -> list of <= n representative colours."""
    boxes = [list(hist.items())]
    while len(boxes) < n:
        # split the box with the widest channel range (weighted by pixel count)
        best = None
        for i, b in enumerate(boxes):
            if len(b) < 2: continue
            rng = [max(c[0][k] for c in b) - min(c[0][k] for c in b) for k in range(3)]
            score = max(rng) * sum(c[1] for c in b) ** 0.5
            if best is None or score > best[0]: best = (score, i, rng.index(max(rng)))
        if best is None: break
        _, i, ch = best
        b = sorted(boxes.pop(i), key=lambda c: c[0][ch])
        total = sum(c[1] for c in b); acc = 0
        for cut, c in enumerate(b):
            acc += c[1]
            if acc >= total / 2: break
        cut = max(1, min(len(b) - 1, cut + 1))
        boxes += [b[:cut], b[cut:]]
    reps = []
    for b in boxes:
        t = sum(c[1] for c in b)
        reps.append(tuple(round(sum(c[0][k] * c[1] for c in b) / t) for k in range(3)))
    return reps


def main():
    src, out = sys.argv[1], sys.argv[2]
    delay = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    prefix = sys.argv[4] if len(sys.argv) > 4 else ''
    files = sorted(glob.glob(os.path.join(src, prefix + '*.png')))
    frames = [read_png(f)[2] for f in files]
    hist = {}
    for f in frames:
        for row in f:
            for px in row:
                hist[px[:3]] = hist.get(px[:3], 0) + 1
    reps = median_cut(hist, 255)
    cache = {}
    def near(c):
        if c not in cache:
            cache[c] = min(reps, key=lambda r: (r[0]-c[0])**2*2 + (r[1]-c[1])**2*4 + (r[2]-c[2])**2*3)
        return cache[c]
    mapped = [[[near(px[:3]) + (255,) for px in row] for row in f] for f in frames]
    write_gif(out, mapped, [delay] * len(mapped))
    print('%d frames, %d colours -> %s' % (len(frames), len(reps), out))


if __name__ == '__main__':
    main()
