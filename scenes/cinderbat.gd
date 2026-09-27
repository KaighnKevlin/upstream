extends Node2D
## Cinder bat: a little clockwork bat of the hot depths. It roosts upside
## down on a chamber ceiling, wings folded, ember chest glowing; when the
## prospector comes within WAKE it drops and swoops at them, bites, then
## flaps back up to its roost to try again. Fragile (a shot or two), but
## they come in threes. Placed by scripts/depths.gd in the hot chambers.
## Art: tools/art/gen_cinderbat.py (4 frames of 24x16: 3 flap, folded).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

enum State { ROOST, SWOOP, RETURN }

const WAKE := 170.0
const SPEED := 150.0
const BITE := 5
const MAX_HP := 3

var hp := MAX_HP
var damage := BITE
var velocity := Vector2.ZERO
var buried := true               # roosting: turrets leave it be
var bites := 0                   # tests
var _dying := false
var _state := State.ROOST
var _roost := Vector2.ZERO
var _wobble := 0.0
var _rest := 0.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("cinderbats")
	z_index = 3
	_roost = global_position
	_wobble = randf() * TAU
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/cinderbat.png")
	for spec in [["fly", [0, 1, 2, 1], 16.0], ["roost", [3], 1.0]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 24, 0, 24, 16)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("roost")
	_spr.flip_v = true
	add_child(_spr)
	var glow := PointLight2D.new()
	glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(32)
	glow.color = Color(1.0, 0.5, 0.15)
	glow.energy = 0.7
	add_child(glow)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 8.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v
		_state = State.RETURN


func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") as Node2D


func _process(delta: float) -> void:
	if _dying:
		return
	var p := _player()
	_wobble += delta * 6.0
	match _state:
		State.ROOST:
			_rest -= delta
			if p and _rest <= 0 and p.global_position.distance_to(global_position) < WAKE:
				_state = State.SWOOP
				buried = false
				_spr.flip_v = false
				_spr.play("fly")
				SFX.play_small(self, SFX.sfx_clink(), -12.0, 2.2)
			return
		State.SWOOP:
			if p == null:
				_state = State.RETURN
				return
			var to := p.global_position + Vector2(0, -12) - global_position
			velocity = velocity.lerp(to.normalized() * SPEED + Vector2(0, sin(_wobble) * 30.0), minf(1.0, 5.0 * delta))
			if to.length() < 12.0:
				if p.has_method("take_damage"):
					p.take_damage(BITE)
				bites += 1
				FX.burst(get_parent(), global_position, Color(1.0, 0.55, 0.2), 6, 70.0, 0.3, 1.4)
				velocity = -to.normalized() * SPEED + Vector2(0, -80)
				_state = State.RETURN
			elif to.length() > WAKE * 2.2:
				_state = State.RETURN
		State.RETURN:
			var back := _roost - global_position
			velocity = velocity.lerp(back.normalized() * SPEED * 0.8 + Vector2(sin(_wobble) * 25.0, 0), minf(1.0, 3.0 * delta))
			if back.length() < 6.0:
				global_position = _roost
				velocity = Vector2.ZERO
				_state = State.ROOST
				_rest = 1.2
				buried = true
				_spr.flip_v = true
				_spr.play("roost")
	global_position += velocity * delta
	_spr.flip_h = velocity.x < 0
	if randf() < delta * 6.0:
		FX.burst(get_parent(), global_position + Vector2(0, 3), Color(1.0, 0.5, 0.15, 0.8), 1, 12.0, 0.4, 1.0, 20.0)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	if hp > 0:
		_state = State.RETURN
		_spr.modulate = Color(3, 3, 3)
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
		return
	_dying = true
	remove_from_group("enemies")
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), -6.0, 1.8)
	FX.burst(get_parent(), global_position, Color(1.0, 0.55, 0.2), 12, 110.0, 0.4, 1.6)
	FX.debris(get_parent(), global_position, 3, 120.0, false)
	var o: RigidBody2D = load("res://scenes/ore.tscn").instantiate()
	o.kind = "grit"
	o.global_position = global_position
	get_parent().add_child.call_deferred(o)
	queue_free()
