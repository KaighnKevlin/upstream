"""A tiny 2.5D painter for clockwork sprites.

Builds a figure from lit primitives (ellipsoids, capsules, gears, discs),
renders it supersampled, then box-filters it into the titan palette, so new
characters share the titan's look (bronze and steel, cyan cores).
Coordinates are in sprite pixels, with y pointing down. Light comes from the
top-left front.

    fig = Figure()
    fig.ellipsoid((0, -14), (11, 8), BRONZE, z=0)
    fig.capsule((4, -10), (9, -2), 1.3, STEEL, z=1)
    img = fig.render(48, 40, origin=(20, 38))   # -> rows of RGBA, palette-mapped
"""
import math
from titan_lib import load_palette, nearest

S = 6  # supersampling

_hex = lambda h: (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
BRONZE = [_hex(h) for h in ('29261f', '4b362b', '634c36', '86613c', 'a88f67', 'c7a877', 'd9c27e', 'e2cb94')]
STEEL = [_hex(h) for h in ('29261f', '353c42', '3a494a', '5f7c83', '709092', '93a29c', 'adc6b8', 'cde3dc')]
DARK = [_hex(h) for h in ('29261f', '29261f', '353c42', '4b362b', '4f3d43', '605d55')]
GLOW = [_hex(h) for h in ('5f7c83', '73bac3', '78c6cd', '90bcc4', 'abd3d4', 'cde3dc')]
OUTLINE = _hex('29261f')

LIGHT = (-0.45, -0.65, 0.62)
_ll = math.sqrt(sum(v * v for v in LIGHT)); LIGHT = tuple(v / _ll for v in LIGHT)


def _ramp(mat, t):
    t = min(0.999, max(0.0, t)) * (len(mat) - 1)
    i = int(t); f = t - i
    a, b = mat[i], mat[min(i + 1, len(mat) - 1)]
    return tuple(a[k] + (b[k] - a[k]) * f for k in range(3))


def _hash(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xffffffff
    h = (h ^ (h >> 13)) * 1274126177 & 0xffffffff
    return (h ^ (h >> 16)) / 0xffffffff


def _shade(n, mat, grit=0.07, gx=0, gy=0, emissive=False):
    if emissive:
        # brighter toward the centre (n.z high)
        return _ramp(mat, 0.25 + 0.75 * n[2])
    diff = max(0.0, n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2])
    rim = max(0.0, 1 - n[2]) ** 3 * 0.25 * max(0.0, -n[1] * 0.5 + 0.5)
    r = (2 * diff * n[2] - LIGHT[2]) if n[2] > 0 else 0
    spec = max(0.0, r) ** 12 * 0.35
    t = 0.12 + 0.75 * diff + rim + spec
    t += (_hash(gx, gy) - 0.5) * 2 * grit
    return _ramp(mat, t)


class Figure:
    def __init__(self):
        self.prims = []

    # each primitive: (z, fn(x, y) -> colour or None)

    def ellipsoid(self, c, r, mat, z=0, emissive=False, grit=0.07, tilt=0.0):
        cx, cy = c; rx, ry = r
        ct, st = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))

        def fn(x, y):
            dx, dy = x - cx, y - cy
            lx, ly = (dx * ct + dy * st) / rx, (-dx * st + dy * ct) / ry
            d = lx * lx + ly * ly
            if d > 1: return None
            nz = math.sqrt(1 - d)
            nx, ny = lx * ct - ly * st, lx * st + ly * ct
            return _shade((nx, ny, nz), mat, grit, int(x * 3), int(y * 3), emissive)
        self.prims.append((z, fn, (cx - max(rx, ry), cy - max(rx, ry), cx + max(rx, ry), cy + max(rx, ry))))

    def sphere(self, c, r, mat, z=0, emissive=False, grit=0.07):
        self.ellipsoid(c, (r, r), mat, z, emissive, grit)

    def capsule(self, a, b, r, mat, z=0, grit=0.07):
        ax, ay = a; bx, by = b
        vx, vy = bx - ax, by - ay; L2 = vx * vx + vy * vy or 1e-9

        def fn(x, y):
            t = max(0.0, min(1.0, ((x - ax) * vx + (y - ay) * vy) / L2))
            px, py = ax + vx * t, ay + vy * t
            dx, dy = (x - px) / r, (y - py) / r
            d = dx * dx + dy * dy
            if d > 1: return None
            return _shade((dx, dy, math.sqrt(1 - d)), mat, grit, int(x * 3), int(y * 3))
        self.prims.append((z, fn, (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r)))

    def gear(self, c, r, teeth, angle, mat, z=0, hub_mat=None):
        """Flat gear seen face-on: bevelled rim, teeth, spokes, hub."""
        cx, cy = c
        hub_mat = hub_mat or mat

        def fn(x, y):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = (math.degrees(math.atan2(dy, dx)) - angle) % (360 / teeth)
            tooth = a < 180 / teeth
            if d > r + (0.9 if tooth else 0): return None
            if d < r * 0.28:  # hub
                nz = math.sqrt(max(0.0, 1 - (d / (r * 0.28)) ** 2))
                return _shade((dx / (r * 0.28) * 0.6, dy / (r * 0.28) * 0.6, max(0.4, nz)), hub_mat)
            spoke = min(abs(((math.degrees(math.atan2(dy, dx)) - angle) % 90) - 45) , 99) > 34
            if r * 0.28 <= d < r * 0.68 and not spoke:
                return None  # holes between spokes
            # bevel: rim faces tilt outward
            k = min(1.0, max(0.0, (d - r * 0.68) / (r * 0.32)))
            nx, ny = dx / (d or 1) * k * 0.7, dy / (d or 1) * k * 0.7
            return _shade((nx, ny, math.sqrt(max(0.1, 1 - nx * nx - ny * ny))), mat, 0.05, int(x * 3), int(y * 3))
        self.prims.append((z, fn, (cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)))

    def disc(self, c, r, mat, z=0, emissive=False):
        """Flat plate, lit as facing the viewer with a bevelled edge."""
        cx, cy = c

        def fn(x, y):
            dx, dy = (x - cx) / r, (y - cy) / r
            d = math.hypot(dx, dy)
            if d > 1: return None
            k = max(0.0, (d - 0.75) / 0.25)
            return _shade((dx * k * 0.7, dy * k * 0.7, 1 - k * 0.3), mat, 0.05, int(x * 3), int(y * 3), emissive)
        self.prims.append((z, fn, (cx - r, cy - r, cx + r, cy + r)))

    def render(self, w, h, origin, outline=True):
        """-> h rows of w RGBA pixels, palette-mapped. origin: where figure
        (0, 0) lands in the output (e.g. feet at bottom-centre)."""
        pal = load_palette()
        prims = sorted(self.prims, key=lambda p: p[0])
        ox, oy = origin
        out = [[(0, 0, 0, 0)] * w for _ in range(h)]
        for py in range(h):
            for px in range(w):
                r = g = b = n = 0
                for sy in range(S):
                    for sx in range(S):
                        x = px - ox + (sx + 0.5) / S
                        y = py - oy + (sy + 0.5) / S
                        col = None
                        for z, fn, bb in reversed(prims):
                            if bb[0] <= x <= bb[2] and bb[1] <= y <= bb[3]:
                                col = fn(x, y)
                                if col: break
                        if col:
                            r += col[0]; g += col[1]; b += col[2]; n += 1
                if n >= S * S * 0.45:
                    out[py][px] = nearest(pal, (r / n, g / n, b / n)) + (255,)
        if outline:
            _outline(out)
        return out


