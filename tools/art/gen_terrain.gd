extends SceneTree
## Generates assets/sprites/terrain_atlas.png — the terrain tiles.
##
##   godot --path . --headless --script tools/art/gen_terrain.gd [-- preview_dir]
##
## Each material is painted as one seamless 128x128 texture and sliced into an
## 8x8 grid of 16px tiles; the world picks the slice by cell position, so the
## ground reads as one continuous surface instead of a repeated 16px stamp.
##
## Every slice then comes in 16 FRAMES, one per combination of open sides
## (bit 1 up, 2 right, 4 down, 8 left: which neighbours are air), the way
## Terraria frames its blocks: open faces are carved into a lumpy edge (the
## lumps follow the world position, so a long floor is one natural edge),
## outer corners are rounded, and each open face gets a dark outline and a
## crust (lit on top, shadowed underneath). Grass creeps down open sides.
##
## Atlases terrain_atlas_<src>.png, one TileSet source each (GL won't load
## a texture 16384 px tall, so each host block is split in two by mask):
##   src = block * 2 + (mask >> 3); block 0 = everything (ore on stone),
##   block 1 = ore on dirt, block 2 = ore on deep stone (ore columns only)
##   column = tile type (matches world_gen TILE_* ids)
##   row = (mask & 7) * 64 + slice   (slice = (x % 8) + (y % 8) * 8)
##   column 6 is hard ironstone (the starting pickaxe can't break it).

const T := 16
const P := 128  # seamless period
const G := P / T  # slices per side
const N := G * G  # slices per material
const MASKS := 16
const HALF := 8 * N       # rows per atlas image (8192 px)
const DIRT := 0
const STONE := 1
const IRON := 2
const COPPER := 3
const DEEP := 4
const GRASS := 5
const HARD := 6

# Palettes, dark → light
const DIRT_PAL := ["2e1c17", "46291f", "5c3727", "663e2b", "8a563b", "a26c4a"]
const STONE_PAL := ["1f2029", "2f313d", "414452", "545868", "6a6f80", "878c9c"]
const DEEP_PAL := ["15141d", "201e2b", "2c2939", "3a3649", "4a455b", "5d5770"]
const GRASS_PAL := ["1d3b1c", "2c5a26", "3d7a30", "56993a", "7dbb4a"]
const IRON_PAL := ["2a2230", "8c5a4e", "c0968a", "e6cfc4", "ffffff"]
const COPPER_PAL := ["5a2410", "9a4a1e", "d27434", "f5a55a", "ffe0a8"]
const VERDIGRIS := "4fb3a0"
const HARD_PAL := ["0d0a0a", "1c1412", "2b1e19", "3d2a21", "54392a", "7a5a3e"]
const RUST := "a0522d"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 7
	var dirt := _dirt()
	var stone := _stone(STONE_PAL, 80, 11)
	var deep := _stone(DEEP_PAL, 112, 23)
	var bases := [stone, dirt, deep]  # ore row blocks: 0 = stone, 1 = dirt, 2 = deep

	var hard := _ironstone()
	var grass := _grass(dirt)
	var atlases := []
	for k in 6:
		atlases.append(Image.create(7 * T, HALF * T, false, Image.FORMAT_RGBA8))
	var pals := [STONE_PAL, DIRT_PAL, DEEP_PAL]
	for mask in MASKS:
		var atlas: Image = atlases[mask >> 3]
		for v in N:
			var row := (mask & 7) * N + v
			_blit_frame(atlas, hard, HARD, v, row, mask, HARD_PAL, 61)
			_blit_frame(atlas, dirt, DIRT, v, row, mask, DIRT_PAL, 3)
			_blit_frame(atlas, stone, STONE, v, row, mask, STONE_PAL, 11)
			_blit_frame(atlas, deep, DEEP, v, row, mask, DEEP_PAL, 23)
			_blit_frame(atlas, grass, GRASS, v, row, mask, DIRT_PAL, 5, true)
	for b in 3:
		var iron := _ore(bases[b], IRON_PAL, "", 101 + b)
		var copper := _ore(bases[b], COPPER_PAL, VERDIGRIS, 201 + b)
		for mask in MASKS:
			for v in N:
				var row := (mask & 7) * N + v
				var img: Image = atlases[b * 2 + (mask >> 3)]
				_blit_frame(img, iron, IRON, v, row, mask, pals[b], 101 + b)
				_blit_frame(img, copper, COPPER, v, row, mask, pals[b], 201 + b)
	for k in 6:
		atlases[k].save_png("res://assets/sprites/terrain_atlas_%d.png" % k)
	print("wrote res://assets/sprites/terrain_atlas_0..5.png")

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_save_previews(args[0], {"dirt": dirt, "stone": stone, "deep": deep,
			"grass": _grass(dirt), "hard": hard, "iron_dirt": _ore(dirt, IRON_PAL, "", 102),
			"iron_stone": _ore(stone, IRON_PAL, "", 101),
			"copper_deep": _ore(deep, COPPER_PAL, VERDIGRIS, 203)})
	quit()


