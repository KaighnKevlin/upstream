"""Ore chunks, brass ingots and the spring trampoline.

    python3 tools/art/gen_items.py [preview_dir]

Writes assets/sprites/ore.png (5 faceted variants, 12x12 each), ingot.png (14x8) and
trampoline.png (44x22: brass plate on a steel coil; the plate's top is
3px from the top edge).
"""
import math, random, sys
from clockwork import *
from clockwork import _hex
from pixtools import write_png, write_gif
from titan_lib import SPR, side_by_side


ORE_ROCK_EXTRA = ['2a221c', '46382d', '62503f', '7e6a55', 'a08a6e', 'c2ad8e']
ORE_ROCK = [_hex(h) for h in ORE_ROCK_EXTRA]
# iron ore: cold blue-grey slate, dense and blocky, with dull magnetite
# nodules and rust weeping from them
IRON_ROCK_EXTRA = ['1f2126', '2e333b', '414852', '58616b', '737d86', '939ca3']
IRON_ROCK = [_hex(h) for h in IRON_ROCK_EXTRA]
MAGNETITE_EXTRA = ['24262b', '3a3e46', '5a6068', '8a929a', 'c4ccd2']
MAGNETITE = [_hex(h) for h in MAGNETITE_EXTRA]
RUST_EXTRA = ['5a2a14', '8a4220', 'b0602c']
RUST = [_hex(h) for h in RUST_EXTRA]


def ore(seed, kind='copper'):
    """Faceted chunk of warm stone with bright copper nuggets (or, for iron,
    cold dense slate with magnetite nodules and rust). Facets are triangles
    fanned from an off-centre apex, each shaded by how much it faces the
    light (top-left), so the chunk reads as a solid lump."""
    iron = kind == 'iron'
    r = random.Random(seed)
    n = r.randint(5, 6) if iron else r.randint(6, 7)   # iron: blockier
    pts = []
    for k in range(n):
        a = k / n * math.tau + r.uniform(-0.25, 0.25)
        rad = r.uniform(4.9, 5.7) if iron else r.uniform(4.3, 5.6)
        pts.append((math.cos(a) * rad, math.sin(a) * rad * 0.9))
    apex = (r.uniform(-1.2, 0.2), r.uniform(-1.4, -0.2))       # ridge leans to the light
    fig = Figure()
    light = (-0.6, -0.8)
    for k in range(n):
        p0, p1 = pts[k], pts[(k + 1) % n]
        mx, my = (p0[0] + p1[0]) / 2 - apex[0], (p0[1] + p1[1]) / 2 - apex[1]
        L = math.hypot(mx, my) or 1
        facing = (mx * light[0] + my * light[1]) / L            # -1..1
        fig.poly([apex, p0, p1], IRON_ROCK if iron else ORE_ROCK, z=0, shade=0.45 + 0.4 * facing, grit=0.06)
    if iron:
        for k in range(r.randint(2, 3)):                          # magnetite nodules, rust below
            a = r.uniform(0, math.tau); d = r.uniform(0.5, 2.6)
            c = (apex[0] + math.cos(a) * d, apex[1] + math.sin(a) * d + 0.8)
            fig.capsule((c[0], c[1] + 0.8), (c[0] + r.uniform(-0.6, 0.6), c[1] + 2.4), 0.55, RUST, z=0.9)
            fig.sphere(c, r.uniform(1.0, 1.4), MAGNETITE, z=1, grit=0.02)
        fig.sphere((apex[0] - 0.8, apex[1] - 0.6), 0.45, [(205, 222, 232)] * 2, z=2, emissive=True)  # cold glint
        return fig.render(12, 12, (6, 6), extra=IRON_ROCK_EXTRA + MAGNETITE_EXTRA + RUST_EXTRA + ['cddee8'])
    for k in range(r.randint(2, 3)):                              # copper nuggets
        a = r.uniform(0, math.tau); d = r.uniform(0.5, 2.8)
        c = (apex[0] + math.cos(a) * d, apex[1] + math.sin(a) * d + 0.8)
        fig.sphere(c, r.uniform(1.0, 1.5), COPPER, z=1, grit=0.02)
    fig.sphere((apex[0] - 0.8, apex[1] - 0.6), 0.45, [(255, 240, 210)] * 2, z=2, emissive=True)  # glint
    return fig.render(12, 12, (6, 6), extra=COPPER_EXTRA + ORE_ROCK_EXTRA + ['fff0d2'])


