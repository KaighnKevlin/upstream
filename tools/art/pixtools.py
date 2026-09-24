"""Tiny stdlib-only helpers for pixel-art work: read PNG / Aseprite, write PNG,
nearest-neighbour upscale. Used by the sprite scripts in tools/art/."""
import struct, zlib


def read_png(path):
    """-> (w, h, rows of (r,g,b,a) tuples). Supports 8-bit RGBA/RGB/palette."""
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    p = 8; idat = b''; plte = None; trns = None
    while p < len(d):
        n, t = struct.unpack('>I4s', d[p:p + 8]); body = d[p + 8:p + 8 + n]; p += 12 + n
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', body[:10])
        elif t == b'PLTE': plte = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif t == b'tRNS': trns = list(body)
        elif t == b'IDAT': idat += body
    assert bd == 8, 'only 8-bit PNGs'
    ch = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    raw = zlib.decompress(idat); stride = w * ch; rows = []; prev = bytearray(stride); i = 0
    for y in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0; b = prev[x]; c = prev[x - ch] if x >= ch else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line; row = []
        for x in range(w):
            if ct == 6: row.append(tuple(line[x * 4:x * 4 + 4]))
            elif ct == 2: row.append(tuple(line[x * 3:x * 3 + 3]) + (255,))
            elif ct == 3:
                k = line[x]; row.append(plte[k] + ((trns[k] if trns and k < len(trns) else 255),))
            elif ct == 4: row.append((line[x * 2],) * 3 + (line[x * 2 + 1],))
            else: row.append((line[x],) * 3 + (255,))
        rows.append(row)
    return w, h, rows


def write_png(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(v for px in row for v in px) for row in rows)
    def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def read_aseprite(path):
    """-> (w, h, palette[(r,g,b,a)], frames[rows]) for single-layer indexed files."""
    d = open(path, 'rb').read()
    _, _, nframes, w, h, depth = struct.unpack_from('<IHHHHH', d, 0)
    transparent_idx = d[28]
    pal = [(0, 0, 0, 0)] * 256; frames = []; off = 128
    for _ in range(nframes):
        fsize, _, old, _ = struct.unpack_from('<IHHH', d, off)
        nch = struct.unpack_from('<I', d, off + 12)[0] or old
        p = off + 16; canvas = [[(0, 0, 0, 0)] * w for _ in range(h)]
        for _ in range(nch):
            cs, ct = struct.unpack_from('<IH', d, p)
            if ct == 0x2019:
                n, first, last = struct.unpack_from('<III', d, p + 6); q = p + 6 + 20
                for k in range(first, last + 1):
                    fl, r, g, b, a = struct.unpack_from('<HBBBB', d, q); q += 6
                    if fl & 1: q += 2 + struct.unpack_from('<H', d, q)[0]
                    pal[k] = (r, g, b, a)
            elif ct == 0x2005:
                li, x, y, op, celtype = struct.unpack_from('<HhhBH', d, p + 6)
                cw, chh = struct.unpack_from('<HH', d, p + 6 + 16)
                px = d[p + 6 + 20:p + cs]
                if celtype == 2: px = zlib.decompress(px)
                bpp = depth // 8
                for yy in range(chh):
                    for xx in range(cw):
                        k = px[(yy * cw + xx) * bpp]
                        if depth == 8 and k != transparent_idx and 0 <= y + yy < h and 0 <= x + xx < w:
                            canvas[y + yy][x + xx] = pal[k]
            p += cs
        frames.append(canvas); off += fsize
    return w, h, [c for c in pal if c[3] > 0], frames


def upscale(rows, s, bg=(24, 24, 30, 255)):
    out = []
    for row in rows:
        line = []
        for px in row:
            line += [px if px[3] > 0 else bg] * s
        out += [line] * s
    return out


def save_scaled(path, rows, s, bg=(24, 24, 30, 255)):
    big = upscale(rows, s, bg); write_png(path, len(big[0]), len(big), big)


def write_gif(path, frames, delays_cs, scale=1, bg=(24, 24, 30)):
    """Animated GIF from equal-size RGBA frames (alpha -> bg), <=255 colours.
    delays_cs: per-frame delay in 1/100 s."""
    cols = {bg: 0}
    idx_frames = []
    for f in frames:
        idx = []
        for row in f:
            line = []
            for px in row:
                c = px[:3] if px[3] > 0 else bg
                if c not in cols: cols[c] = len(cols)
                line += [cols[c]] * scale
            idx += line * scale
        idx_frames.append(idx)
    assert len(cols) <= 256, 'too many colours for GIF'
    h = len(frames[0]) * scale; w = len(frames[0][0]) * scale
    bits = max(2, (len(cols) - 1).bit_length()); size = 1 << bits
    pal = sorted(cols, key=cols.get) + [(0, 0, 0)] * (size - len(cols))
    out = bytearray(b'GIF89a' + struct.pack('<HHBBB', w, h, 0xF0 | (bits - 1), 0, 0))
    for c in pal: out += bytes(c)
    out += b'\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00'  # loop forever
    for idx, d in zip(idx_frames, delays_cs):
        out += b'\x21\xF9\x04\x00' + struct.pack('<H', d) + b'\x00\x00'
        out += b'\x2C' + struct.pack('<HHHHB', 0, 0, w, h, 0)
        out += bytes([bits]) + _lzw(idx, bits) + b'\x00'
    out += b'\x3B'
    open(path, 'wb').write(out)


def _lzw(data, min_bits):
    clear = 1 << min_bits; eoi = clear + 1
    table = {(i,): i for i in range(clear)}
    nxt = eoi + 1; width = min_bits + 1
    buf = 0; nbits = 0; outb = bytearray()

    def emit(code):
        nonlocal buf, nbits
        buf |= code << nbits; nbits += width
        while nbits >= 8:
            outb.append(buf & 255); buf >>= 8; nbits -= 8
    emit(clear)
    cur = ()
    for k in data:
        cand = cur + (k,)
        if cand in table:
            cur = cand; continue
        emit(table[cur])
        if nxt < 4096:
            table[cand] = nxt; nxt += 1
            if nxt > (1 << width) and width < 12: width += 1
        else:
            emit(clear); table = {(i,): i for i in range(clear)}; nxt = eoi + 1; width = min_bits + 1
        cur = (k,)
    if cur: emit(table[cur])
    emit(eoi)
    if nbits: outb.append(buf & 255)
    blocks = bytearray()
    for i in range(0, len(outb), 255):
        chunk = outb[i:i + 255]; blocks += bytes([len(chunk)]) + chunk
    return bytes(blocks)
