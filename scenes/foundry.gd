extends CharacterBody2D
## The Foundry Engine: a boss. A walking blast furnace on four piston legs
## that arrives every fifth wave. It plods toward the dome; within range it
## stops and flings gobs of molten slag at it (scenes/slag.gd) from the
## ladle on its crane arm, and every so often its back hatch opens and lets
## out a pair of scuttlers. Too big to climb or leap: it grinds its way
## through ditch walls and ledges in its path, leaving a ramp. Too heavy for
## magnets and bumpers. It has a health bar at the top of the screen, and
## when it finally blows it scatters a heap of scrap.
## Art: tools/art/gen_foundry.py (10 frames of 110x112: 6 walk, 4 fling).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const SPEED := 16.0
const GRAVITY := 980.0
const MAX_HP := 90
const FLING_RANGE := 520.0       # starts flinging at the dome from this far
const STOP_RANGE := 300.0        # stops walking this far from the dome
const FLING_EVERY := 4.0
const HATCH_EVERY := 10.0
const RELEASE := Vector2(34, -94)
const HATCH := Vector2(-31, -30)
const GRIND := 0.45              # seconds to smash one column of wall
const BODY_H := 60.0

var hp := MAX_HP
var damage := 30                 # if it ever reaches the dome
var direction := -1.0
var flung := 0                   # tests
var hatched := 0
var ground := 0                  # wall tiles smashed
var _dying := false
var _fling_t := 1.5
var _hatch_t := 5.0
var _grind := 0.0
var _spr: AnimatedSprite2D
var _bar: CanvasLayer
var _bar_fill: ColorRect
var _smoke := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, BODY_H)
	cs.shape = r
	cs.position = Vector2(0, -BODY_H * 0.5)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/foundry.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 7.0, true], ["fling", [6, 7, 8, 9], 8.0, false], ["idle", [0], 1.0, true]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 110, 0, 110, 112)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-55, -111)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	_spr.frame_changed.connect(_on_frame)
	add_child(_spr)
	var glow := PointLight2D.new()
	glow.texture = LightTextures.create_radial_light(128)
	glow.color = Color(1.0, 0.5, 0.2)
	glow.energy = 0.8
	glow.position = Vector2(20, -46)
	add_child(glow)
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D if scene else null
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)
	_make_bar()


func _make_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	var root := Control.new()
	root.position = Vector2(440, 8)
	_bar.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.07, 0.85)
	bg.size = Vector2(400, 26)
	root.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.66, 0.56, 0.4)
	edge.position = Vector2(4, 16)
	edge.size = Vector2(392, 7)
	root.add_child(edge)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.95, 0.45, 0.15)
	_bar_fill.position = Vector2(5, 17)
	_bar_fill.size = Vector2(390, 5)
	root.add_child(_bar_fill)
	var l := Label.new()
	l.text = "THE FOUNDRY ENGINE"
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	l.position = Vector2(0, 1)
	l.size = Vector2(400, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	add_child(_bar)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -50)


func hit_radius() -> float:
	return 34.0


func knock(_v: Vector2) -> void:
	pass   # it doesn't budge


func _dome_x() -> float:
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	return dome.global_position.x if dome else 1200.0


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	var dist := absf(_dome_x() - global_position.x)
	var flinging := _spr.animation == "fling" and _spr.is_playing()
	if dist > STOP_RANGE and not flinging:
		velocity.x = SPEED * direction
		if _spr.animation != "walk":
			_spr.play("walk")
	else:
		velocity.x = 0
		if not flinging and _spr.animation != "idle":
			_spr.play("idle")
	if is_on_wall() and velocity.x != 0:
		_bulldoze(delta)
	move_and_slide()
	_spr.flip_h = direction < 0
	# attacks
	_fling_t -= delta
	if _fling_t <= 0 and dist < FLING_RANGE and not flinging:
		_fling_t = FLING_EVERY
		_spr.play("fling")
	_hatch_t -= delta
	if _hatch_t <= 0 and dist < 900.0:
		_hatch_t = HATCH_EVERY
		_open_hatch()
	# chimney smoke
	_smoke -= delta
	if _smoke <= 0:
		_smoke = 0.18
		FX.burst(get_parent(), global_position + Vector2(-3 * direction, -100), Color(0.3, 0.28, 0.3, 0.6), 2, 25.0, 1.6, 3.5, -50.0)
		if randf() < 0.3:
			FX.burst(get_parent(), global_position + Vector2(-3 * direction, -100), Color(1.0, 0.6, 0.2, 0.9), 1, 40.0, 0.5, 1.2, -80.0)


