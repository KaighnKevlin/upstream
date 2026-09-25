extends Node2D
## Gravity wheel: an overshot bucket wheel. Ore dropped into its intake
## (the top, on the side it turns toward) rides a bucket down; its weight on
## the descending side turns the wheel, and at the bottom the bucket tips it
## out along the rim into whatever comes next. The turning wheel powers
## machines in reach (scripts/power.gd) over leather drive belts; each one
## it drives loads it a little. Heavy ore (iron) turns it harder.
## A ratchet stops it running backwards. Click it to mirror (turn the other
## way: intake and outlet swap sides) while it's empty.
## Art: tools/art/gen_wheel.py.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const Tech = preload("res://scripts/tech.gd")

const R := 27.0                # bucket centre radius
const N := 8
const G := 980.0
const INERTIA := 5000.0
const BEARING := 15000.0       # friction torque per rad/s
const LOAD := 2500.0           # extra per machine driven
const RATED := 2.0             # rad/s for full power
const MAX_OMEGA := 5.0
const INTAKE_AT := 35.0        # degrees from the top, toward the turn
const DUMP_AT := 165.0
const STAND_DROP := 38.0       # axle above the ground

@export var mirrored := false

var theta := 0.0               # wheel angle (radians)
var omega := 0.0
var _buckets := []             # N entries: RigidBody2D or null
var _wheel: Sprite2D
var _intake: Area2D
var _users := []               # machines in reach (refreshed every so often)
var _scan := 0.0
var _belt_phase := 0.0
var dumped := 0                # for tests


func _s() -> float:
	return -1.0 if mirrored else 1.0


func _ready() -> void:
	z_index = 1
	add_to_group("power_wheels")
	if not has_meta("ghost"):
		_snap_to_ground()
	var stand := Sprite2D.new()
	stand.texture = preload("res://assets/sprites/wheel_stand.png")
	stand.centered = false
	stand.offset = Vector2(-25, -6)
	stand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stand.z_index = -1
	add_child(stand)
	_wheel = Sprite2D.new()
	_wheel.texture = preload("res://assets/sprites/gravity_wheel.png")
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_wheel)
	_buckets.resize(N)
	_buckets.fill(null)
	if has_meta("ghost"):
		remove_from_group("power_wheels")
		return
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	cs.shape = c
	_intake.add_child(cs)
	add_child(_intake)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)
	_place_intake()


func _snap_to_ground() -> void:
	var space := get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 240), 1))
	if not hit.is_empty():
		global_position.y = hit.position.y - STAND_DROP


func _place_intake() -> void:
	if _intake:
		_intake.position = _rim(deg_to_rad(INTAKE_AT), R + 4.0)


## A point on the wheel at angle phi (from the top, measured the way it turns).
func _rim(phi: float, radius := R) -> Vector2:
	return Vector2(_s() * sin(phi), -cos(phi)) * radius


func _bucket_phi(k: int) -> float:
	return fposmod(theta + k * TAU / N, TAU)


func power() -> float:
	return clampf(omega / RATED * Tech.mult("buckets"), 0.0, 1.0)


func _on_intake(body) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(body):
		return
	var o := body as RigidBody2D
	if o == null or o.freeze or o.has_meta("caught_by") or o.get_meta("wheel_cool", 0.0) > Time.get_ticks_msec() / 1000.0:
		return
	# the empty bucket nearest the intake, on the loading side
	var best := -1
	var best_d := deg_to_rad(40.0)
	for k in N:
		if _buckets[k] != null:
			continue
		var d := absf(angle_difference(_bucket_phi(k), deg_to_rad(INTAKE_AT)))
		if d < best_d:
			best_d = d
			best = k
	if best < 0:
		return  # all full here: it bounces on past
	_buckets[best] = o
	o.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	o.set_deferred("freeze", true)
	o.set_meta("caught_by", self)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.8)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	# torque from the loaded buckets (only the descending side pulls)
	var torque := 0.0
	for k in N:
		var o = _buckets[k]
		if o == null:
			continue
		if not is_instance_valid(o):
			_buckets[k] = null
			continue
		torque += o.mass * G * R * sin(_bucket_phi(k))
	_scan -= delta
	if _scan <= 0:
		_scan = 0.5
		_users.clear()
		for u in get_tree().get_nodes_in_group("power_users"):
			if is_instance_valid(u) and u != self and u.global_position.distance_to(global_position) <= Power.REACH:
				_users.append(u)
	torque -= (BEARING + LOAD * _users.size()) * omega
	omega = clampf(omega + torque / INERTIA * delta, 0.0, MAX_OMEGA)   # ratchet: never backwards
	theta = fposmod(theta + omega * delta, TAU)
	_wheel.rotation = theta * _s()
	_wheel.flip_h = mirrored
	_belt_phase = fmod(_belt_phase + omega * 12.0 * delta, 8.0)
	# carry and dump
	var now := Time.get_ticks_msec() / 1000.0
	for k in N:
		var o = _buckets[k]
		if o == null:
			continue
		var phi := _bucket_phi(k)
		o.global_position = global_position + _rim(phi)
		if "_timer" in o:
			o._timer = 0.0
		if phi > deg_to_rad(DUMP_AT) and phi < deg_to_rad(DUMP_AT + 60):
			_buckets[k] = null
			o.freeze = false
			o.remove_meta("caught_by")
			o.set_meta("wheel_cool", now + 0.6)
			o.sleeping = false
			# leaves along the rim at the wheel's speed, tipping outward
			var tangent := Vector2(_s() * cos(phi), sin(phi))
			o.linear_velocity = tangent * omega * R + _rim(phi, 1.0) * 40.0
			dumped += 1
	queue_redraw()


# ── drive belts to the machines it powers, and a speed gauge ───────────

const LEATHER := Color(0.36, 0.24, 0.16)
const LEATHER_HI := Color(0.55, 0.38, 0.25)
const DARK := Color(0.09, 0.07, 0.1)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	for u in _users:
		if not is_instance_valid(u):
			continue
		var to := to_local(u.global_position)
		var d := to.normalized()
		var n := d.orthogonal() * 2.0
		for side in [-1.0, 1.0]:
			draw_line(n * side, to + n * side, DARK, 2.0)
			draw_line(n * side, to + n * side, LEATHER, 1.0)
		# stitching that travels with the belt
		var l := to.length()
		var k := _belt_phase
		while k < l:
			draw_rect(Rect2((d * k + n).round(), Vector2(1, 1)), LEATHER_HI)
			draw_rect(Rect2((d * (l - k) - n).round(), Vector2(1, 1)), LEATHER_HI)
			k += 8.0
		draw_circle(to, 3.0, DARK)
		draw_circle(to, 2.0, BRASS)
	# gauge on the stand: a needle over a brass dial, full right at rated speed
	var g := Vector2(0, 22)
	draw_circle(g, 5.0, DARK)
	draw_circle(g, 4.0, Color(0.86, 0.8, 0.62))
	var a := lerpf(PI * 0.8, PI * 0.2, power()) + PI
	draw_line(g, g + Vector2.from_angle(a) * 3.5, DARK, 1.0)


func _input(event: InputEvent) -> void:
	if _intake == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position) < 14:
			for o in _buckets:
				if o != null:
					return  # loaded: can't turn it round
			mirrored = not mirrored
			_place_intake()
			get_viewport().set_input_as_handled()
