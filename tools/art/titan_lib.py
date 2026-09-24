"""Shared pieces for building titan frames from the high-res reference
(assets/sprites/Sprite-0009.aseprite) — see gen_titan.py."""
import math
from pixtools import *

SPR = '/Users/kaighnkevlin/Documents/upstream/assets/sprites/'


def load_reference():
    w, h, pal, fr = read_aseprite(SPR + 'Sprite-0009.aseprite')
    return w, h, fr[0]


def load_palette():
    _, _, pal, _ = read_aseprite(SPR + 'axe-titan-base.ase')
    return [p[:3] for p in pal]


def nearest(pal, c):
    best = None; bd = 1e9
    for p in pal:
        # weighted RGB distance (perceptual-ish)
        d = 2 * (p[0] - c[0]) ** 2 + 4 * (p[1] - c[1]) ** 2 + 3 * (p[2] - c[2]) ** 2
        if d < bd: bd = d; best = p
    return best


def downscale(img, w, h, ow, oh, pal, ox=0.0, oy=0.0, scale=None, coverage=0.5):
    """Box-filter img (w x h RGBA rows) into ow x oh, then map to palette.
    scale = source px per output px (defaults to fit height)."""
    s = scale or h / oh
    out = [[(0, 0, 0, 0)] * ow for _ in range(oh)]
    for y in range(oh):
        for x in range(ow):
            x0 = ox + x * s; y0 = oy + y * s
            r = g = b = n = tot = 0
            for yy in range(int(y0), int(math.ceil(y0 + s))):
                for xx in range(int(x0), int(math.ceil(x0 + s))):
                    tot += 1
                    if 0 <= yy < h and 0 <= xx < w:
                        px = img[yy][xx]
                        if px[3] > 0: r += px[0]; g += px[1]; b += px[2]; n += 1
            if tot and n / tot >= coverage:
                out[y][x] = nearest(pal, (r / n, g / n, b / n)) + (255,)
    return out


def side_by_side(frames, s, gap=4, bg=(24, 24, 30, 255)):
    h = max(len(f) for f in frames); ws = [len(f[0]) for f in frames]
    W = sum(ws) + gap * (len(frames) - 1)
    rows = [[bg] * W for _ in range(h)]
    x0 = 0
    for f, w in zip(frames, ws):
        for y in range(len(f)):
            for x in range(w):
                if f[y][x][3] > 0: rows[y][x0 + x] = f[y][x]
        x0 += w + gap
    return upscale(rows, s, bg)
