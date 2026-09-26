extends CharacterBody2D
## Mortar crab: artillery. A squat four-legged walker with a mortar on its
## back. It marches until it's RANGE from the dome, plants its legs, and
## from there lobs a shell over everything in between (ditches, walls,
## your whole defence line) every FIRE_EVERY seconds, on a high arc at the
## dome. Shells that fall short burst where they land (setting off powder
## kegs, hurting you). It won't budge once planted: go out and kill it, or
## reach it with something long-ranged. Knocked off its spot, it re-plants.
## Art: tools/art/gen_mortar.py (8 frames of 40x36: 6 walk, planted, firing).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

enum State { MARCH, PLANT, FIRE }

const SPEED := 26.0
const GRAVITY := 980.0
const MAX_HP := 12
const RANGE := 480.0              # stops this far from the dome
const FIRE_EVERY := 4.5
const PLANT_TIME := 1.2
const MUZZLE := Vector2(3, -24)
const LOB := deg_to_rad(62.0)
const SHELL_G := 420.0
const SPREAD := 0.08             # speed jitter: some fall short, some long

var hp := MAX_HP
var damage := 5                  # contact
var direction := -1.0
var fired := 0                   # tests
var _dying := false
var _knock_t := 0.0
var _state := State.MARCH
var _t := 0.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 20)
	cs.shape = r
	cs.position = Vector2(0, -10)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/mortar.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 8.0], ["planted", [6], 1.0], ["fire", [7], 1.0]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 40, 0, 40, 36)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-18, -35)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	add_child(_spr)
	var dome := _dome()
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)


func _dome() -> Node2D:
	return get_tree().current_scene.get_node_or_null("DomeZone") as Node2D


func hit_center() -> Vector2:
	return global_position + Vector2(0, -12)


func hit_radius() -> float:
	return 13.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v * 0.6          # heavy and low
		_knock_t = 0.4
		_state = State.MARCH


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 500 * delta)
		move_and_slide()
		return
	var dome := _dome()
	var dx := (dome.global_position.x - global_position.x) if dome else 0.0
	match _state:
		State.MARCH:
			_spr.play("walk")
			if absf(dx) <= RANGE and is_on_floor():
				_state = State.PLANT
				_t = PLANT_TIME
				velocity.x = 0
				SFX.play_small(self, SFX.sfx_clink(), -6.0, 0.6)
				FX.burst(get_parent(), global_position, Color(0.55, 0.45, 0.35, 0.7), 6, 40.0, 0.4, 1.8)
			else:
				direction = signf(dx) if absf(dx) > 1 else direction
				velocity.x = SPEED * direction
				if is_on_floor() and is_on_wall():
					velocity.y = -250.0
		State.PLANT:
			velocity.x = 0
			_spr.play("planted")
			_t -= delta
			if _t <= 0:
				_state = State.FIRE
				_t = 0.5
		State.FIRE:
			velocity.x = 0
			_t -= delta
			if _t <= 0:
				_fire()
				_t = FIRE_EVERY
			_spr.play("fire" if _t > FIRE_EVERY - 0.18 else "planted")
	_spr.flip_h = direction < 0
	move_and_slide()


func _muzzle() -> Vector2:
	return global_position + Vector2(MUZZLE.x * direction, MUZZLE.y)


## A high lob: speed for a fixed launch angle to land on the dome's crown.
func _fire() -> void:
	var dome := _dome()
	if dome == null:
		return
	var from := _muzzle()
	var target := dome.global_position + Vector2(0, -30)
	var dx := absf(target.x - from.x)
	var h := from.y - target.y            # target height above the muzzle
	var denom := 2.0 * pow(cos(LOB), 2) * (dx * tan(LOB) - h)
	if denom <= 0:
		return
	var v := sqrt(SHELL_G * dx * dx / denom) * (1.0 + randf_range(-SPREAD, SPREAD))
	var b: Node2D = preload("res://scenes/bomb.gd").new()
	b.gravity = SHELL_G
	b.damage = 3
	b.global_position = from
	b.velocity = Vector2(cos(LOB) * v * signf(target.x - from.x), -sin(LOB) * v)
	get_parent().add_child(b)
	fired += 1
	SFX.play(self, SFX.sfx_turret_fire(), -4.0, 0.55)
	FX.burst(get_parent(), from, Color(1.0, 0.8, 0.4), 8, 90.0, 0.25, 1.6, -30.0)
	FX.burst(get_parent(), from, Color(0.7, 0.7, 0.68, 0.7), 6, 30.0, 1.0, 3.0, -40.0)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 0.8)
		return
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 3)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), 0.0, 0.8)
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.7, 0.3), 14, 150.0, 0.4, 2.0)
	FX.debris(get_parent(), hit_center(), 8, 180.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 0.5, 0.3)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(queue_free)
