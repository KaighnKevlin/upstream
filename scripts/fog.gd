extends Sprite2D
## Fog of war underground. Unexplored ground is black; the prospector's lamp
## reveals a soft circle around them as they dig and explore, and whatever
## you build lights up its surroundings. Revealed stays revealed. The sky
## and the top of the ground are always in view.
##
## One pixel per tile, scaled up with linear filtering so the edge of the
## known world is a soft gradient rather than a staircase.

const WorldGen = preload("res://scripts/world_gen.gd")

const PLAYER_RADIUS := 8.5      # tiles
const BUILD_RADIUS := 5.0
const OPEN_ROWS := 3            # rows below the surface that are always seen
const SOFT := 2.5               # tiles of falloff at the edge of a reveal

var _img: Image
var _tex: ImageTexture
var _dirty := false
var _last_cell := Vector2i(-999, -999)
var _known_buildings := {}
var _scan_t := 0.0


func _ready() -> void:
	z_index = 20
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var w := WorldGen.WORLD_WIDTH
	var h := WorldGen.WORLD_HEIGHT
	_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.02, 0.02, 0.03, 1.0))
	for y in WorldGen.SURFACE_ROWS + OPEN_ROWS:
		for x in w:
			_img.set_pixel(x, y, Color(0, 0, 0, 0))
	# soften the band's lower edge
	for k in 3:
		var y := WorldGen.SURFACE_ROWS + OPEN_ROWS + k
		for x in w:
			_img.set_pixel(x, y, Color(0.02, 0.02, 0.03, 0.35 + k * 0.25))
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex
	scale = Vector2(WorldGen.TILE_SIZE, WorldGen.TILE_SIZE)
	# pixel centres at tile centres: shift by half a tile
	position = Vector2.ZERO


## Reveal a disc of `radius` tiles around a world position.
func reveal(at: Vector2, radius: float) -> void:
	var c := Vector2i(int(at.x / WorldGen.TILE_SIZE), int(at.y / WorldGen.TILE_SIZE))
	var r := int(ceil(radius + SOFT))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= _img.get_width() or p.y >= _img.get_height():
				continue
			var d := Vector2(dx, dy).length()
			if d > radius + SOFT:
				continue
			var a := clampf((d - radius) / SOFT, 0.0, 1.0)
			var cur := _img.get_pixel(p.x, p.y)
			if a < cur.a:
				_img.set_pixel(p.x, p.y, Color(cur.r, cur.g, cur.b, a))
				_dirty = true


func is_revealed(at: Vector2) -> bool:
	var c := Vector2i(int(at.x / WorldGen.TILE_SIZE), int(at.y / WorldGen.TILE_SIZE))
	if c.x < 0 or c.y < 0 or c.x >= _img.get_width() or c.y >= _img.get_height():
		return true
	return _img.get_pixel(c.x, c.y).a < 0.5


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	var p := scene.get_node_or_null("Player") as Node2D if scene else null
	if p:
		var cell := Vector2i(p.global_position / WorldGen.TILE_SIZE)
		if cell != _last_cell:
			_last_cell = cell
			reveal(p.global_position, PLAYER_RADIUS)
	_scan_t -= delta
	if _scan_t <= 0:
		_scan_t = 0.5
		var bs := get_node_or_null("/root/BuildSystem")
		if bs:
			for b in bs._placed_buildings:
				if is_instance_valid(b) and not _known_buildings.has(b):
					_known_buildings[b] = true
					reveal(b.global_position, BUILD_RADIUS)
	if _dirty:
		_dirty = false
		_tex.update(_img)
