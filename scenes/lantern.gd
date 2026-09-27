extends Node2D
## Miner's lantern: hang light in the dark. Placed under a cave ceiling
## (rock within a few tiles above) it hangs from an iron hook; out in the
## open it stands on a pole down to the ground. Warm, flickering light that
## reaches well past your own lamp's, and it clears the fog around it for
## good (fog.gd reads reveal_radius). Lights up crawlers, gas pockets and
## anything else lurking in a cave.
## Art: tools/art/gen_lantern.py (3 frames of 16x22, hook at the top).

const LightTextures = preload("res://scripts/light_textures.gd")

const HANG_MAX := 5              # tiles up to look for a ceiling
const POLE_MAX := 6              # tiles down to look for ground
const FLAME := Vector2(0, 13)

var reveal_radius := 170.0       # fog.gd
var _spr: AnimatedSprite2D
var _light: PointLight2D
var _pole := 0.0                 # > 0: standing on a pole this long
var _t := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_mount()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 7.0)
	var tex := preload("res://assets/sprites/lantern.png")
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 16, 0, 16, 22)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-8, 0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	_spr.play()
	_spr.frame = randi() % 3
	# the flame glows through the dark (unshaded), and lights the cave
	var glow := Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = mat
	glow.z_index = 2
	glow.draw.connect(func(): glow.draw_rect(Rect2(FLAME + Vector2(-1, -2), Vector2(2, 3)), Color(1.0, 0.9, 0.6)))
	add_child(glow)
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(128)
	_light.color = Color(1.0, 0.76, 0.45)
	_light.energy = 0.95
	_light.texture_scale = 2.4
	_light.position = FLAME
	_light.shadow_enabled = false
	add_child(_light)
	add_to_group("lanterns")


## Hang from the ceiling if there's one close above, else stand on a pole.
func _mount() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in HANG_MAX:
		if tm.get_cell_source_id(cell + Vector2i.UP) != -1:
			global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y - 8)
			return
		cell.y -= 1
	cell = tm.local_to_map(tm.to_local(global_position))
	for i in POLE_MAX:
		if tm.get_cell_source_id(cell + Vector2i.DOWN) != -1:
			var ground := tm.to_global(tm.map_to_local(cell)).y + 8
			global_position.y = ground - 36          # lantern hook 36px up a pole
			_pole = 36.0
			queue_redraw()
			return
		cell.y += 1


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	_light.energy = 0.9 + 0.08 * sin(_t * 11.0) + 0.05 * sin(_t * 23.0 + 1.3)


func _draw() -> void:
	if _pole > 0:
		# an iron pole with a crook at the top the lantern hangs from
		draw_line(Vector2(-5, 0), Vector2(-5, _pole), Color(0.16, 0.15, 0.14), 3.0)
		draw_line(Vector2(-5, 1), Vector2(-5, _pole), Color(0.36, 0.33, 0.3), 1.0)
		draw_line(Vector2(-5, 0), Vector2(0, 0), Color(0.16, 0.15, 0.14), 2.0)
		draw_line(Vector2(-8, _pole), Vector2(-2, _pole), Color(0.2, 0.18, 0.16), 2.0)