def ingot(kind='copper'):
    mat = STEEL if kind == 'iron' else BRONZE    # iron: a gunmetal bar
    fig = Figure()
    fig.box((-6, -2.6, 6, 2.6), mat, z=0, bevel=1.6, grit=0.03)
    fig.box((-4.6, -2.6, 4.6, -0.6), mat, z=1, bevel=1.0, grit=0.02)    # raised top face
    if kind == 'iron':
        fig.capsule((-3.5, 1.2), (3.5, 1.2), 0.35, DARK, z=1.1)          # cast seam
    return fig.render(14, 8, (7, 4))


def shot():
    """Iron shot: a small cast ball, dark and heavy, one bright glint."""
    fig = Figure()
    fig.sphere((0, 0), 3.2, STEEL, z=0, grit=0.02)
    fig.sphere((-1.1, -1.2), 0.5, [(215, 228, 232)] * 2, z=1, emissive=True)
    return fig.render(8, 8, (4, 4))


def flask():
    """Science flask: a round-bottomed glass flask of glowing red tincture,
    brass-capped. Fragile."""
    fig = Figure()
    GLASS = [(41, 38, 31), (74, 96, 104), (112, 150, 158), (160, 196, 200), (205, 228, 230)]
    RED = [(60, 18, 20), (120, 30, 32), (180, 52, 44), (230, 92, 64), (255, 160, 110)]
    fig.sphere((0, 2), 4.4, GLASS, z=0, grit=0.01)
    fig.ellipsoid((0, 3.2), (3.7, 2.7), RED, z=0.5, emissive=True)      # the tincture
    fig.capsule((0, -2), (0, -4.5), 1.6, GLASS, z=0.4)                   # neck
    fig.ellipsoid((0, -5.2), (2.1, 0.9), BRONZE, z=1)                   # cap
    fig.sphere((-1.8, 0.5), 0.6, [(235, 245, 245)] * 2, z=1.1, emissive=True)  # glint
    return fig.render(12, 14, (6, 7), extra=['4a6068', '70969e', 'a0c4c8', 'cde4e6', '3c1214', '781e20', 'b4342c', 'e65c40', 'ffa06e', 'ebf5f5'])


def spring():
    """Springsteel coil: an open steel helix between two brass end caps, seen
    side-on. Bounces off nearly everything, enemies included."""
    fig = Figure()
    for k in range(4):
        x = -3.3 + k * 2.2
        fig.capsule((x, 3.4), (x + 1.1, -3.4), 0.5, STEEL, z=1)              # front of each turn
        if k < 3:
            fig.capsule((x + 1.1, -3.4), (x + 2.2, 3.4), 0.35, DARK, z=0.2)  # back of the turn
    fig.capsule((-4.6, -3.8), (-4.6, 3.8), 0.7, BRONZE, z=1.5)
    fig.capsule((4.6, -3.8), (4.6, 3.8), 0.7, BRONZE, z=1.5)
    return fig.render(12, 12, (6, 6))


def scrap(v):
    """Wreckage from a destroyed automaton: a bent riveted plate, a snapped
    gear segment, a twisted rod with a bolt, a dented boiler shard."""
    fig = Figure()
    if v == 0:
        fig.poly([(-4.5, -2), (1, -4), (4.5, -1), (3, 3.5), (-3, 3)], BRONZE, z=0, shade=0.8)
        fig.sphere((-1.5, 0), 0.6, STEEL, z=1)
        fig.sphere((2, 0.5), 0.6, STEEL, z=1)
    elif v == 1:
        fig.gear((1.5, 1.5), 4.8, 9, 10, STEEL, z=0)
        fig.disc((1.5, 1.5), 2.0, DARK, z=0.6)
    elif v == 2:
        fig.capsule((-4.5, 2.5), (0, -1), 0.9, STEEL, z=0)
        fig.capsule((0, -1), (4, -3), 0.9, STEEL, z=0.1)
        fig.ellipsoid((-4, 2.5), (1.6, 1.4), BRONZE, z=0.5)
    else:
        fig.ellipsoid((0, 0), (4.5, 3.5), STEEL, z=0, grit=0.1)
        fig.ellipsoid((-1, -0.8), (2.5, 1.6), DARK, z=0.3)
        fig.sphere((2.5, 1.5), 0.6, BRONZE, z=0.6)
    return fig.render(12, 12, (6, 6))


