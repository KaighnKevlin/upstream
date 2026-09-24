"""Builds the titan's walk and axe-attack animations as cut-out animation on
the high-res reference (assets/sprites/Sprite-0009.aseprite), then box-filters
each frame down to sprite size in the titan's 26-colour palette.

    python3 tools/art/gen_titan.py [preview_dir]

Writes assets/sprites/titan_walk.png and titan_attack.png (horizontal strips of
FW x FH frames). Everything below is in reference-image pixels.
"""
import math, os, sys
from collections import deque
from titan_lib import *

OUT = SPR
FW, FH = 120, 120           # output frame size (sprite px)
SCALE = 7.3                 # reference px per sprite px
CW, CH = int(FW * SCALE), int(FH * SCALE)   # canvas in reference px
OX, OY = int(48 * SCALE) - 205, CH - 687 - 4  # body centred 48px from the left, feet on the bottom

# ── part masks (polygons in reference coords) ───────────────────────────
LEFT_ARM = [(6, 95), (106, 95), (111, 240), (117, 378), (114, 430), (28, 430), (6, 300)]
RIGHT_ARM = [(281, 160), (370, 148), (374, 300), (364, 382), (340, 428),
             (241, 428), (239, 370), (282, 362), (277, 268)]
PAD_L = [(18, 8), (152, 0), (152, 108), (104, 124), (12, 122)]
PAD_R = [(290, 92), (372, 92), (374, 176), (290, 180)]
FRONT_LEG = [(42, 452), (166, 452), (170, 560), (192, 618), (198, 687), (28, 687), (36, 560)]
BACK_LEG = [(192, 452), (292, 452), (284, 520), (272, 602), (270, 672), (192, 672),
            (163, 610), (166, 540)]
AXE = [(0, 420), (345, 418), (330, 352), (427, 348), (427, 578), (272, 578), (276, 455),
       (40, 455), (36, 482), (0, 482)]

# pivots / attachment points
SHOULDER_L = (62, 120)
SHOULDER_R = (322, 168)
HIP_F = (108, 462)
HIP_B = (240, 468)
GRIP_R = (292, 437)          # where the right hand holds the haft
GRIP_L = (72, 437)


def inside(poly, x, y):
    c = False; j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c


def is_blade(px):
    # light, cool pixels: axe metal (vs the brown leg it overlaps)
    return px[2] > 150 and px[2] >= px[0]


def split_parts(ref, w, h):
    parts = {k: {} for k in ('torso', 'left_arm', 'right_arm', 'axe', 'front_leg',
                             'back_leg', 'pad_l', 'pad_r')}
    for y in range(h):
        for x in range(w):
            px = ref[y][x]
            if px[3] == 0:
                continue
            if inside(PAD_L, x, y): parts['pad_l'][(x, y)] = px
            if inside(PAD_R, x, y): parts['pad_r'][(x, y)] = px
            if inside(LEFT_ARM, x, y): parts['left_arm'][(x, y)] = px
            elif inside(RIGHT_ARM, x, y): parts['right_arm'][(x, y)] = px
            elif inside(AXE, x, y) and (y < 455 or is_blade(px) or x > 300): parts['axe'][(x, y)] = px
            elif inside(FRONT_LEG, x, y): parts['front_leg'][(x, y)] = px
            elif inside(BACK_LEG, x, y): parts['back_leg'][(x, y)] = px
            else: parts['torso'][(x, y)] = px
    _inpaint_torso(parts['torso'])
    return parts


