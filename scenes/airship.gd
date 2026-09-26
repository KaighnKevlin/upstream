extends Node2D
## Troop airship: a brass-ribbed balloon that ignores your ditches and traps
## altogether. It drifts in high, stops over a spot behind your front line
## (DROP_BEHIND short of the dome), and winches soldiers down on a rope one
## at a time; then it turns for home. Shoot it down and the whole thing
## comes crashing to the ground in a heap of scrap (troops still on the
## rope fall with it). Lightning and steep turret shots reach it.
## Art: tools/art/gen_airship.py (4 frames of 100x64, facing right).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

enum State { CRUISE, DROP, LEAVE, FALLING }

const ALTITUDE := -150.0
const SPEED := 42.0
const DROP_BEHIND := 360.0       # hovers this far short of the dome
const TROOPS := 3
const LOWER := 95.0              # rope speed
const WINCH := Vector2(4, 30)
const MAX_HP := 22

var hp := MAX_HP
var damage := 0
var velocity := Vector2.ZERO     # turrets lead on this
var direction := -1.0
var dropped := 0                 # tests
var _dying := false
var _state := State.CRUISE
var _drop_x := 1560.0
var _gap := 0.0
var _lowering: CharacterBody2D = null
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	z_index = 3
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 12.0)
	var tex := preload("res://assets/sprites/airship.png")
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 100, 0, 100, 64)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-50, -22)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play()
	add_child(_spr)
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	var dome_x := dome.global_position.x if dome else 1200.0
	direction = signf(dome_x - global_position.x) if absf(dome_x - global_position.x) > 1 else -1.0
	_drop_x = dome_x - direction * DROP_BEHIND
	global_position.y = ALTITUDE


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 26.0


func _winch() -> Vector2:
	return global_position + Vector2(WINCH.x * direction, WINCH.y)


func _physics_process(delta: float) -> void:
	match _state:
		State.CRUISE:
			velocity = Vector2(SPEED * direction, sin(Time.get_ticks_msec() * 0.002) * 4.0)
			if (global_position.x - _drop_x) * direction >= 0:
				_state = State.DROP
				_gap = 0.4
		State.DROP:
			velocity = velocity.lerp(Vector2.ZERO, 0.05)
			_drop(delta)
		State.LEAVE:
			velocity = velocity.lerp(Vector2(-SPEED * 1.3 * direction, -20.0), 0.02)
			var w := WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE
			if global_position.x < -120 or global_position.x > w + 120:
				queue_free()
		State.FALLING:
			velocity.y += 500.0 * delta
			rotation += 0.6 * delta * -direction
			var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
			if (tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position + Vector2(0, 30)))) != -1) or global_position.y > 1400:
				_crash()
				return
			if randf() < 0.5:
				FX.burst(get_parent(), global_position + Vector2(randf_range(-20, 20), -4), Color(0.3, 0.28, 0.3, 0.6), 1, 20.0, 1.2, 3.0, -30.0)
	global_position += velocity * delta
	_spr.flip_h = direction < 0
	queue_redraw()


func _drop(delta: float) -> void:
	if _lowering:
		if not is_instance_valid(_lowering) or _lowering._dying:
			_lowering = null
			return
		if _lowering.is_on_floor():
			_lowering = null      # down: it unclips and marches off
			_gap = 1.2
			return
		_lowering.velocity = Vector2(0, LOWER)
		_lowering._knock_t = 0.1  # dangling: no walking
		return
	_gap -= delta
	if _gap > 0:
		return
	if dropped >= TROOPS:
		_state = State.LEAVE
		return
	var s: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	s.add_to_group("enemies")
	s.setup(2 if dropped % 2 == 0 else 5)   # soldiers, a shieldbearer between them
	s.global_position = _winch() + Vector2(0, 14)
	s.direction = direction
	get_parent().add_child(s)
	_lowering = s
	dropped += 1
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.8)


func _draw() -> void:
	if _lowering and is_instance_valid(_lowering):
		var a := Vector2(WINCH.x * direction, WINCH.y)
		var b := to_local(_lowering.global_position + Vector2(0, -24))
		draw_line(a, b, Color(0.16, 0.15, 0.12), 2.0)
		draw_line(a, b, Color(0.72, 0.62, 0.45), 1.0)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount)
	FX.burst(get_parent(), global_position + Vector2(randf_range(-20, 20), randf_range(-8, 8)), Color(0.8, 0.7, 0.55), 4, 60.0, 0.4, 1.6)
	_spr.modulate = Color(2.2, 2.0, 1.8)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -6.0, 0.7)
		return
	# the envelope tears: it goes down
	_dying = true
	remove_from_group("enemies")
	_state = State.FALLING
	velocity = Vector2(velocity.x * 0.5 + direction * 20.0, 30.0)
	_lowering = null
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), 0.0, 0.6)
	FX.burst(get_parent(), global_position, Color(0.8, 0.7, 0.55), 14, 120.0, 0.6, 2.4)
	_spr.speed_scale = 0.3


func _crash() -> void:
	var at := global_position + Vector2(0, 26)
	FX.shake(self, 6.0, 0.35)
	FX.burst(get_parent(), at, Color(1.0, 0.7, 0.3), 24, 180.0, 0.5, 2.4)
	FX.burst(get_parent(), at, Color(0.55, 0.45, 0.35), 16, 120.0, 0.7, 2.6, 200.0)
	FX.debris(get_parent(), at, 10, 200.0, false)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), 0.0, 0.6)
	preload("res://scenes/ore.gd").spill(get_parent(), at + Vector2(0, -10), 4)
	# the wreck lands on whatever is underneath
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage") and not ("_dying" in e and e._dying):
			var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
			if c.distance_to(at) < 50.0:
				e.take_damage(6)
	queue_free()