def shell():
    """Blast shell: a squat riveted iron canister packed with crushed grit,
    a red warning band and a brass percussion cap."""
    fig = Figure()
    fig.ellipsoid((0, 0.5), (3.6, 4.0), STEEL, z=0, grit=0.04)
    fig.box((-3.6, -0.6, 3.6, 1.2), [(80, 20, 18), (150, 40, 32), (200, 70, 50)], z=0.5, bevel=0.3)
    fig.ellipsoid((0, -3.6), (1.8, 1.0), BRONZE, z=1)
    fig.sphere((0, -4.3), 0.7, [(255, 200, 120)] * 2, z=1.1, emissive=True)
    fig.sphere((-1.6, 2.6), 0.45, BRONZE, z=0.6)
    fig.sphere((1.6, 2.6), 0.45, BRONZE, z=0.6)
    return fig.render(10, 11, (5, 5))


def gear():
    """A loose brass-and-steel gear: rolls like a wheel."""
    fig = Figure()
    fig.gear((0, 0), 6.2, 10, 0, BRONZE, z=0)
    fig.disc((0, 0), 3.0, DARK, z=0.5)
    fig.gear((0, 0), 2.6, 6, 15, STEEL, z=1)
    fig.disc((0, 0), 0.9, DARK, z=1.1)
    return fig.render(16, 16, (8, 8))


def trampoline():
    fig = Figure()
    # riveted base
    fig.box((-11, 14, 11, 18), DARK, z=0, bevel=1.2)
    for x in (-8, 8):
        fig.sphere((x, 16), 0.8, STEEL, z=0.5)
    # the coil: 3 turns, front strands bright, back strands dark, gaps between
    top, bot, turns = 6.0, 14.0, 3
    n = turns * 2
    for k in range(n):
        y0 = bot + (top - bot) * k / n; y1 = bot + (top - bot) * (k + 1) / n
        front = k % 2 == 0
        fig.capsule((-5 if front else 5, y0), (5 if front else -5, y1), 0.65,
                    STEEL if front else DARK, z=2 if front else 1, grit=0.02)
    # guide posts
    for x in (-9, 9):
        fig.capsule((x, 5.5), (x, 14), 0.7, BRONZE, z=1.5)
    # the brass plate on top, with a dark grip strip
    fig.box((-20, 1.5, 20, 6.0), BRONZE, z=3, bevel=1.5)
    fig.box((-18, 0.3, 18, 2.2), DARK, z=3.5, bevel=0.6, grit=0.02)
    for x in (-17, 17):
        fig.sphere((x, 4.4), 0.8, STEEL, z=3.6)
    return fig.render(44, 22, (22, 3))


# Split trampoline: a fixed base, and a spring + plate that the game tilts to
# the launch angle (the plate faces where it throws) and animates on a hit.
SPRING_REST = 8.0
TOP_FW, TOP_FH, TOP_O = 48, 28, (24, 26)     # pivot (spring foot) at TOP_O


def tramp_base():
    fig = Figure()
    fig.box((-12, 0, 12, 4.5), DARK, z=0, bevel=1.2)
    for x in (-9, 9):
        fig.sphere((x, 2.3), 0.8, STEEL, z=0.5)
    # brass hinge block the spring stands on
    fig.box((-4, -1.5, 4, 1.5), BRONZE, z=1, bevel=0.8)
    fig.disc((0, 0), 1.1, STEEL, z=1.2)
    return fig.render(28, 8, (14, 2))


def tramp_top(length, splay=0.0):
    """Spring of `length` px from the pivot (0, 0) up to the plate.
    splay widens the coil when it's crushed."""
    fig = Figure()
    turns = 3
    n = turns * 2
    w = 5 + splay
    for k in range(n):
        y0 = -length * k / n; y1 = -length * (k + 1) / n
        front = k % 2 == 0
        fig.capsule((-w if front else w, y0), (w if front else -w, y1), 0.65,
                    STEEL if front else DARK, z=2 if front else 1, grit=0.02)
    for x in (-8, 8):  # telescoping guide rods
        fig.capsule((x * 0.9, -0.5), (x, -length), 0.6, BRONZE, z=1.5)
    top = -length
    fig.box((-20, top - 4.5, 20, top), BRONZE, z=3, bevel=1.5)
    fig.box((-18, top - 5.7, 18, top - 3.8), DARK, z=3.5, bevel=0.6, grit=0.02)
    for x in (-17, 17):
        fig.sphere((x, top - 1.6), 0.8, STEEL, z=3.6)
    fig.sphere((0, top - 1.8), 1.1, GLOW, z=3.7, emissive=True)   # little status core
    return fig.render(TOP_FW, TOP_FH, TOP_O)


