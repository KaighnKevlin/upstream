extends Node2D
## Sling: a whirligig on a post. A piece dropped or rolled into its cup is
## caught, whirled round twice on the arm (faster and faster) and let go the
## way the arrow points (click the hub: turn it 45°). Unpowered it throws at
## a lob; with a gravity wheel or steam engine in reach it throws twice as
## hard. Lifts a line up and over, or hurls it across a gap.
## Ore-only: walkers aren't touched.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const R := 22.0                  # arm length, px
const TURNS := 2.0
const V_MIN := 200.0             # release speed = V_MIN + V_POW * power rate
const V_POW := 400.0

@export var aim := 7             # 0..7, 45° steps from pointing right; 7 = up-right

var thrown := 0                  # tests
var last_v := Vector2.ZERO       # tests: the last throw
var _held: RigidBody2D = null
var _theta := 0.0                # arm angle
var _spun := 0.0                 # how far it's turned with this one
var _w := 0.0                    # rad/s
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_catch)


func _dir() -> Vector2:
	return Vector2.RIGHT.rotated(aim * PI / 4.0)


func _catch(b) -> void:
	if _held != null or not (b is RigidBody2D) or not b.is_in_group("ore"):
		return
	if b.get_meta("sling_until", 0.0) > Time.get_ticks_msec() / 1000.0:
		return
	_held = b
	b.gravity_scale = 0.0
	# the arm swings to where it came in, already moving at its speed
	var p: Vector2 = b.global_position - global_position
	_theta = p.angle() if p.length() > 1.0 else -PI * 0.5
	_spun = 0.0
	_w = maxf(b.linear_velocity.length() / R, 3.0)
	SFX.play_small(self, SFX.sfx_roll(), -14.0, 1.4)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	if _held == null or not is_instance_valid(_held):
		_held = null
		if _w > 0:
			_w = maxf(0.0, _w - 6.0 * delta)
			_theta += _w * delta
			queue_redraw()
		return
	var v_out := V_MIN + V_POW * _rate
	_w = minf(v_out / R, _w + 14.0 * delta)
	var step := _w * delta
	# the angle where the arm's swing (theta increasing) points along the aim
	var rel := fposmod(_dir().angle() - PI * 0.5, TAU)
	var before := fposmod(_theta, TAU)
	_theta += step
	_spun += step
	var crossed := before <= rel and before + step > rel or before > rel and before + step > rel + TAU
	if _spun >= TAU * TURNS and crossed:
		_theta = rel
		var o := _held
		_held = null
		o.global_position = global_position + Vector2.RIGHT.rotated(_theta) * R
		o.gravity_scale = 1.0
		o.linear_velocity = _dir() * v_out
		o.set_meta("sling_until", Time.get_ticks_msec() / 1000.0 + 0.6)
		thrown += 1
		last_v = o.linear_velocity
		SFX.play_small(self, SFX.sfx_latch(), -10.0, 1.3)
		queue_redraw()
		return
	var at := global_position + Vector2.RIGHT.rotated(_theta) * R
	_held.linear_velocity = (at - _held.global_position) / delta
	if "_timer" in _held:
		_held._timer = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 9:
		aim = (aim + 1) % 8
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var iron := Color(0.42, 0.44, 0.5)
	# the post down to the ground, the swing circle faintly
	draw_line(Vector2(0, 4), Vector2(-6, 30), dark, 4.0)
	draw_line(Vector2(0, 4), Vector2(6, 30), dark, 4.0)
	draw_line(Vector2(0, 4), Vector2(-6, 30), iron, 2.0)
	draw_line(Vector2(0, 4), Vector2(6, 30), iron, 2.0)
	draw_arc(Vector2.ZERO, R, 0, TAU, 32, Color(0.85, 0.65, 0.35, 0.18), 1.0)
	# the arm and its cup
	var tip := Vector2.RIGHT.rotated(_theta) * R
	draw_line(Vector2.ZERO, tip, dark, 4.0)
	draw_line(Vector2.ZERO, tip, brass, 2.0)
	draw_arc(tip, 5.0, _theta + PI * 0.5, _theta + PI * 1.5, 8, dark, 3.0)
	draw_arc(tip, 5.0, _theta + PI * 0.5, _theta + PI * 1.5, 8, brass, 1.5)
	# the hub, and the arrow the throw goes
	draw_circle(Vector2.ZERO, 5.0, dark)
	draw_circle(Vector2.ZERO, 3.5, brass.lerp(Color(1, 0.95, 0.7), clampf(_w / 20.0, 0, 1)))
	var d := _dir()
	var a0 := d * (R + 6)
	var a1 := d * (R + 14)
	draw_line(a0, a1, Color(1.0, 0.85, 0.5, 0.8), 1.5)
	draw_line(a1, a1 - d.rotated(0.5) * 4, Color(1.0, 0.85, 0.5, 0.8), 1.5)
	draw_line(a1, a1 - d.rotated(-0.5) * 4, Color(1.0, 0.85, 0.5, 0.8), 1.5)