def _inpaint_torso(torso):
    """Fill the gaps the arms/haft leave in the torso, between x 108 and 292,
    by growing neighbouring torso colours inward."""
    hull = set()
    for y in range(90, 470):
        row = [x for x in range(100, 300) if (x, y) in torso]
        if len(row) > 4:
            for x in range(max(108, min(row)), min(292, max(row)) + 1):
                hull.add((x, y))
    # torso flanks the arms hid: widen a little, tapering to the waist, so a
    # raised arm doesn't leave a ruler-straight edge
    for y in range(130, 415):
        t = (y - 130) / 285.0
        left = int(96 + 8 * t); right = int(304 - 8 * t)
        for x in range(left, 112):
            hull.add((x, y))
        for x in range(288, right):
            hull.add((x, y))
    # the waist behind the haft (it has no torso pixels at all to seed a row)
    for y in range(415, 468):
        for x in range(112, 290):
            hull.add((x, y))
    # waist band: repeat the armour plates just above it, so it reads as
    # plating rather than smeared stripes
    for y in range(415, 468):
        for x in range(112, 290):
            if (x, y) not in torso:
                for k in (36, 72):
                    src = torso.get((x, y - k))
                    if src and y - k < 415:
                        torso[(x, y)] = src; break
    # stray bits left of the body where the haft knob was
    for p in [p for p in torso if p[0] < 44 and p[1] > 400]:
        del torso[p]
    todo = deque(p for p in hull if p not in torso)
    missing = set(todo)
    for _ in range(40):
        if not missing: break
        grown = {}
        for (x, y) in missing:
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                n = (x + dx, y + dy)
                if n in torso:
                    grown[(x, y)] = torso[n]; break
        for p, c in grown.items(): torso[p] = c
        missing -= set(grown)