# rest, then on a hit: crush, bottom out, rebound past rest, settle
TRAMP_FRAMES = [(SPRING_REST, 0), (5.0, 1.0), (3.2, 2.0), (6.5, 0.8), (11.0, 0), (7.0, 0.3), (8.8, 0), (SPRING_REST, 0)]


def debris():
    """Clockwork debris for deaths: 6 pieces, 8x8 each."""
    pieces = []
    f = Figure(); f.gear((0, 0), 3.0, 7, 10, BRONZE); pieces.append(f)          # brass gear
    f = Figure(); f.gear((0, 0), 2.6, 6, 0, STEEL); pieces.append(f)            # steel gear
    f = Figure(); f.box((-2, -2, 2, 2), STEEL, bevel=0.8, tilt=30)              # hex-ish bolt
    f.disc((0, 0), 0.8, DARK); pieces.append(f)
    f = Figure()                                                               # coil spring
    for k in range(4):
        f.capsule((-2.5, -3 + k * 1.6), (2.5, -2.2 + k * 1.6), 0.45, STEEL, z=k)
    pieces.append(f)
    f = Figure(); f.box((-3, -1.5, 3, 1.5), BRONZE, bevel=0.8, tilt=-20)        # plate shard
    f.sphere((-1.5, 0), 0.5, STEEL, z=1); pieces.append(f)
    f = Figure(); f.ellipsoid((0, 0), (2.4, 1.5), GLOW, emissive=True, tilt=40); pieces.append(f)  # core glass
    return [p.render(8, 8, (4, 4)) for p in pieces]


def main():
    ores = [ore(s) for s in (3, 8, 13, 21, 34)]
    rows = [sum((f[y] for f in ores), []) for y in range(12)]
    write_png(SPR + 'ore.png', 12 * len(ores), 12, rows)
    irons = [ore(s, 'iron') for s in (4, 9, 15, 22, 35)]
    write_png(SPR + 'ore_iron.png', 12 * len(irons), 12, [sum((f[y] for f in irons), []) for y in range(12)])
    ing = ingot(); write_png(SPR + 'ingot.png', 14, 8, ing)
    write_png(SPR + 'ingot_iron.png', 14, 8, ingot('iron'))
    write_png(SPR + 'iron_shot.png', 8, 8, shot())
    write_png(SPR + 'gear_item.png', 16, 16, gear())
    write_png(SPR + 'flask.png', 12, 14, flask())
    write_png(SPR + 'spring_item.png', 12, 12, spring())
    write_png(SPR + 'shell.png', 10, 11, shell())
    sc = [scrap(v) for v in range(4)]
    write_png(SPR + 'scrap.png', 48, 12, [sum((f[y] for f in sc), []) for y in range(12)])
    tr = trampoline(); write_png(SPR + 'trampoline.png', 44, 22, tr)
    write_png(SPR + 'trampoline_base.png', 28, 8, tramp_base())
    tops = [tramp_top(l, sp) for l, sp in TRAMP_FRAMES]
    write_png(SPR + 'trampoline_top.png', TOP_FW * len(tops), TOP_FH,
              [sum((f[y] for f in tops), []) for y in range(TOP_FH)])
    deb = debris()
    write_png(SPR + 'debris.png', 48, 8, [sum((d[y] for d in deb), []) for y in range(8)])
    print('wrote ore.png, ingot.png, trampoline.png, debris.png')
    if len(sys.argv) > 1:
        pad = lambda f, w, h: [row + [(0, 0, 0, 0)] * (w - len(row)) for row in f] + [[(0, 0, 0, 0)] * w] * (h - len(f))
        big = side_by_side([pad(o, 12, 22) for o in ores + irons] + [pad(ing, 14, 22), pad(ingot('iron'), 14, 22), pad(shot(), 8, 22), pad(gear(), 16, 22), pad(flask(), 12, 22), tr] + [pad(d, 8, 22) for d in deb], 10)
        write_png(sys.argv[1] + '/items_preview.png', len(big[0]), len(big), big)
        base = tramp_base()
        comp = []
        for t in tops:   # stack each top frame on the base for the preview
            f = [row[:] for row in t] + [[(0, 0, 0, 0)] * TOP_FW for _ in range(6)]
            for y, row in enumerate(base):
                for x, px in enumerate(row):
                    if px[3]: f[TOP_O[1] - 2 + y][TOP_O[0] - 14 + x] = px
            comp.append(f)
        big = side_by_side(comp, 6)
        write_png(sys.argv[1] + '/tramp_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
