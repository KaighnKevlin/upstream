extends Node2D
## Catapult: catches ore (or ingots) in its bucket and flings them where it's
## aimed: sideways, backwards, high. A transport piece that can redirect ore
## anywhere, unlike a trampoline which only reflects what lands on it.
##
## Cycle: catch -> wind up -> the arm whips round from rest (low, behind) to
## the aim direction and lets go at the aimed speed -> the arm drops back.
## Aim: click it, drag the handle (direction = aim, distance = force); a
## dotted arc previews the throw.
## Art: tools/art/gen_catapult.py (origin = the arm's pivot).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const Trajectory = preload("res://scripts/trajectory_preview.gd")

## Aim in degrees (0 = straight up, positive = right).
@export_range(-170, 170, 1) var aim_angle: float = 35.0
@export_range(150, 1200, 10) var throw_speed: float = 480.0

const ARM_LEN := 27.0          # pivot to bucket centre
const CATCH_RADIUS := 11.0
const WIND_UP := 0.18
const SWING := 0.14
const RESET := 0.45
const HANDLE_MIN := 22.0
const HANDLE_MAX := 110.0
const SPEED_RANGE := Vector2(150, 1200)

var _arm: Sprite2D
var _catch: Area2D
var _held: RigidBody2D
var _busy := false
var _selected := false
var _dragging := false
var _handle: Polygon2D
var _arc: Node2D
var last_thrown: RigidBody2D   # for inspection/tests


func _ready() -> void:
	_snap_to_floor()
	var base := Sprite2D.new()
	base.texture = load("res://assets/sprites/catapult_base.png")
	base.centered = false
	base.offset = Vector2(-18, -12)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(base)
	_arm = Sprite2D.new()
	_arm.texture = load("res://assets/sprites/catapult_arm.png")
	_arm.centered = false
	_arm.offset = Vector2(-4, -6)
	_arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arm.z_index = 1
	add_child(_arm)
	_arm.rotation = _rest_angle()
	if has_meta("ghost"):
		return
	_catch = Area2D.new()
	_catch.collision_layer = 0
	_catch.collision_mask = 2   # ore, ingots
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = CATCH_RADIUS
	cs.shape = c
	_catch.add_child(cs)
	add_child(_catch)
	_catch.body_entered.connect(_on_catch, CONNECT_DEFERRED)
	_place_catch()
	_handle = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(Vector2.from_angle(k * TAU / 12) * 5)
	_handle.polygon = pts
	_handle.color = Color(1.0, 0.7, 0.2)
	_handle.visible = false
	_handle.z_index = 21
	add_child(_handle)
	_arc = Trajectory.new()
	_arc.tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer")
	_arc.visible = false
	add_child(_arc)
	_aim_visuals()


## The frame's feet stand on the floor; the pivot is 16px above it.
func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 6:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	var ctr := tm.to_global(tm.map_to_local(cell))
	global_position = Vector2(global_position.x, ctr.y + 8 - 18)  # x stays where it was put


func _aim_dir() -> Vector2:
	var a := deg_to_rad(aim_angle)
	return Vector2(sin(a), -cos(a))


## Arm at rest: low and behind, opposite the throw, so the swing goes up and over.
func _rest_angle() -> float:
	var side := 1.0 if _aim_dir().x >= 0 else -1.0
	return PI / 2 + side * 0.9  # down-left for a rightward throw, down-right for leftward


func _bucket_at(arm_angle: float) -> Vector2:
	return Vector2.from_angle(arm_angle) * ARM_LEN


func _place_catch() -> void:
	if _catch:
		_catch.position = _bucket_at(_arm.rotation) + Vector2(0, -3)


func _on_catch(body) -> void:   # untyped: a deferred call can arrive after the body was freed
	if _busy or not is_instance_valid(body) or not body is RigidBody2D:
		return
	_busy = true
	_held = body
	_held.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC  # carried smoothly in the bucket
	_held.set_deferred("freeze", true)
	_held.set_meta("caught_by", self)
	SFX.play(self, SFX.sfx_mine_hit())
	_throw()


func _physics_process(_delta: float) -> void:
	if _held and is_instance_valid(_held):
		# ride in the bucket
		_held.global_position = to_global(_bucket_at(_arm.rotation) + Vector2.from_angle(_arm.rotation - PI / 2) * 4)
		if "_timer" in _held:
			_held._timer = 0.0


func _throw() -> void:
	await get_tree().create_timer(WIND_UP).timeout
	if not is_inside_tree():
		return
	var release := _aim_dir().angle()
	var start := _arm.rotation
	# whip the long way over the top: rest (below) -> aim
	var target := release
	if _aim_dir().x >= 0:   # bucket starts low-left, goes up over the top (angle increasing)
		while target < start:
			target += TAU
	else:                   # mirrored
		while target > start:
			target -= TAU
	var t := create_tween()
	t.tween_property(_arm, "rotation", target, SWING).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_arm.rotation = wrapf(_arm.rotation, -PI, PI)
	if _held and is_instance_valid(_held):
		var b := _held
		_held = null
		b.global_position = to_global(_bucket_at(_arm.rotation) + _aim_dir() * 4)
		b.freeze = false
		b.sleeping = false
		b.linear_velocity = _aim_dir() * throw_speed
		b.angular_velocity = randf_range(-10, 10)
		b.remove_meta("caught_by")
		last_thrown = b
	SFX.play(self, SFX.sfx_bounce())
	FX.burst(get_parent(), to_global(_bucket_at(_arm.rotation)), Color(0.8, 0.75, 0.6, 0.7), 4, 30.0, 0.3, 1.5)
	var back := create_tween()
	back.tween_interval(0.08)
	back.tween_property(_arm, "rotation", _rest_angle(), RESET).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	_place_catch()
	_busy = false
	# anything that arrived during the swing and is sitting in the bucket
	if _catch:
		for other in _catch.get_overlapping_bodies():
			if other is RigidBody2D and not _busy:
				_on_catch(other)


# ── aiming UI (as the vein tapper) ─────────────────────────────────────

func _handle_dist() -> float:
	return remap(throw_speed, SPEED_RANGE.x, SPEED_RANGE.y, HANDLE_MIN, HANDLE_MAX)


func _aim_visuals() -> void:
	var dir := _aim_dir()
	if not _busy:
		_arm.rotation = _rest_angle()
		_place_catch()
	_handle.position = dir * _handle_dist()
	_arc.origin = global_position + dir * (ARM_LEN + 4)
	_arc.velocity = dir * throw_speed
	_arc.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	_handle.visible = on
	_arc.visible = on
	modulate = Color(1.2, 1.15, 1.05) if on else Color.WHITE
	_aim_visuals()


func _input(event: InputEvent) -> void:
	if _handle == null:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			_set_selected(false)
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			_set_selected(false)
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var over_body := mouse.distance_to(global_position) < 18
			if _selected and mouse.distance_to(to_global(_handle.position)) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif over_body:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var v := mouse - global_position
		if v.length() > 4:
			aim_angle = clampf(rad_to_deg(v.angle() + PI / 2), -170, 170)
			aim_angle = wrapf(aim_angle, -180, 180)
			throw_speed = clampf(remap(v.length(), HANDLE_MIN, HANDLE_MAX, SPEED_RANGE.x, SPEED_RANGE.y),
				SPEED_RANGE.x, SPEED_RANGE.y)
			_aim_visuals()
		get_viewport().set_input_as_handled()