def _outline(img):
    h, w = len(img), len(img[0])
    add = []
    for y in range(h):
        for x in range(w):
            if img[y][x][3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and img[yy][xx][3] and img[yy][xx][:3] != OUTLINE:
                    add.append((x, y)); break
    for x, y in add:
        img[y][x] = OUTLINE + (255,)


def bolt(fig, a, b, seed, z=20, jag=1.6, segs=6, width=0.45):
    """Jagged lightning between a and b, drawn as thin emissive segments."""
    import random
    r = random.Random(seed)
    pts = [a]
    for k in range(1, segs):
        t = k / segs
        px = a[0] + (b[0] - a[0]) * t; py = a[1] + (b[1] - a[1]) * t
        # offset perpendicular to the bolt
        dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy) or 1
        o = (r.random() - 0.5) * 2 * jag
        pts.append((px - dy / L * o, py + dx / L * o))
    pts.append(b)
    for p, q in zip(pts, pts[1:]):
        fig.capsule_glow(p, q, width, z)


def _capsule_glow(self, a, b, r, z):
    ax, ay = a; bx, by = b
    vx, vy = bx - ax, by - ay; L2 = vx * vx + vy * vy or 1e-9

    def fn(x, y):
        t = max(0.0, min(1.0, ((x - ax) * vx + (y - ay) * vy) / L2))
        d = math.hypot(x - (ax + vx * t), y - (ay + vy * t)) / r
        if d > 1: return None
        return _ramp(GLOW, 1.0 - d * 0.5)
    self.prims.append((z, fn, (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r)))


Figure.capsule_glow = _capsule_glow