def rot(p, pivot, deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    x, y = p[0] - pivot[0], p[1] - pivot[1]
    return (pivot[0] + x * c - y * s, pivot[1] + x * s + y * c)


# 2D affine transforms as (a, b, c, d, tx, ty): p' = (a*x + b*y + tx, c*x + d*y + ty)
IDENT = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def m_rot(deg, pivot=(0, 0)):
    r = math.radians(deg); c, s = math.cos(r), math.sin(r)
    px, py = pivot
    return (c, -s, s, c, px - c * px + s * py, py - s * px - c * py)


def m_tr(dx, dy):
    return (1.0, 0.0, 0.0, 1.0, dx, dy)


def m_mul(A, B):
    """A after B."""
    a1, b1, c1, d1, x1, y1 = A; a2, b2, c2, d2, x2, y2 = B
    return (a1 * a2 + b1 * c2, a1 * b2 + b1 * d2, c1 * a2 + d1 * c2, c1 * b2 + d1 * d2,
            a1 * x2 + b1 * y2 + x1, c1 * x2 + d1 * y2 + y1)


def m_apply(M, p):
    a, b, c, d, tx, ty = M
    return (a * p[0] + b * p[1] + tx, c * p[0] + d * p[1] + ty)


def blit_m(canvas, part, M, remap=None):
    """Draw part through affine M (nearest sampling via the inverse, so no
    holes). remap: optional {rgba: rgba} colour substitution."""
    if not part: return
    xs = [p[0] for p in part]; ys = [p[1] for p in part]
    corners = [m_apply(M, c) for c in ((min(xs), min(ys)), (max(xs), min(ys)),
                                       (min(xs), max(ys)), (max(xs), max(ys)))]
    x0 = int(min(c[0] for c in corners)) - 1; x1 = int(max(c[0] for c in corners)) + 2
    y0 = int(min(c[1] for c in corners)) - 1; y1 = int(max(c[1] for c in corners)) + 2
    a, b, c, d, tx, ty = M
    det = a * d - b * c
    ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
    for y in range(y0, y1):
        cy = y + OY
        if cy < 0 or cy >= CH: continue
        for x in range(x0, x1):
            cx = x + OX
            if cx < 0 or cx >= CW: continue
            rx, ry = x - tx, y - ty
            px = part.get((int(round(ia * rx + ib * ry)), int(round(ic * rx + id_ * ry))))
            if px:
                canvas[cy][cx] = remap.get(px, px) if remap else px


def blit(canvas, part, pivot=(0, 0), deg=0.0, dx=0.0, dy=0.0, remap=None):
    """Rotate part by deg around pivot, then translate."""
    blit_m(canvas, part, m_mul(m_tr(dx, dy), m_rot(deg, pivot)), remap)


ARM_L = math.dist(SHOULDER_L, GRIP_L)
ARM_R = math.dist(SHOULDER_R, GRIP_R)
GRIP_C = ((GRIP_L[0] + GRIP_R[0]) / 2, (GRIP_L[1] + GRIP_R[1]) / 2)


def _angle(v):
    return math.degrees(math.atan2(v[1], v[0]))


def solve_arms(axe_c, axe_deg, prev=(0.0, 0.0)):
    """Arm rotations (deg, around the shoulders) that point each hand at its
    grip on an axe centred at axe_c and rotated axe_deg. Picks the equivalent
    angle closest to prev so arms don't spin the long way round."""
    out = []
    for shoulder, grip, p in ((SHOULDER_L, GRIP_L, prev[0]), (SHOULDER_R, GRIP_R, prev[1])):
        g = rot((axe_c[0] + grip[0] - GRIP_C[0], axe_c[1] + grip[1] - GRIP_C[1]), axe_c, axe_deg)
        rest = _angle((grip[0] - shoulder[0], grip[1] - shoulder[1]))
        want = _angle((g[0] - shoulder[0], g[1] - shoulder[1]))
        d = want - rest
        while d - p > 180: d -= 360
        while d - p < -180: d += 360
        out.append(d)
    return tuple(out)


def resolve(poses):
    """Turn 'axe_at' (centre, angle) keys into arm angles, carrying continuity."""
    prev = (0.0, 0.0)
    for p in poses:
        if 'axe_at' in p:
            c, deg = p['axe_at']
            p['arms'] = solve_arms(c, deg, prev)
            p['axe'] = deg
            keys = p.get('smear_at', [])
            dense = []
            for i in range(len(keys) - 1):
                (c0, d0), (c1, d1) = keys[i], keys[i + 1]
                for k in range(4):
                    t = k / 4
                    dense.append(((c0[0] + (c1[0] - c0[0]) * t, c0[1] + (c1[1] - c0[1]) * t),
                                  d0 + (d1 - d0) * t))
            if keys: dense.append(keys[-1])
            p['smear'] = [(solve_arms(sc, sd, prev)[1], sd, min(2, 3 * i // max(1, len(dense))))
                          for i, (sc, sd) in enumerate(dense)]
        prev = p.get('arms', (0, 0))
    return poses


def render(parts, pose):
    """pose: body (dx,dy); legs (front, back) degrees; arms (left, right) degrees
    around the shoulders; axe degrees around the right grip, placed in the
    right hand; smear: list of previous axe angles/arm angles for a motion trail."""
    canvas = [[(0, 0, 0, 0)] * CW for _ in range(CH)]
    bx, by = pose.get('body', (0, 0))
    lf, lb = pose.get('legs', (0, 0))
    al, ar = pose.get('arms', (0, 0))
    ax = pose.get('axe', 0)
    # legs stay planted-ish: they only take half the body bob
    blit(canvas, parts['back_leg'], HIP_B, lb, bx * 0.5, by * 0.5)
    blit(canvas, parts['left_arm'], SHOULDER_L, al, bx, by) if pose.get('left_behind') else None
    blit(canvas, parts['front_leg'], HIP_F, lf, bx * 0.5, by * 0.5)
    blit(canvas, parts['torso'], (0, 0), 0, bx, by)
    if not pose.get('left_behind'):
        blit(canvas, parts['left_arm'], SHOULDER_L, al, bx, by)
    # axe follows the right hand
    hand = rot(GRIP_R, SHOULDER_R, ar)
    for ar_s, ax_s, shade in pose.get('smear', []):
        _smear(canvas, parts['axe'], (ar_s, ax_s), bx, by, shade)
    blit(canvas, parts['axe'], GRIP_R, ax, hand[0] - GRIP_R[0] + bx, hand[1] - GRIP_R[1] + by)
    blit(canvas, parts['right_arm'], SHOULDER_R, ar, bx, by)
    blit(canvas, parts['pad_l'], (0, 0), 0, bx, by)
    blit(canvas, parts['pad_r'], (0, 0), 0, bx, by)
    return canvas


SMEAR_COLS = [(144, 188, 196, 255), (171, 211, 212, 255), (205, 227, 220, 255)]


def _smear(canvas, axe, trail, bx, by, shade=1):
    """Motion smear: the blade head stamped flat at an in-between pose.
    Stamped densely, the stamps merge into one swept shape."""
    ar, ax = trail
    hand = rot(GRIP_R, SHOULDER_R, ar)
    ghost = {p: SMEAR_COLS[shade] for p, c in axe.items() if p[0] > 270 and (is_blade(c) or p[1] > 455)}
    blit(canvas, ghost, GRIP_R, ax, hand[0] - GRIP_R[0] + bx, hand[1] - GRIP_R[1] + by)


def lerp_pose(a, b, t):
    out = {}
    for k in ('body', 'legs', 'arms'):
        va, vb = a.get(k, (0, 0)), b.get(k, (0, 0))
        out[k] = (va[0] + (vb[0] - va[0]) * t, va[1] + (vb[1] - va[1]) * t)
    out['axe'] = a.get('axe', 0) + (b.get('axe', 0) - a.get('axe', 0)) * t
    return out


# ── animations ──────────────────────────────────────────────────────────

def walk_poses(n=8):
    poses = []
    for i in range(n):
        t = i / n * 2 * math.pi
        s = math.sin(t)
        poses.append({
            'body': (0, 12 * abs(s)),             # sinks as the stride opens
            'legs': (19 * s, -19 * s),
            'arms': (-3 * s, -3 * s),             # slight counter-sway
            'axe': -3 * s,
        })
    return poses


ATTACK = resolve([
    # axe_at: (axe centre, axe angle); arms follow by IK. Body (dx, dy) leans,
    # legs (front, back) rotate at the hips (negative = foot forward/right).
    # rest → wind-up → overhead → chop (smear) → impact → hold → recover
    {'body': (0, 4), 'axe_at': ((182, 437), 0)},
    {'body': (-8, 12), 'legs': (6, -4), 'axe_at': ((150, 330), -45)},
    {'body': (-14, 2), 'legs': (8, -6), 'axe_at': ((150, 170), -105)},
    {'body': (-18, -6), 'legs': (8, -8), 'axe_at': ((175, 70), -150)},
    {'body': (-2, 4), 'legs': (0, -2), 'axe_at': ((255, 150), -45),
     'smear_at': [((185, 85), -140), ((200, 100), -120), ((218, 115), -100),
                  ((232, 128), -82), ((245, 140), -64)]},
    {'body': (14, 22), 'legs': (-14, 6), 'axe_at': ((282, 345), 70),
     'smear_at': [((262, 190), -25), ((268, 230), 0), ((274, 270), 22), ((280, 310), 45)]},
    {'body': (12, 20), 'legs': (-14, 6), 'axe_at': ((280, 340), 66)},
    {'body': (5, 10), 'legs': (-6, 3), 'axe_at': ((235, 400), 25)},
])


SWEEP = resolve([
    # low rising sweep: wind the axe back behind, scoop it low across the
    # ground, follow through high in front. Impact on frame 4.
    {'body': (0, 4), 'axe_at': ((182, 437), 0)},
    {'body': (-10, 8), 'legs': (4, -4), 'axe_at': ((110, 410), 150)},
    {'body': (-16, 12), 'legs': (8, -6), 'axe_at': ((95, 400), 175)},
    {'body': (0, 16), 'legs': (0, 0), 'axe_at': ((190, 470), 95),
     'smear_at': [((105, 410), 170), ((130, 440), 145), ((160, 462), 120), ((190, 470), 95)]},
    {'body': (14, 10), 'legs': (-12, 6), 'axe_at': ((290, 380), -10),
     'smear_at': [((215, 470), 65), ((250, 450), 35), ((275, 415), 10)]},
    {'body': (12, 4), 'legs': (-12, 6), 'axe_at': ((300, 300), -45)},
    {'body': (6, 4), 'legs': (-5, 3), 'axe_at': ((240, 380), -15)},
    {'body': (1, 4), 'axe_at': ((190, 432), -3)},
])


def build(poses, parts, pal):
    frames = []
    for p in poses:
        canvas = render(parts, p)
        frames.append(downscale(canvas, CW, CH, FW, FH, pal, scale=SCALE))
    return frames


def strip(frames):
    rows = []
    for y in range(FH):
        row = []
        for f in frames: row += f[y]
        rows.append(row)
    return rows


def main():
    w, h, ref = load_reference()
    pal = load_palette()
    parts = split_parts(ref, w, h)
    walk = build(walk_poses(), parts, pal)
    attack = build(ATTACK, parts, pal)
    sweep = build(SWEEP, parts, pal)
    write_png(OUT + 'titan_walk.png', FW * len(walk), FH, strip(walk))
    write_png(OUT + 'titan_attack.png', FW * len(attack), FH, strip(attack))
    write_png(OUT + 'titan_sweep.png', FW * len(sweep), FH, strip(sweep))
    print('wrote titan_walk.png (%d frames), titan_attack.png (%d frames)' % (len(walk), len(attack)))
    if len(sys.argv) > 1:
        d = sys.argv[1]
        big = side_by_side(walk, 4); write_png(d + '/titan_walk_preview.png', len(big[0]), len(big), big)
        big = side_by_side(attack, 4); write_png(d + '/titan_attack_preview.png', len(big[0]), len(big), big)
        big = side_by_side(sweep, 4); write_png(d + '/titan_sweep_preview.png', len(big[0]), len(big), big)
        write_gif(d + '/titan_sweep.gif', sweep + [sweep[0]], [10, 9, 12, 5, 6, 14, 10, 10, 40], 4)
        # part map for checking the masks
        colors = {'torso': (200, 160, 90), 'left_arm': (80, 160, 255), 'right_arm': (60, 220, 160),
                  'axe': (240, 240, 240), 'front_leg': (230, 90, 90), 'back_leg': (170, 60, 200),
                  'pad_l': (255, 220, 0), 'pad_r': (255, 140, 0)}
        m = [[(20, 20, 26, 255)] * w for _ in range(h)]
        for name, pts in parts.items():
            for (x, y) in pts:
                if 0 <= x < w and 0 <= y < h:
                    src = ref[y][x] if ref[y][x][3] else (120, 120, 120, 255)
                    col = colors[name]
                    m[y][x] = tuple((src[i] + col[i] * 2) // 3 for i in range(3)) + (255,)
        write_png(d + '/titan_parts.png', w, h, m)





# ── idle and death: whole-body transforms ───────────────────────────────

HIP_C = (175, 458)      # between the hips: the body tips around this
# glowing-core colours (palette cyans) and what they become
_hex = lambda h: (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
GLOW = [_hex(h) for h in ('73bac3', '78c6cd', '90bcc4', 'abd3d4', 'cde3dc')]
PULSE = dict(zip(GLOW, [_hex(h) for h in ('90bcc4', 'abd3d4', 'cde3dc', 'cde3dc', 'cde3dc')]))
DIM = [dict(zip(GLOW, [_hex(h) for h in row])) for row in (
    ('709092', '738877', '709092', '90bcc4', 'abd3d4'),   # flickering
    ('5f7c83', '5f7c83', '709092', '709092', '93a29c'),   # dying
    ('4f3d43', '4f3d43', '5f7c83', '5f7c83', '605d55'),   # dark
)]


def render_body(parts, pose):
    """Like render(), but the upper body (torso, pads, arms, held axe) takes a
    tilt around HIP_C, and the axe can be let go ('axe_free': (x, y, deg)).
    pose['glow']: None, 'pulse' or 0-2 (dimming stages)."""
    canvas = [[(0, 0, 0, 0)] * CW for _ in range(CH)]
    bx, by = pose.get('body', (0, 0))
    tilt = pose.get('tilt', 0)
    lf, lb = pose.get('legs', (0, 0))
    lx, ly = pose.get('legs_shift', (bx * 0.5, by * 0.5))
    al, ar = pose.get('arms', (0, 0))
    g = pose.get('glow')
    remap = PULSE if g == 'pulse' else (DIM[g] if isinstance(g, int) else None)
    B = m_mul(m_tr(bx, by), m_rot(tilt, HIP_C))
    blit_m(canvas, parts['back_leg'], m_mul(m_tr(lx, ly), m_rot(lb, HIP_B)), remap)
    fx_, fy_ = pose.get('front_lift', (0, 0))   # knee-up: slide the front leg up under the hip
    blit_m(canvas, parts['front_leg'], m_mul(m_tr(lx + fx_, ly + fy_), m_rot(lf, HIP_F)), remap)
    free = pose.get('axe_free')
    free_m = None
    if free:  # dropped axe: offset from its resting place, rotated about its middle
        fx, fy, fdeg = free
        free_m = m_mul(m_tr(fx, fy), m_rot(fdeg, GRIP_C))
        if not pose.get('axe_front'):
            blit_m(canvas, parts['axe'], free_m)
    blit_m(canvas, parts['torso'], B, remap)
    blit_m(canvas, parts['left_arm'], m_mul(B, m_rot(al, SHOULDER_L)), remap)
    if not free:
        hand = rot(GRIP_R, SHOULDER_R, ar)
        axe_m = m_mul(B, m_mul(m_tr(hand[0] - GRIP_R[0], hand[1] - GRIP_R[1]),
                               m_rot(pose.get('axe', 0), GRIP_R)))
        blit_m(canvas, parts['axe'], axe_m)
    blit_m(canvas, parts['right_arm'], m_mul(B, m_rot(ar, SHOULDER_R)), remap)
    blit_m(canvas, parts['pad_l'], B, remap)
    blit_m(canvas, parts['pad_r'], B, remap)
    if free_m and pose.get('axe_front'):
        blit_m(canvas, parts['axe'], free_m)
    return canvas


def idle_poses(n=6):
    poses = []
    for i in range(n):
        s = math.sin(i / n * 2 * math.pi)
        poses.append({'body': (0, 4 + 4 * s), 'legs_shift': (0, 0), 'arms': (1.5 * s, 1.5 * s),
                      'axe': 1.5 * s, 'glow': 'pulse' if i in (1, 2) else None})
    return poses


LEG_LEN = 225   # hip to sole, reference px
LEG_HALF = 40   # half a leg's thickness


def _hip_drop(deg):
    """How far the hips sink when both legs fold to deg, feet on the ground."""
    r = math.radians(deg)
    return 687 - LEG_LEN * math.cos(r) - LEG_HALF * math.sin(r) - 462


def _death_pose(legs, dx, tilt, arms, glow, axe=None, axe_front=False, bounce=0):
    d = max(0.0, _hip_drop(legs))
    return {'body': (dx, d - bounce), 'tilt': tilt, 'legs': (legs, legs), 'legs_shift': (dx * 0.4, d),
            'arms': arms, 'glow': glow, 'axe_free': axe, 'axe_front': axe_front}


# recoil → knees give → pitches forward, axe slips and lands in front →
# face down, one settle bounce, core fades out
DEATH = [
    {'body': (-6, 0), 'tilt': -6, 'arms': (8, 6), 'glow': None},
    _death_pose(10, 4, 6, (-4, -8), 0),
    _death_pose(26, 10, 16, (-10, -16), 0, axe=(30, 40, 25)),
    _death_pose(46, 20, 34, (-18, -24), 1, axe=(80, 95, 12)),
    _death_pose(64, 34, 56, (-30, -36), 1, axe=(125, 112, -4), axe_front=True),
    _death_pose(78, 46, 78, (-44, -48), 2, axe=(125, 112, -4), axe_front=True),
    _death_pose(78, 46, 76, (-44, -48), 2, axe=(125, 112, -4), axe_front=True, bounce=8),
    _death_pose(78, 46, 78, (-44, -48), 2, axe=(125, 112, -4), axe_front=True),
]


# stomp: axe raised across the chest, weight back, front leg swings up,
# slams down (impact frame 4) and the body drops into it, core flaring.
STOMP = resolve([
    {'body': (0, 4), 'legs_shift': (0, 2), 'axe_at': ((182, 437), 0)},
    {'body': (-8, 8), 'legs_shift': (-2, 4), 'legs': (-4, 2), 'axe_at': ((190, 380), -12)},
    {'body': (-14, 0), 'tilt': -5, 'legs_shift': (-4, 5), 'legs': (-22, -2), 'front_lift': (10, -60), 'axe_at': ((185, 250), -30), 'glow': 'pulse'},
    {'body': (-16, -4), 'tilt': -9, 'legs_shift': (-5, 5), 'legs': (-30, -4), 'front_lift': (18, -105), 'axe_at': ((185, 215), -36), 'glow': 'pulse'},
    {'body': (8, 26), 'tilt': 5, 'legs_shift': (4, 12), 'legs': (-8, 6), 'axe_at': ((205, 420), 8), 'glow': 'pulse'},
    {'body': (8, 24), 'tilt': 4, 'legs_shift': (4, 11), 'legs': (-8, 6), 'axe_at': ((205, 420), 8)},
    {'body': (4, 14), 'tilt': 2, 'legs_shift': (2, 7), 'legs': (-4, 3), 'axe_at': ((192, 430), 3)},
    {'body': (0, 6), 'legs_shift': (0, 3), 'axe_at': ((182, 437), 0)},
])


def build_body(poses, parts, pal):
    return [downscale(render_body(parts, p), CW, CH, FW, FH, pal, scale=SCALE) for p in poses]


def main_extra(preview=None):
    w, h, ref = load_reference()
    pal = load_palette()
    parts = split_parts(ref, w, h)
    idle = build_body(idle_poses(), parts, pal)
    death = build_body(DEATH, parts, pal)
    write_png(OUT + 'titan_idle.png', FW * len(idle), FH, strip(idle))
    write_png(OUT + 'titan_death.png', FW * len(death), FH, strip(death))
    stomp = build_body(STOMP, parts, pal)
    write_png(OUT + 'titan_stomp.png', FW * len(stomp), FH, strip(stomp))
    print('wrote titan_idle.png (%d), titan_death.png (%d)' % (len(idle), len(death)))
    if preview:
        big = side_by_side(idle, 4); write_png(preview + '/titan_idle_preview.png', len(big[0]), len(big), big)
        big = side_by_side(death, 4); write_png(preview + '/titan_death_preview.png', len(big[0]), len(big), big)
        big = side_by_side(stomp, 4); write_png(preview + '/titan_stomp_preview.png', len(big[0]), len(big), big)
        return
        write_gif(preview + '/titan_idle.gif', idle, [14] * len(idle), 4)
        write_gif(preview + '/titan_death.gif', death + [death[-1]], [8, 8, 8, 8, 8, 10, 12, 80, 60], 4)


if __name__ == '__main__':
    if os.environ.get('ONLY_EXTRA') is None:
        main()
    main_extra(sys.argv[1] if len(sys.argv) > 1 else None)