## Pressed against a wall: grind away the tiles above the lowest one in the
## column ahead, then step up onto it (a ramp out of any ditch).
func _bulldoze(delta: float) -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var feet := global_position.y
	var col := tm.local_to_map(tm.to_local(global_position + Vector2(direction * 36.0, -8.0))).x
	var blocking := []
	for k in range(2, 6):   # rows from one tile above the feet up past the body
		var c := Vector2i(col, tm.local_to_map(tm.to_local(Vector2(0, feet - 8.0 - k * 16.0 + 16.0))).y)
		if c.x >= 0 and c.x < WorldGen.WORLD_WIDTH and tm.get_cell_source_id(c) != -1:
			blocking.append(c)
	if blocking.is_empty():
		velocity.y = -230.0     # one tile high: heave up onto it
		return
	_grind += delta
	_spr.position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	if _grind < GRIND:
		return
	_grind = 0.0
	_spr.position = Vector2.ZERO
	FX.shake(self, 3.0, 0.2)
	for c in blocking:
		var src := tm.get_cell_source_id(c)
		var atlas := tm.get_cell_atlas_coords(c)
		tm.set_cell(c, -1)
		WorldGen.reframe_around(tm, c)
		get_tree().call_group("tile_shading", "mark_dirty", c)
		get_tree().call_group("cave_decor", "tile_cleared", c)
		FX.tile_break(get_parent(), tm, c, src, atlas, Vector2(-direction, 0))
		ground += 1
	SFX.play_small(self, SFX.sfx_mine_break(), -4.0, 0.6)


func _on_frame() -> void:
	if _spr.animation != "fling" or _spr.frame != 2 or _dying:
		return
	var from := global_position + Vector2(RELEASE.x * direction, RELEASE.y)
	var scene := get_tree().current_scene
	var target := Vector2(_dome_x(), 70.0)
	var p := scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(global_position) < 260.0 and randf() < 0.5:
		target = p.global_position
	var t := clampf(absf(target.x - from.x) / 300.0, 0.7, 1.6)
	var s: Node2D = preload("res://scenes/slag.gd").new()
	s.global_position = from
	s.velocity = (target - from) / t - Vector2(0, 0.5 * 700.0 * t)
	get_parent().add_child(s)
	flung += 1
	SFX.play(self, SFX.sfx_turret_fire(), -4.0, 0.6)
	FX.burst(get_parent(), from, Color(1.0, 0.6, 0.2), 6, 60.0, 0.3, 1.5)


func _open_hatch() -> void:
	var at := global_position + Vector2(HATCH.x * direction, HATCH.y)
	FX.burst(get_parent(), at, Color(0.8, 0.8, 0.78, 0.7), 8, 60.0, 0.8, 3.0, -30.0)
	SFX.play_small(self, SFX.sfx_clink(), -4.0, 0.6)
	for k in 2:
		var e: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
		e.add_to_group("enemies")
		e.setup(1)   # SCUTTLER
		e.global_position = at + Vector2(-direction * 8 * k, 0)
		e.direction = direction
		get_parent().add_child.call_deferred(e)
		hatched += 1


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	_bar_fill.size.x = 390.0 * maxf(0.0, float(hp) / MAX_HP)
	_spr.modulate = Color(2.2, 1.6, 1.4)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
	FX.burst(get_parent(), hit_center() + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(1.0, 0.75, 0.4), 4, 90.0, 0.3, 1.4)
	if hp > 0:
		if randf() < 0.3:
			SFX.play(self, SFX.sfx_enemy_hit(), -6.0, 0.6)
		return
	_die()


func _die() -> void:
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	_spr.stop()
	var scene := get_tree().current_scene
	SFX.play(scene, SFX.sfx_enemy_die(), 0.0, 0.5)
	# a chain of blasts across the hull, then it bursts
	for k in 6:
		var at := global_position + Vector2(randf_range(-30, 30), randf_range(-80, -20))
		FX.burst(get_parent(), at, Color(1.0, 0.65, 0.25), 14, 170.0, 0.45, 2.2)
		FX.shake(self, 5.0, 0.2)
		SFX.play_small(self, SFX.sfx_mine_break(), -2.0, randf_range(0.5, 0.8))
		await get_tree().create_timer(0.16).timeout
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.8, 0.4), 40, 260.0, 0.6, 3.0)
	FX.burst(get_parent(), hit_center(), Color(0.3, 0.28, 0.3, 0.7), 16, 60.0, 1.6, 4.0, -40.0)
	FX.debris(get_parent(), hit_center(), 14, 260.0, false)
	FX.shake(self, 9.0, 0.5)
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 10)
	if scene.has_method("_show_banner"):
		scene._show_banner("FOUNDRY ENGINE DESTROYED", "it leaves a heap of scrap")
	if _bar:
		_bar.queue_free()
	var tw := create_tween()
	tw.tween_property(_spr, "modulate", Color(0.3, 0.25, 0.25, 0.0), 0.8)
	tw.tween_callback(queue_free)
