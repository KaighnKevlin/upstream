extends Node2D
## Clockwork magpie: an ore thief. It ignores the dome and goes for your
## supply chain: loose ore in flight, rolling on the ground, riding a belt.
## It swoops, grabs a piece in its claw and flies off the edge of the map
## with it. Loaded down it flies slowly, so there's time to shoot it: any
## hit makes it drop what it's carrying (the ore falls with the bird's
## momentum), and three hits bring it down.
## Ore in hoppers and turret funnels is safe: it only takes what's loose.
## Art: tools/art/gen_magpie.py (8 frames of 40x28, facing right).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

enum State { SEEK, CARRY, FLUSTERED, DYING }

const SEEK_SPEED := 150.0
const SWOOP_SPEED := 230.0
const CARRY_SPEED := 80.0     # weighed down: the window to shoot it
const TURN := 3.5             # steering responsiveness (1/s)
const SIGHT := 800.0
const GRAB_DIST := 11.0
const CLAW := Vector2(1, 9)   # where carried ore hangs, from the body centre
const CRUISE_Y := -90.0
const EXIT_Y := -110.0
const MAX_HP := 3

var hp := MAX_HP
var damage := 4               # a peck if the prospector gets in its way
var velocity := Vector2(-SEEK_SPEED, 0)   # turrets lead on this
var direction := -1.0
var _dying := false
var _state := State.SEEK
var _target: RigidBody2D
var _carried: RigidBody2D
var _retarget := 0.0
var _fluster := 0.0
var _patrol_t := randf() * TAU
var _spr: AnimatedSprite2D
var stolen := 0               # for tests


func _ready() -> void:
	add_to_group("enemies")
	z_index = 3
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/magpie.png")
	for spec in [["fly", [0, 1, 2, 3, 4, 5], 14.0, true], ["dive", [6, 7], 8.0, true]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 40, 0, 40, 28)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-19, -13)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("fly")
	add_child(_spr)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 10.0


func _physics_process(delta: float) -> void:
	match _state:
		State.DYING:
			velocity.y += 700.0 * delta
			rotation += 9.0 * delta * signf(velocity.x + 0.01)
			global_position += velocity * delta
			var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
			if tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position))) != -1 or global_position.y > 1400:
				_crash()
			return
		State.FLUSTERED:
			_fluster -= delta
			_steer(Vector2(global_position.x + direction * 60, CRUISE_Y - 30), SEEK_SPEED, delta)
			if _fluster <= 0:
				_state = State.SEEK
		State.CARRY:
			if not is_instance_valid(_carried):
				_state = State.SEEK
			else:
				var exit_x := WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE + 80.0
				_steer(Vector2(exit_x, EXIT_Y), CARRY_SPEED / sqrt(maxf(_carried.mass, 1.0)), delta)  # iron weighs it down
				_carried.global_position = global_position + CLAW.rotated(rotation)
				_carried.linear_velocity = Vector2.ZERO
				if "_timer" in _carried:
					_carried._timer = 0.0
				if global_position.x > exit_x - 20:
					_carried.queue_free()   # gone: it got away with it
					_carried = null
					stolen += 1
					queue_free()
		State.SEEK:
			_seek(delta)
	global_position += velocity * delta
	if absf(velocity.x) > 8:
		direction = signf(velocity.x)
	_spr.flip_h = direction < 0
	# bank into the dive
	var diving := _state == State.SEEK and velocity.y > 90
	_spr.play("dive" if diving else "fly")
	rotation = lerp_angle(rotation, clampf(velocity.y / 400.0, -0.35, 0.5) * direction, 0.15)


func _seek(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0 or not _valid(_target):
		_retarget = 0.4
		_target = _pick_ore()
	if _target:
		var aim := _target.global_position - CLAW
		# lead a moving piece a little
		aim += _target.linear_velocity * clampf(global_position.distance_to(aim) / SWOOP_SPEED, 0.0, 0.5)
		var close := global_position.distance_to(aim) < 90
		_steer(aim, SWOOP_SPEED if close else SEEK_SPEED, delta, 7.0 if close else TURN)
		if (global_position + CLAW).distance_to(_target.global_position) < GRAB_DIST:
			_grab(_target)
	else:
		# nothing loose: circle over the works, waiting
		_patrol_t += delta * 0.6
		_steer(Vector2(1300 + cos(_patrol_t) * 260, CRUISE_Y + sin(_patrol_t * 2.0) * 25), SEEK_SPEED * 0.7, delta)


func _steer(to: Vector2, speed: float, delta: float, turn := TURN) -> void:
	var want := (to - global_position).limit_length(1.0) if global_position.distance_to(to) > 1 else Vector2.ZERO
	want = want.normalized() * speed if want.length() > 0.01 else Vector2.ZERO
	velocity = velocity.lerp(want, minf(1.0, turn * delta))


func _valid(o) -> bool:
	return o != null and is_instance_valid(o) and not o.freeze and not o.has_meta("caught_by") \
		and not o.has_meta("store_material")


func _pick_ore() -> RigidBody2D:
	var best: RigidBody2D = null
	var best_d := SIGHT
	for o in get_tree().get_nodes_in_group("ore"):
		if not _valid(o):
			continue
		var d: float = global_position.distance_to(o.global_position)
		# prefers pieces that are already up in the air: easier pickings
		if o.global_position.y < 60:
			d *= 0.7
		if d < best_d:
			best_d = d
			best = o
	return best


func _grab(o: RigidBody2D) -> void:
	_carried = o
	_target = null
	o.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	o.set_deferred("freeze", true)
	o.set_meta("caught_by", self)
	_state = State.CARRY
	velocity = velocity.limit_length(CARRY_SPEED) + Vector2(0, -40)
	SFX.play(self, SFX.sfx_clink())


func _drop() -> void:
	if not is_instance_valid(_carried):
		_carried = null
		return
	var o := _carried
	_carried = null
	o.freeze = false
	o.remove_meta("caught_by")
	o.linear_velocity = velocity + Vector2(0, 30)
	o.sleeping = false


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount, self)
	_drop()
	FX.burst(get_parent(), global_position, Color(0.85, 0.75, 0.55), 5, 80.0, 0.3, 1.5)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		_dying = true
		_state = State.DYING
		preload("res://scenes/ore.gd").spill(get_parent(), global_position, 1)
		velocity = Vector2(velocity.x * 0.5, -60)
		SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
		_spr.stop()
		return
	SFX.play(self, SFX.sfx_enemy_hit())
	# startled: flaps up and away for a moment, then goes looking again
	_state = State.FLUSTERED
	_fluster = 0.7
	velocity = Vector2(-direction * 60, -160)


func _crash() -> void:
	FX.burst(get_parent(), global_position, Color(0.78, 0.6, 0.35), 10, 110.0, 0.5, 2.0)
	FX.burst(get_parent(), global_position, Color(0.6, 0.66, 0.66), 6, 80.0, 0.4, 1.5)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(1))
	queue_free()


func _exit_tree() -> void:
	_drop()
