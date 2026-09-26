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

# Day and night (scripts/daynight.gd drives set_daylight): the day sky and a
# dawn/dusk glow fade in over the night sky, the stars and moon fade out, a
# sun arcs over, and the silhouettes lighten with the haze.
var _day_sky: Sprite2D
var _glow: Sprite2D
var _stars_layer: ParallaxLayer
var _moon: Sprite2D
var _sun: Node2D
var _silhouettes: Array[ParallaxLayer] = []
var _haze: ShaderMaterial        # blends the silhouettes toward the day haze

const HAZE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform vec4 haze : source_color = vec4(0.55, 0.66, 0.78, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, haze.rgb * (0.75 + 0.25 * c.r * 2.0), amount), c.a);
}
"""


func _ready() -> void:
	# Painted layers (tools/art/gen_background.py); fall back to the procedural ones
	if load("res://assets/backgrounds/city.png") != null:
		_build_painted()
		return
	_build_procedural()


func _build_painted() -> void:
	# Sky: a 4px-wide gradient stretched to cover any zoom, bottom at the horizon
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0, 1)
	var sky := Sprite2D.new()
	sky.texture = load("res://assets/backgrounds/sky.png")
	sky.centered = false
	sky.scale = Vector2(BG_WIDTH * 12 / 4.0, 1.0)
	sky.position = Vector2(-BG_WIDTH * 6, SURFACE_Y - 1200 + 40)
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky_layer.add_child(sky)
	_day_sky = _gradient_sprite(sky, [Color(0.22, 0.42, 0.7), Color(0.45, 0.66, 0.85), Color(0.78, 0.87, 0.9)], [0.0, 0.7, 1.0])
	sky_layer.add_child(_day_sky)
	_glow = _gradient_sprite(sky, [Color(1.0, 0.55, 0.3, 0.0), Color(1.0, 0.5, 0.3, 0.0), Color(1.0, 0.62, 0.35, 0.85)], [0.0, 0.72, 1.0])
	sky_layer.add_child(_glow)
	add_child(sky_layer)

	var stars_layer := ParallaxLayer.new()
	stars_layer.motion_scale = Vector2(0.05, 1)
	stars_layer.motion_mirroring = Vector2(BG_WIDTH * TILE_COPIES, 0)
	var stars := Sprite2D.new()
	stars.texture = BackgroundGen.create_stars_texture(BG_WIDTH, BG_HEIGHT)
	stars.centered = false
	stars.position = Vector2(-BG_WIDTH / 2, SURFACE_Y - BG_HEIGHT)
	stars.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_tiled(stars_layer, stars)
	add_child(stars_layer)
	_stars_layer = stars_layer

	# The moon drifts very slowly and is not tiled (one moon at any zoom)
	var moon_layer := ParallaxLayer.new()
	moon_layer.motion_scale = Vector2(0.03, 1)
	var moon := Sprite2D.new()
	moon.texture = load("res://assets/backgrounds/moon.png")
	moon.position = Vector2(560, SURFACE_Y - 175)  # screen x is ~ this * zoom
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moon_layer.add_child(moon)
	_moon = moon
	_sun = Node2D.new()
	var halo := Sprite2D.new()
	halo.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
	halo.modulate = Color(1.0, 0.9, 0.6, 0.55)
	halo.scale = Vector2(1.6, 1.6)
	_sun.add_child(halo)
	var disc := Sprite2D.new()
	disc.texture = preload("res://scripts/light_textures.gd").create_radial_light(32)
	disc.modulate = Color(1.0, 0.98, 0.85, 1.0)
	disc.scale = Vector2(1.3, 1.3)
	_sun.add_child(disc)
	_sun.modulate.a = 0.0
	moon_layer.add_child(_sun)
	add_child(moon_layer)

	# name, motion, top of the texture relative to the surface
	for spec in [["far", 0.1, -205.0], ["city", 0.2, -168.0], ["near", 0.35, -84.0]]:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(spec[1], 1)
		layer.motion_mirroring = Vector2(BG_WIDTH * TILE_COPIES, 0)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/backgrounds/%s.png" % spec[0])
		spr.centered = false
		spr.position = Vector2(-BG_WIDTH / 2, SURFACE_Y + spec[2])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _haze == null:
			var sh := Shader.new()
			sh.code = HAZE_SHADER
			_haze = ShaderMaterial.new()
			_haze.shader = sh
		spr.material = _haze
		_add_tiled(layer, spr)
		add_child(layer)
		_silhouettes.append(layer)


func _build_procedural() -> void:
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


## A sprite the size and place of the night sky, painted with a vertical
## gradient (top to horizon).
func _gradient_sprite(like: Sprite2D, colors: Array, offsets: Array) -> Sprite2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = like.texture.get_height()
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = like.scale
	spr.position = like.position
	spr.modulate.a = 0.0
	return spr


## daylight 0 (night) .. 1 (full day); warm: the dawn/dusk glow 0..1; sun:
## 0..1 across the day (where the sun is on its arc).
func set_daylight(daylight: float, warm: float, sun: float) -> void:
	if _day_sky == null:
		return
	_day_sky.modulate.a = daylight
	_glow.modulate.a = warm
	_stars_layer.modulate.a = 1.0 - daylight
	_moon.modulate.a = 1.0 - daylight
	_sun.modulate.a = clampf(daylight * 1.5, 0.0, 1.0)
	_sun.position = Vector2(lerpf(260.0, 900.0, sun), SURFACE_Y - 70.0 - 190.0 * sin(PI * clampf(sun, 0.0, 1.0)))
	# far layers take more haze than near ones (the order is far, city, near)
	if _haze:
		_haze.set_shader_parameter("amount", daylight * 0.55)
		_haze.set_shader_parameter("haze", Color(0.52, 0.64, 0.78).lerp(Color(0.85, 0.6, 0.5), warm * 0.7))


func _add_tiled(layer: ParallaxLayer, sprite: Sprite2D) -> void:
	layer.add_child(sprite)
	for i in range(1, TILE_COPIES):
		var copy := sprite.duplicate() as Sprite2D
		copy.position.x += BG_WIDTH * i
		layer.add_child(copy)
