extends ParallaxBackground

const BackgroundGen = preload("res://scripts/background_gen.gd")

const BG_WIDTH := 960
const BG_HEIGHT := 1200
# Surface is at tile row 6 * 16 = pixel Y 96
const SURFACE_Y := 96.0
# ParallaxLayer mirroring only draws one extra copy, which leaves gaps when the
# camera zooms out (min 0.5 → 2560px of world across the screen). Lay out
# several copies side by side and mirror the whole strip instead.
const TILE_COPIES := 3


func _ready() -> void:
	# Sky gradient: anchored to the surface, stretched wide to cover any zoom
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0, 1)
	var sky_sprite := Sprite2D.new()
	sky_sprite.texture = BackgroundGen.create_sky_texture(BG_WIDTH, BG_HEIGHT)
	sky_sprite.centered = false
	# Gradient is uniform horizontally, so stretch it to cover any zoom
	sky_sprite.scale.x = 12.0
	sky_sprite.position = Vector2(-BG_WIDTH * 6, SURFACE_Y - BG_HEIGHT)
	sky_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky_layer.add_child(sky_sprite)
	add_child(sky_layer)

	# Stars (very slow parallax)
	var stars_layer := ParallaxLayer.new()
	stars_layer.motion_scale = Vector2(0.05, 1)
	stars_layer.motion_mirroring = Vector2(BG_WIDTH * TILE_COPIES, 0)
	var stars_sprite := Sprite2D.new()
	stars_sprite.texture = BackgroundGen.create_stars_texture(BG_WIDTH, BG_HEIGHT)
	stars_sprite.centered = false
	stars_sprite.position = Vector2(-BG_WIDTH / 2, SURFACE_Y - BG_HEIGHT)
	stars_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_tiled(stars_layer, stars_sprite)
	add_child(stars_layer)

	# Distant mountains (slow parallax) — extends well past surface
	var mountain_layer := ParallaxLayer.new()
	mountain_layer.motion_scale = Vector2(0.15, 1)
	mountain_layer.motion_mirroring = Vector2(BG_WIDTH * TILE_COPIES, 0)
	var mtn_height := 600
	var mountain_sprite := Sprite2D.new()
	mountain_sprite.texture = BackgroundGen.create_mountains_texture(BG_WIDTH, mtn_height)
	mountain_sprite.centered = false
	mountain_sprite.position = Vector2(-BG_WIDTH / 2, SURFACE_Y - mtn_height + 200)
	mountain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_tiled(mountain_layer, mountain_sprite)
	add_child(mountain_layer)

	# Near hills (medium parallax) — fills down past surface
	var hills_layer := ParallaxLayer.new()
	hills_layer.motion_scale = Vector2(0.3, 1)
	hills_layer.motion_mirroring = Vector2(BG_WIDTH * TILE_COPIES, 0)
	var hill_height := 400
	var hills_sprite := Sprite2D.new()
	hills_sprite.texture = BackgroundGen.create_hills_texture(BG_WIDTH, hill_height)
	hills_sprite.centered = false
	hills_sprite.position = Vector2(-BG_WIDTH / 2, SURFACE_Y - hill_height + 250)
	hills_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_tiled(hills_layer, hills_sprite)
	add_child(hills_layer)


func _add_tiled(layer: ParallaxLayer, sprite: Sprite2D) -> void:
	layer.add_child(sprite)
	for i in range(1, TILE_COPIES):
		var copy := sprite.duplicate() as Sprite2D
		copy.position.x += BG_WIDTH * i
		layer.add_child(copy)
