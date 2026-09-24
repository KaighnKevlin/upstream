"""Title logo: UPSTREAM in riveted brass blocks, flanked by gears.

    python3 tools/art/gen_title.py [preview_dir]

Writes assets/ui/logo.png. Letters come from the HUD font's glyphs
(gen_font.G), each font pixel drawn as a bevelled brass block, with a dark
drop shadow and a cyan core set into the S and the A.
"""
import sys
from clockwork import *
from pixtools import write_png
from gen_font import G

TEXT = 'UPSTREAM'
CELL = 3.0         # px per font pixel
GAP = 1            # font pixels between letters


def main():
    glyphs = [G[c] for c in TEXT]
    widths = [max(len(r) for r in g) for g in glyphs]
    total = sum(widths) + GAP * (len(TEXT) - 1)
    W = int(total * CELL) + 60
    H = int(7 * CELL) + 26
    fig = Figure()
    x0 = 30 - W / 2
    y0 = 10 - H / 2
    cx = x0
    for k, (g, w) in enumerate(zip(glyphs, widths)):
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch != '#':
                    continue
                px, py = cx + x * CELL, y0 + (y - 1) * CELL
                fig.box((px + 1.2, py + 1.2, px + CELL + 1.2, py + CELL + 1.2), DARK, z=0, bevel=0.3, grit=0.0)   # shadow
                fig.box((px, py, px + CELL - 0.1, py + CELL - 0.1), BRONZE, z=1, bevel=0.9, grit=0.05)
        cx += (w + GAP) * CELL
    # cores set into the first S and the A
    for ch, row, col in (('S', 3, 1.5), ('A', 4, 1.5)):
        idx = TEXT.index(ch)
        lx = x0 + (sum(widths[:idx]) + GAP * idx) * CELL
        fig.sphere((lx + col * CELL + CELL / 2, y0 + (row - 1) * CELL + CELL / 2), 1.3, GLOW, z=2, emissive=True)
    # gears either side, and a brass rail underneath
    for side in (-1, 1):
        gx = side * (W / 2 - 13)
        fig.disc((gx, 0), 10.5, DARK, z=-1)
        fig.gear((gx, 0), 9.5, 12, 7 * side, BRONZE, z=0.5)
        fig.sphere((gx, 0), 2.4, GLOW, z=0.6, emissive=True)
    rail_y = y0 + 6 * CELL + 5
    fig.box((x0 - 2, rail_y, x0 + total * CELL + 2, rail_y + 2.5), BRONZE, z=1, bevel=0.8)
    for k in range(9):
        fig.sphere((x0 + k * (total * CELL) / 8, rail_y + 1.25), 0.7, STEEL, z=1.1)
    img = fig.render(W, H, (W // 2, H // 2))
    out = __file__.rsplit('/', 1)[0] + '/../../assets/ui/logo.png'
    write_png(out, W, H, img)
    print('wrote assets/ui/logo.png (%dx%d)' % (W, H))
    if len(sys.argv) > 1:
        from pixtools import upscale
        big = upscale(img, 4)
        write_png(sys.argv[1] + '/logo_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
