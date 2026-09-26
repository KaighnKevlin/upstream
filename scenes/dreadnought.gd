extends Node2D
## The Dreadnought: a boss, a flying fortress that comes every tenth wave
## (instead of the Foundry Engine). It cruises in at low altitude, parks
## over your works just short of the dome and holds there: it drops bombs
## from its bay, launches ornithopters from its hangar, and sweeps a little
## back and forth. Too big for harpoons to drag down (they still hurt it);
## lightning, turrets and your gun do the rest. When it's done it goes down
## in a long burning dive and a huge crash, and leaves a mountain of scrap.
## Art: tools/art/gen_dreadnought.py (4 frames of 200x96, facing right).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

enum State { CRUISE, HOLD, FALLING }

const ALTITUDE := -120.0
const SPEED := 45.0
const HOLD_OFF := 150.0          # parks this far short of the dome
const MAX_HP := 160
const BOMB_EVERY := 3.0
const HANGAR_EVERY := 20.0
const BAY := Vector2(10, 50)
const HANGAR := Vector2(-30, 50)

var hp := MAX_HP
var damage := 0
var velocity := Vector2.ZERO     # turrets lead on this
var direction := -1.0
var bombs := 0                   # tests
var launched := 0
var _dying := false
var _state := State.CRUISE
var _hold_x := 1350.0
var _sweep := 0.0
var _bomb_t := 2.0
var _hangar_t := 6.0
var _spr: AnimatedSprite2D
var _bar: CanvasLayer
var _bar_fill: ColorRect
var _smoke := 0.0


func _ready() -> void:
	add_to_group("enemies")
	z_index = 3
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 12.0)
	var tex := preload("res://assets/sprites/dreadnought.png")
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 200, 0, 200, 96)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-100, -34)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play()
	add_child(_spr)
	var glow := PointLight2D.new()
	glow.texture = LightTextures.create_radial_light(128)
	glow.color = Color(0.6, 0.85, 1.0)
	glow.energy = 0.5
	glow.position = Vector2(0, 45)
	add_child(glow)
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	var dome_x := dome.global_position.x if dome else 1200.0
	direction = signf(dome_x - global_position.x) if absf(dome_x - global_position.x) > 1 else -1.0
	_hold_x = dome_x - direction * HOLD_OFF
	global_position.y = ALTITUDE
	_make_bar()


func _make_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	var root := Control.new()
	root.position = Vector2(440, 40)
	_bar.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.85)
	bg.size = Vector2(400, 26)
	root.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.6, 0.66, 0.66)
	edge.position = Vector2(4, 16)
	edge.size = Vector2(392, 7)
	root.add_child(edge)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.45, 0.8, 0.95)
	_bar_fill.position = Vector2(5, 17)
	_bar_fill.size = Vector2(390, 5)
	root.add_child(_bar_fill)
	var l := Label.new()
	l.text = "THE DREADNOUGHT"
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	l.position = Vector2(0, 1)
	l.size = Vector2(400, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	add_child(_bar)


func hit_center() -> Vector2:
	return global_position + Vector2(0, 14)


func hit_radius() -> float:
	return 60.0


func _physics_process(delta: float) -> void:
	match _state:
		State.CRUISE:
			velocity = Vector2(SPEED * direction, sin(Time.get_ticks_msec() * 0.0012) * 5.0)
			if (global_position.x - _hold_x) * direction >= 0:
				_state = State.HOLD
		State.HOLD:
			_sweep += delta * 0.25
			var want := _hold_x + sin(_sweep) * 90.0
			velocity = Vector2(clampf(want - global_position.x, -1.0, 1.0) * SPEED * 0.8, sin(Time.get_ticks_msec() * 0.0012) * 5.0)
			_bomb_t -= delta
			if _bomb_t <= 0:
				_bomb_t = BOMB_EVERY
				_drop_bomb()
			_hangar_t -= delta
			if _hangar_t <= 0:
				_hangar_t = HANGAR_EVERY
				_launch()
		State.FALLING:
			velocity.y += 160.0 * delta
			velocity.x = move_toward(velocity.x, direction * 40.0, 20.0 * delta)
			rotation = lerp_angle(rotation, direction * 0.35, 0.01)
			_smoke -= delta
			if _smoke <= 0:
				_smoke = 0.08
				var at := global_position + Vector2(randf_range(-80, 80), randf_range(-20, 40))
				FX.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 4, 60.0, 0.4, 2.0)
				FX.burst(get_parent(), at, Color(0.25, 0.23, 0.25, 0.6), 2, 30.0, 1.6, 4.0, -40.0)
			var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
			if (tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position + Vector2(0, 58)))) != -1) or global_position.y > 1400:
				_crash()
				return
	global_position += velocity * delta
	_spr.flip_h = direction < 0


func _drop_bomb() -> void:
	var b: Node2D = preload("res://scenes/bomb.gd").new()
	b.global_position = global_position + Vector2(BAY.x * direction, BAY.y)
	b.velocity = Vector2(velocity.x, 40)
	b.damage = 3
	get_parent().add_child(b)
	bombs += 1
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.6)


func _launch() -> void:
	var at := global_position + Vector2(HANGAR.x * direction, HANGAR.y + 10)
	FX.burst(get_parent(), at, Color(0.8, 0.8, 0.78, 0.7), 8, 60.0, 0.6, 2.4)
	for k in 1:
		var o: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
		o.add_to_group("enemies")
		o.setup(4)   # ORNITHOPTER
		o.global_position = at + Vector2(0, 10)
		o.direction = direction
		get_parent().add_child.call_deferred(o)
		launched += 1
	SFX.play(self, SFX.sfx_clink(), -4.0, 0.8)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount)
	_bar_fill.size.x = 390.0 * maxf(0.0, float(hp) / MAX_HP)
	_spr.modulate = Color(1.8, 1.8, 2.0)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
	FX.burst(get_parent(), hit_center() + Vector2(randf_range(-60, 60), randf_range(-20, 20)), Color(0.9, 0.85, 0.7), 4, 80.0, 0.3, 1.5)
	if hp > 0:
		return
	_dying = true
	remove_from_group("enemies")
	_state = State.FALLING
	velocity = Vector2(velocity.x, 10.0)
	_spr.speed_scale = 0.3
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), 0.0, 0.4)
	if _bar:
		_bar.queue_free()
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner"):
		scene._show_banner("THE DREADNOUGHT IS GOING DOWN", "")


func _crash() -> void:
	var at := global_position + Vector2(0, 50)
	for k in 5:
		FX.burst(get_parent(), at + Vector2(randf_range(-90, 90), randf_range(-30, 10)), Color(1.0, 0.7, 0.3), 20, 220.0, 0.5, 2.6)
	FX.burst(get_parent(), at, Color(0.3, 0.28, 0.3, 0.7), 20, 80.0, 2.0, 5.0, -50.0)
	FX.debris(get_parent(), at, 18, 280.0, false)
	FX.shake(self, 12.0, 0.7)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), 4.0, 0.4)
	preload("res://scenes/ore.gd").spill(get_parent(), at + Vector2(0, -20), 16)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage") and not ("_dying" in e and e._dying):
			var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
			if c.distance_to(at) < 110.0:
				e.take_damage(12)
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner"):
		scene._show_banner("DREADNOUGHT DESTROYED", "a mountain of scrap")
	queue_free()
