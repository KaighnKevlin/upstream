extends CharacterBody2D
## Clockwork grenadier: a bomber. It marches in with the pack; when the
## prospector or the dome is within THROW_RANGE it stops, lights a bomb and
## lobs it on an arc. The bombs are real, physical things (ore.gd kind
## "bomb"): they bounce and roll, and go off when their fuse burns down
## (FUSE ~2.6 s), hurting everyone close, its own side included. So a
## trampoline, a bumper or a fan in their path sends them back where they
## came from, and a catapult will happily throw one.
## Art: tools/art/gen_grenadier.py (9 frames of 40x40: 6 walk, wind-up,
## release, follow-through).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const SPEED := 30.0
const GRAVITY := 980.0
const MAX_HP := 9
const THROW_RANGE := 290.0
const THROW_EVERY := 3.4
const WIND_UP := 0.45
const HAND := Vector2(9, -30)
const LOB := deg_to_rad(50.0)

var hp := MAX_HP
var damage := 4
var direction := -1.0
var thrown := 0                  # tests
var _dying := false
var _knock_t := 0.0
var _throw_t := 1.0
var _winding := -1.0
var _aim_at := Vector2.ZERO
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 30)
	cs.shape = r
	cs.position = Vector2(0, -15)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/grenadier.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 9.0, true], ["windup", [6], 1.0, false], ["throw", [7, 8], 8.0, false]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 40, 0, 40, 40)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-17, -39)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	add_child(_spr)
	var dome := _dome()
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)


func _dome() -> Node2D:
	return get_tree().current_scene.get_node_or_null("DomeZone") as Node2D


func hit_center() -> Vector2:
	return global_position + Vector2(0, -20)


func hit_radius() -> float:
	return 10.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v
		_knock_t = 0.4
		_winding = -1.0


## Who to bomb: the prospector if they're in reach, else the dome.
func _pick() -> Variant:
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(global_position) < THROW_RANGE:
		return p.global_position
	var dome := _dome()
	if dome and absf(dome.global_position.x - global_position.x) < THROW_RANGE:
		return dome.global_position + Vector2(0, -20)
	return null


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
		move_and_slide()
		return
	if _winding >= 0:
		velocity.x = 0
		_winding -= delta
		if _winding < 0:
			_throw()
		move_and_slide()
		return
	var tgt = _pick()
	if tgt != null:
		velocity.x = 0
		direction = signf(tgt.x - global_position.x) if absf(tgt.x - global_position.x) > 2 else direction
		_throw_t -= delta
		if _throw_t <= 0 and is_on_floor():
			_throw_t = THROW_EVERY
			_aim_at = tgt
			_winding = WIND_UP
			_spr.play("windup")
			SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.8)   # striking the fuse
		elif _spr.animation == "walk":
			_spr.stop()          # standing, between throws
	else:
		_spr.play("walk")
		var dome := _dome()
		var dx := (dome.global_position.x - global_position.x) if dome else 0.0
		direction = signf(dx) if absf(dx) > 1 else direction
		velocity.x = SPEED * direction
		if is_on_floor() and is_on_wall():
			velocity.y = -260.0
	_spr.flip_h = direction < 0
	_spr.offset.x = -17 if direction > 0 else -23
	move_and_slide()


## Let go: a lit bomb on an arc toward where the target was.
func _throw() -> void:
	_spr.play("throw")
	var from := global_position + Vector2(HAND.x * direction, HAND.y)
	var dx := absf(_aim_at.x - from.x)
	var h := from.y - _aim_at.y
	var denom := 2.0 * pow(cos(LOB), 2) * (dx * tan(LOB) - h)
	var v := sqrt(GRAVITY * dx * dx / denom) if denom > 0 else 260.0
	v = clampf(v * randf_range(0.93, 1.07), 150.0, 520.0)
	var b: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	b.kind = "bomb"
	b.global_position = from
	b.linear_velocity = Vector2(cos(LOB) * v * signf(_aim_at.x - from.x), -sin(LOB) * v)
	b.angular_velocity = randf_range(-8, 8)
	get_parent().add_child(b)
	thrown += 1
	SFX.play_small(self, SFX.sfx_bounce(), -8.0, 0.7)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 1.0)
		return
	_dying = true
	_winding = -1.0
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 2)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.7, 0.3), 12, 140.0, 0.35, 1.8)
	FX.debris(get_parent(), hit_center(), 6, 170.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 1.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(queue_free)