# ── helpers ─────────────────────────────────────────────────────────────

func _c(hex: String) -> Color:
	return Color.html(hex)


func _blit_slice(atlas: Image, tex: Image, col: int, v: int, row: int) -> void:
	var sx := (v % G) * T
	var sy := (v / G) * T
	atlas.blit_rect(tex, Rect2i(sx, sy, T, T), Vector2i(col * T, row * T))


const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8


## 1D wrapping noise over the period -> carve depth 0..2 px, per edge.
func _edge_depths(seed_val: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var knots := []
	for i in P / 4:
		knots.append(r.randf())
	var out := []
	for i in P:
		var a: float = knots[(i / 4) % knots.size()]
		var b: float = knots[(i / 4 + 1) % knots.size()]
		var f := float(i % 4) / 4.0
		var n := lerpf(a, b, f * f * (3.0 - 2.0 * f))
		out.append(0 if n < 0.22 else (1 if n < 0.62 else (2 if n < 0.88 else 3)))
	return out


var _depth_cache := {}

func _depths(seed_val: int) -> Dictionary:
	if not _depth_cache.has(seed_val):
		_depth_cache[seed_val] = {"up": _edge_depths(seed_val * 7 + 1), "down": _edge_depths(seed_val * 7 + 2),
			"left": _edge_depths(seed_val * 7 + 3), "right": _edge_depths(seed_val * 7 + 4)}
	return _depth_cache[seed_val]


## One framed tile: slice v of `tex`, with the sides in `mask` open to air.
func _blit_frame(atlas: Image, tex: Image, col: int, v: int, row: int, mask: int, pal: Array,
		seed_val: int, grassy := false) -> void:
	var sx := (v % G) * T
	var sy := (v / G) * T
	var dep := _depths(seed_val)
	# 1. carve: which pixels of this tile are air
	var air := []
	air.resize(T * T)
	for y in T:
		for x in T:
			var gx := sx + x
			var gy := sy + y
			var a := false
			if mask & UP and y < int(dep.up[gx]):
				a = true
			if mask & DOWN and y > T - 1 - int(dep.down[gx]):
				a = true
			if mask & LEFT and x < int(dep.left[gy]):
				a = true
			if mask & RIGHT and x > T - 1 - int(dep.right[gy]):
				a = true
			# rounded outer corners
			var r := 5.5
			if mask & UP and mask & LEFT and x < 6 and y < 6 and Vector2(x + 0.5 - r, y + 0.5 - r).length() > r:
				a = true
			if mask & UP and mask & RIGHT and x > 9 and y < 6 and Vector2(x + 0.5 - (T - r), y + 0.5 - r).length() > r:
				a = true
			if mask & DOWN and mask & LEFT and x < 6 and y > 9 and Vector2(x + 0.5 - r, y + 0.5 - (T - r)).length() > r:
				a = true
			if mask & DOWN and mask & RIGHT and x > 9 and y > 9 and Vector2(x + 0.5 - (T - r), y + 0.5 - (T - r)).length() > r:
				a = true
			air[y * T + x] = a
	# 2. distance to air along each open direction (beyond an open side is air)
	var dark := Color(0.07, 0.045, 0.06)   # near-black outline: reads against the dark back wall
	var light: Color = _c(pal[pal.size() - 1])
	for y in T:
		for x in T:
			var px := Vector2i(col * T + x, row * T + y)
			if air[y * T + x]:
				atlas.set_pixelv(px, Color(0, 0, 0, 0))
				continue
			var c := tex.get_pixel(sx + x, sy + y)
			var du := _run(air, x, y, 0, -1, mask & UP != 0)
			var dd := _run(air, x, y, 0, 1, mask & DOWN != 0)
			var dl := _run(air, x, y, -1, 0, mask & LEFT != 0)
			var dr := _run(air, x, y, 1, 0, mask & RIGHT != 0)
			var d := mini(mini(du, dd), mini(dl, dr))
			if d == 1:
				c = dark                                   # outline
			elif du == 2:
				c = c.lerp(light, 0.6)                     # bright top lip
			elif du == 3:
				c = c.lerp(light, 0.25)
			elif dd == 2:
				c = c.darkened(0.55)                       # shadowed underside
			elif dd <= 4:
				c = c.darkened(0.32 if dd == 3 else 0.15)
			elif mini(dl, dr) == 2:
				c = c.darkened(0.35)                       # side faces
			elif mini(dl, dr) == 3:
				c = c.darkened(0.15)
			# grass creeping down open sides of a grass block
			if grassy and d > 1 and (mini(dl, dr) <= 3) and y < 4 + int(dep.down[(sx + x) % P]) * 3:
				c = _c(GRASS_PAL[3 if mini(dl, dr) == 2 else 2])
			atlas.set_pixelv(px, c)


## Pixels from (x,y) to air going (dx,dy); open = the tile edge that way is air.
func _run(air: Array, x: int, y: int, dx: int, dy: int, open: bool) -> int:
	var k := 0
	while true:
		x += dx
		y += dy
		k += 1
		if x < 0 or y < 0 or x >= T or y >= T:
			return k if open else 99
		if air[y * T + x]:
			return k
	return 99


func _wrap(v: int) -> int:
	return posmod(v, P)


## Wrapping value noise, 0..1, with lattice spacing `cell` (must divide P).
func _noise_grid(cell: int, seed_val: int) -> Callable:
	var n := P / cell
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var lattice := []
	for i in n * n:
		lattice.append(r.randf())
	return func(x: float, y: float) -> float:
		var gx := x / cell
		var gy := y / cell
		var x0 := int(floor(gx))
		var y0 := int(floor(gy))
		var fx := gx - x0
		var fy := gy - y0
		fx = fx * fx * (3.0 - 2.0 * fx)
		fy = fy * fy * (3.0 - 2.0 * fy)
		var a: float = lattice[posmod(y0, n) * n + posmod(x0, n)]
		var b: float = lattice[posmod(y0, n) * n + posmod(x0 + 1, n)]
		var c: float = lattice[posmod(y0 + 1, n) * n + posmod(x0, n)]
		var d: float = lattice[posmod(y0 + 1, n) * n + posmod(x0 + 1, n)]
		return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _fbm(seed_val: int) -> Callable:
	var o0 := _noise_grid(32, seed_val + 3)
	var o1 := _noise_grid(16, seed_val)
	var o2 := _noise_grid(8, seed_val + 1)
	var o3 := _noise_grid(4, seed_val + 2)
	return func(x: float, y: float) -> float:
		return o0.call(x, y) * 0.35 + o1.call(x, y) * 0.35 + o2.call(x, y) * 0.2 + o3.call(x, y) * 0.1


## Toroidal distance vector from a to b.
func _tdelta(a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	if d.x > P / 2.0: d.x -= P
	if d.x < -P / 2.0: d.x += P
	if d.y > P / 2.0: d.y -= P
	if d.y < -P / 2.0: d.y += P
	return d


# ── materials ───────────────────────────────────────────────────────────

func _dirt() -> Image:
	var img := Image.create(P, P, false, Image.FORMAT_RGBA8)
	var fbm := _fbm(3)
	# Soft clumps: 3 mid shades from low-frequency noise
	for y in P:
		for x in P:
			var n: float = fbm.call(x, y)
			var idx := 2 if n < 0.47 else 3
			img.set_pixel(x, y, _c(DIRT_PAL[idx]))
	# Pebbles: small dark blobs lit from above
	rng.seed = 31
	for i in 88:
		var cx := rng.randi_range(0, P - 1)
		var cy := rng.randi_range(0, P - 1)
		var w := rng.randi_range(1, 3)
		var h := rng.randi_range(1, 2)
		for dy in h:
			for dx in w:
				img.set_pixel(_wrap(cx + dx), _wrap(cy + dy), _c(DIRT_PAL[1]))
		for dx in w:
			img.set_pixel(_wrap(cx + dx), _wrap(cy - 1), _c(DIRT_PAL[5]))  # rim light
			img.set_pixel(_wrap(cx + dx), _wrap(cy + h), _c(DIRT_PAL[0]))  # contact shadow
	# Fine specks
	for i in 144:
		var x := rng.randi_range(0, P - 1)
		var y := rng.randi_range(0, P - 1)
		img.set_pixel(x, y, _c(DIRT_PAL[4] if rng.randf() < 0.5 else DIRT_PAL[1]))
	return img


## Boulder texture: wrapping Voronoi cells with cracks between them, each
## cell shaded as a rounded rock lit from the top-left.
func _stone(pal: Array, points: int, seed_val: int) -> Image:
	var img := Image.create(P, P, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var pts: Array[Vector2] = []
	for i in points:
		pts.append(Vector2(r.randf() * P, r.randf() * P))
	var light := Vector2(-0.6, -0.8).normalized()
	var grain := _noise_grid(4, seed_val + 5)
	for y in P:
		for x in P:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := INF
			var d2 := INF
			var nearest := Vector2.ZERO
			for c in pts:
				var dv := _tdelta(c, p)
				var d := dv.length()
				if d < d1:
					d2 = d1
					d1 = d
					nearest = dv
				elif d < d2:
					d2 = d
			var edge := d2 - d1
			var idx: int
			if edge < 1.1:
				idx = 0  # crack
			elif edge < 2.2:
				# rim: lit side bright, shadow side dark
				idx = 3 if nearest.normalized().dot(light) > 0.2 else 1
			else:
				var shade := -nearest.normalized().dot(light) * clampf(d1 / 7.0, 0.0, 1.0)
				shade += (grain.call(x, y) - 0.5) * 0.5
				idx = 3 if shade > 0.45 else (2 if shade > -0.45 else 1)
			img.set_pixel(x, y, _c(pal[idx]))
	# A few bright glints
	for i in 24:
		img.set_pixel(r.randi_range(0, P - 1), r.randi_range(0, P - 1), _c(pal[4]))
	return img


## Ironstone: dark columnar rock with vertical joints and staggered
## cross-cracks, each column lit on its left face, rust flecks. Reads as
## "too hard for this pickaxe" next to the rounded boulders of stone.
func _ironstone() -> Image:
	var img := Image.create(P, P, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 61
	var grain := _noise_grid(8, 67)
	# column edges: widths summing to P so it wraps
	var edges: Array[int] = [0]
	while edges[-1] < P - 14:
		edges.append(edges[-1] + r.randi_range(10, 14))
	edges.append(P)
	for ci in edges.size() - 1:
		var x0 := edges[ci]
		var x1 := edges[ci + 1]
		# cross joints for this column
		var joints: Array[int] = []
		var jy := r.randi_range(0, 12)
		while jy < P:
			joints.append(jy)
			jy += r.randi_range(14, 26)
		for y in P:
			for x in range(x0, x1):
				var fx := float(x - x0) / float(x1 - x0)
				var idx := 2
				if x == x0:
					idx = 0          # joint
				elif x == x0 + 1:
					idx = 4          # lit left face
				elif fx > 0.8:
					idx = 1          # shadowed right side
				elif grain.call(x, y) > 0.62:
					idx = 3
				for j in joints:
					if y == j:
						idx = 0
					elif y == posmod(j + 1, P) and idx > 1:
						idx = 3      # lit lip under the crack
				img.set_pixel(x, y, _c(HARD_PAL[idx]))
	for i in 40:
		img.set_pixel(r.randi_range(0, P - 1), r.randi_range(0, P - 1), _c(RUST))
	for i in 14:
		img.set_pixel(r.randi_range(0, P - 1), r.randi_range(0, P - 1), _c(HARD_PAL[5]))
	return img


func _grass(dirt: Image) -> Image:
	var img := dirt.duplicate() as Image
	var r := RandomNumberGenerator.new()
	r.seed = 55
	for x in P:
		# grass mat 3-4px thick, then a ragged fringe hanging into the dirt
		var depth := 3 + (1 if r.randf() < 0.4 else 0)
		var fringe := r.randi_range(0, 3) if r.randf() < 0.6 else 0
		for y in range(0, depth + fringe):
			var idx := 4 if y == 0 else (3 if y == 1 else (2 if y < depth else 1))
			for tile_row in G:  # every 16px row of the period is a possible grass row
				img.set_pixel(x, tile_row * T + y, _c(GRASS_PAL[idx]))
		for tile_row in G:
			img.set_pixel(x, tile_row * T + depth + fringe, _c(DIRT_PAL[0]))  # shadow under grass
	return img


## Ore: the host rock with 3-5 lit nuggets per 16px tile, kept inside the
## tile so ore blocks don't bleed into neighbours.
func _ore(base: Image, pal: Array, fleck: String, seed_val: int) -> Image:
	var img := base.duplicate() as Image
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	for ty in G:
		for tx in G:
			var count := r.randi_range(4, 6)
			for i in count:
				var w := r.randi_range(2, 4)
				var h := r.randi_range(2, 3)
				var ox := tx * T + r.randi_range(1, T - 2 - w)
				var oy := ty * T + r.randi_range(1, T - 2 - h)
				# full dark outline first, nugget on top
				for dy in range(-1, h + 1):
					for dx in range(-1, w + 1):
						img.set_pixel(ox + dx, oy + dy, _c(pal[0]))
				for dy in h:
					for dx in w:
						var idx := 2
						if dy == 0 or dx == 0:
							idx = 3
						if dy == h - 1 or dx == w - 1:
							idx = 1
						img.set_pixel(ox + dx, oy + dy, _c(pal[idx]))
				img.set_pixel(ox, oy, _c(pal[4]))  # glint
				# dark outline below/right so nuggets sit in the rock
				for dx in w:
					img.set_pixel(ox + dx, oy + h, _c(pal[0]))
				for dy in h:
					img.set_pixel(ox + w, oy + dy, _c(pal[0]))
			if fleck != "" and r.randf() < 0.7:
				img.set_pixel(tx * T + r.randi_range(2, 13), ty * T + r.randi_range(2, 13), _c(fleck))
	return img


func _save_previews(dir: String, textures: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Each material tiled 2x2 (128px) and scaled 4x, side by side
	var names := textures.keys()
	var sheet := Image.create(names.size() * 2 * P * 4 + (names.size() - 1) * 16, 2 * P * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in names.size():
		var tex: Image = textures[names[i]]
		var tiled := Image.create(2 * P, 2 * P, false, Image.FORMAT_RGBA8)
		for ty in 2:
			for tx in 2:
				tiled.blit_rect(tex, Rect2i(0, 0, P, P), Vector2i(tx * P, ty * P))
		tiled.resize(2 * P * 4, 2 * P * 4, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(tiled, Rect2i(0, 0, tiled.get_width(), tiled.get_height()),
			Vector2i(i * (2 * P * 4 + 16), 0))
	sheet.save_png(dir + "/terrain_preview.png")
	print("preview: %s  order: %s" % [dir + "/terrain_preview.png", names])
