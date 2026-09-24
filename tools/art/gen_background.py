"""Night backdrop: sky, moon, far peaks, a ruined clockwork city, near ridge.

    python3 tools/art/gen_background.py [preview_dir]

Writes assets/backgrounds/*.png. Every layer tiles horizontally (all shapes
are periodic in x or wrapped), is lit from the moon on the upper left, and
gets bluer and flatter with distance. The city is where the titans come
from: towers, half-buried gears, chimneys, a few lit windows.

  sky.png     4 x 1200  vertical gradient (stretched in x by the game)
  moon.png    96 x 96   moon with craters and a halo
  far.png     960 x 220 mountain range
  city.png    960 x 200 clockwork ruins
  near.png    960 x 150 ridge with a buried gear and pipes
Bottom of far/city/near is solid so they can run down behind the ground.
"""
import math, os, random, sys
from pixtools import write_png

W = 960
OUT = os.path.join(os.path.dirname(__file__), '../../assets/backgrounds/')
H = lambda h: (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y, t, ramp):
    """Ordered-dither t (0..1) across a list of colours."""
    t = max(0.0, min(0.9999, t)) * (len(ramp) - 1)
    i = int(t)
    f = t - i
    j = i + 1 if f * 16 > BAYER[y % 4][x % 4] + 0.5 else i
    return ramp[min(j, len(ramp) - 1)]


def periodic(seed, harmonics, width=W):
    """Tileable 1D noise: sum of integer-frequency sines."""
    r = random.Random(seed)
    terms = [(k, a, r.uniform(0, 2 * math.pi)) for k, a in harmonics]
    return lambda x: sum(a * math.sin(2 * math.pi * k * x / width + p) for k, a, p in terms)


def blank(w, h):
    return [[(0, 0, 0, 0)] * w for _ in range(h)]


# ── sky ─────────────────────────────────────────────────────────────────
SKY = [H(c) for c in ('0b0a17', '100e21', '15122b', '1c1735', '251d40', '30244a', '3d2c52', '4a3458')]


def sky():
    h = 1200
    img = blank(4, h)
    for y in range(h):
        t = (y / (h - 1)) ** 1.6       # most of the colour change near the horizon
        for x in range(4):
            img[y][x] = dith(x, y, t, SKY) + (255,)
    return img


# ── moon ────────────────────────────────────────────────────────────────
MOON = [H(c) for c in ('4f3d43', '605d55', '93a29c', 'adc6b8', 'cde3dc', 'e8f2ec')]
HALO = [H(c) for c in ('1c1735', '251d40', '30244a', '3d3a5c')]


def moon():
    n, R = 96, 26
    c = n / 2
    r = random.Random(3)
    craters = [(r.uniform(-18, 18), r.uniform(-18, 18), r.uniform(2, 6)) for _ in range(9)]
    img = blank(n, n)
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = math.hypot(dx, dy)
            if d <= R:
                nz = math.sqrt(max(0.0, 1 - (d / R) ** 2))
                lit = 0.35 + 0.65 * max(0.0, (-dx * 0.55 - dy * 0.45) / R + nz * 0.6)
                for cx, cy, cr in craters:
                    e = math.hypot(dx - cx, dy - cy)
                    if e < cr * 0.7:     # shadowed floor
                        lit -= 0.2
                    elif e < cr and (dx - cx) * 0.55 + (dy - cy) * 0.45 > 0:
                        lit += 0.15      # far rim catches the light
                img[y][x] = dith(x, y, lit, MOON) + (255,)
            elif d < R + 20:
                a = (1 - (d - R) / 20) ** 2
                if a * 16 > BAYER[y % 4][x % 4] * 0.9:
                    img[y][x] = dith(x, y, a, HALO) + (255,)
    return img


# ── far mountains ───────────────────────────────────────────────────────
FAR = [H(c) for c in ('1a1731', '201c3a', '282244', '322a4f', '3f3560')]


