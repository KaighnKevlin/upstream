extends RefCounted
## The game's pixel font, built at runtime from assets/ui/font.png (drawn by
## tools/art/gen_font.py): a 16x6 grid of 6x10 cells for ASCII 32-127.
## Proportional: each glyph's advance is measured from its ink.
## Draw it at multiples of 10 (font_size 20 = 2x, 30 = 3x) to stay crisp.

const CELL := Vector2i(6, 10)
const BASELINE := 7  # rows above the baseline

static var _font: FontFile


static func get_font() -> FontFile:
	if _font:
		return _font
	var img := (load("res://assets/ui/font.png") as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var f := FontFile.new()
	f.fixed_size = CELL.y
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var size := Vector2i(CELL.y, 0)
	f.set_texture_image(0, size, 0, img)
	f.set_cache_ascent(0, CELL.y, BASELINE)
	f.set_cache_descent(0, CELL.y, CELL.y - BASELINE)
	for code in range(32, 128):
		var cx := (code - 32) % 16 * CELL.x
		var cy := (code - 32) / 16 * CELL.y
		var w := 0
		for x in CELL.x:
			for y in CELL.y:
				if img.get_pixel(cx + x, cy + y).a > 0.5:
					w = maxi(w, x + 1)
		if code == 32:
			w = 2
		f.set_glyph_advance(0, CELL.y, code, Vector2(w + 1, 0))
		f.set_glyph_offset(0, size, code, Vector2(0, -BASELINE))
		f.set_glyph_size(0, size, code, Vector2(CELL))
		f.set_glyph_uv_rect(0, size, code, Rect2(cx, cy, CELL.x, CELL.y))
		f.set_glyph_texture_idx(0, size, code, 0)
	_font = f
	return f