def far():
    h = 220
    ridge = periodic(11, [(2, 30), (3, 18), (5, 12), (9, 6), (17, 3), (31, 1.5)])
    img = blank(W, h)
    for x in range(W):
        top = 95 + ridge(x)
        slope = ridge(x + 1) - ridge(x - 1)      # >0: the ground rises to the right
        for y in range(int(top), h):
            depth = min(1.0, (y - top) / 110)
            t = 0.35 + depth * 0.45
            if y - top < 6 and slope < 0:        # moonlit left-facing slopes
                t += 0.35 * (1 - (y - top) / 6)
            img[y][x] = dith(x, y, t, FAR) + (255,)
    return img


# ── clockwork city ──────────────────────────────────────────────────────
CITY = [H(c) for c in ('130f22', '18142b', '1e1934', '26203f', '30284b')]
WIN = [H('78c6cd'), H('abd3d4'), H('d9a45a')]


def city():
    h = 200
    base = 150
    img = blank(W, h)
    mask = [[0.0] * W for _ in range(h)]   # 0 = empty, else shade 0..1
    r = random.Random(21)

    def put(x, y, t):
        x %= W
        if 0 <= y < h:
            mask[y][x] = max(mask[y][x], t)

    def rect(x0, y0, x1, y1, t=0.2, lit_edge=True, ledges=False):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                v = t
                if lit_edge and x - x0 < 2:
                    v += 0.45
                elif ledges and (y - y0) % 14 == 0:
                    v += 0.3
                elif y - y0 < 1:
                    v += 0.35
                put(x, y, v)

    def gear(cx, cy, R, teeth, t=0.22):
        for y in range(int(cy - R - 3), int(cy + R + 3)):
            for x in range(int(cx - R - 3), int(cx + R + 3)):
                dx, dy = x - cx, y - cy
                d = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                tooth = (a * teeth / (2 * math.pi)) % 1 < 0.5
                if d < R + (2.5 if tooth else 0) and not (R * 0.3 < d < R * 0.7 and (a * 4 / math.pi) % 2 > 0.6):
                    edge = (-dx - dy) / (R + 3)
                    put(x, y, t + (0.45 if d > R - 2.5 and edge > 0.2 else 0))

    # rolling rubble base
    rub = periodic(5, [(4, 5), (7, 3), (13, 2), (29, 1)])
    for x in range(W):
        for y in range(int(base + rub(x)), h):
            put(x, y, 0.15 + (0.3 if y - base - rub(x) < 1 else 0))
    # structures, spread round the loop
    xs = sorted(r.sample(range(0, W, 8), 22))
    for i, x in enumerate(xs):
        kind = i % 5
        if kind in (0, 3):            # tower with a domed or spired top
            w = r.randint(18, 32); top = r.randint(45, 100)
            rect(x, top, x + w, base + 5, ledges=True)
            if r.random() < 0.5:
                for y in range(top - w // 2, top):
                    half = math.sqrt(max(0, (w / 2) ** 2 - (top - y) ** 2 * 1.0))
                    for xx in range(int(x + w / 2 - half), int(x + w / 2 + half)):
                        put(xx, y, 0.2 + (0.45 if xx - (x + w / 2 - half) < 2 else 0))
            else:
                for k in range(22):
                    put(x + w // 2, top - k, 0.5)
                    if k < 6: put(x + w // 2 - 1, top - k, 0.4)
            for _ in range(r.randint(3, 8)):   # lit windows
                wx, wy = x + r.randint(3, w - 3), r.randint(top + 4, base - 4)
                mask[wy][wx % W] = 2 + r.choice((0, 0, 1, 2))
                if r.random() < 0.5: mask[wy][(wx + 1) % W] = mask[wy][wx % W]
        elif kind == 1:               # giant gear, half sunk
            R = r.randint(18, 32)
            gear(x, base - R * 0.3, R, r.randint(10, 16))
        elif kind == 2:               # chimney stack
            w = r.randint(6, 9); top = r.randint(40, 80)
            rect(x, top, x + w, base + 5)
            rect(x - 1, top, x + w + 1, top + 3, 0.45)
            for k in range(40):       # smoke drifting right, thinning
                sx = x + w / 2 + k * 1.2 + math.sin(k / 4) * 2
                sy = top - 3 - k * 1.1
                rad = 2 + k * 0.12
                for yy in range(int(sy - rad), int(sy + rad)):
                    for xx in range(int(sx - rad), int(sx + rad)):
                        if math.hypot(xx - sx, yy - sy) < rad and BAYER[yy % 4][xx % 4] < 16 * (1 - k / 40) * 0.6:
                            put(xx, yy, 0.55)
        else:                         # low block with an arched bridge to the next
            w = r.randint(24, 40); top = r.randint(110, 130)
            rect(x, top, x + w, base + 5, 0.2, ledges=True)
            for xx in range(w + 30):
                yy = top - 8 + int(6 * math.sin(math.pi * xx / (w + 30)) * -1)
                put(x + xx, yy, 0.6); put(x + xx, yy + 1, 0.25)
    for y in range(h):
        for x in range(W):
            m = mask[y][x]
            if m >= 2:
                img[y][x] = WIN[int(m) - 2] + (255,)
            elif m > 0:
                img[y][x] = dith(x, y, m, CITY) + (255,)
    return img


# ── near ridge ──────────────────────────────────────────────────────────
NEAR = [H(c) for c in ('0c0a12', '110e18', '17131f', '1f1a28', '2a2233')]
PIPE = [H(c) for c in ('17131f', '241e2c', '342a38', '4b3d43', '634c36')]


def near():
    h = 150
    ridge = periodic(8, [(3, 14), (5, 8), (11, 4), (23, 2), (47, 1)])
    img = blank(W, h)
    for x in range(W):
        top = 60 + ridge(x)
        slope = ridge(x + 1) - ridge(x - 1)
        for y in range(int(top), h):
            t = 0.4 - (y - top) / 90
            if y - top < 3 and slope < 0:
                t += 0.3
            img[y][x] = dith(x, y, t, NEAR) + (255,)
        # grass blades on the crest
        if random.Random(x * 7).random() < 0.35:
            for k in range(random.Random(x).randint(1, 3)):
                yy = int(top) - 1 - k
                if 0 <= yy: img[yy][x] = NEAR[2] + (255,)
    # a big half-buried gear and a pipe run
    cx, cy, R = 300, 78, 34
    for y in range(h):
        for x in range(cx - R - 4, cx + R + 4):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = (a * 14 / (2 * math.pi)) % 1 < 0.5
            if d < R + (3 if tooth else 0) and not (R * 0.35 < d < R * 0.72 and (a * 6 / math.pi) % 2 > 0.7):
                if img[y][x % W][3] and y > 60 + ridge(x) + 4:
                    continue  # buried below the crest
                lit = 0.35 + (0.35 if d > R - 3 and (-dx - dy) > R * 0.4 else 0)
                img[y][x % W] = dith(x, y, lit, PIPE) + (255,)
    for x in range(560, 780):              # pipe along the slope
        y0 = int(60 + ridge(x)) - 3
        for k in range(5):
            if 0 <= y0 + k < h:
                img[y0 + k][x] = dith(x, y0 + k, [0.7, 0.55, 0.4, 0.3, 0.2][k], PIPE) + (255,)
        if x % 40 == 0:                     # flanges
            for k in range(-1, 7):
                if 0 <= y0 + k < h:
                    img[y0 + k][x] = PIPE[3] + (255,); img[y0 + k][x + 1] = PIPE[2] + (255,)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    layers = {'sky': sky(), 'moon': moon(), 'far': far(), 'city': city(), 'near': near()}
    for name, img in layers.items():
        write_png(OUT + name + '.png', len(img[0]), len(img), img)
    print('wrote', ', '.join(layers))
    if len(sys.argv) > 1:
        # composite preview, roughly as the game stacks them
        cw, ch = W, 330
        comp = [[SKY[min(7, int((y / ch) ** 1.6 * 8))] + (255,)] * cw for y in range(ch)]
        comp = [row[:] for row in comp]

        def over(img, ox, oy):
            for y, row in enumerate(img):
                for x, p in enumerate(row):
                    X, Y = ox + x, oy + y
                    if p[3] and 0 <= X < cw and 0 <= Y < ch:
                        comp[Y][X] = p
        over(layers['moon'], 200, 20)
        over(layers['far'], 0, 90)
        over(layers['city'], 0, 130)
        over(layers['near'], 0, 230)
        write_png(sys.argv[1] + '/bg_preview.png', cw, ch, comp)


if __name__ == '__main__':
    main()
