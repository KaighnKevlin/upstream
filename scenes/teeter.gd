extends Node2D
## Teeter launcher: a seesaw with a cup on each end. A piece sits loaded in
## the near cup; another dropping into the far cup slams it down and flings
## the loaded one up into the air, harder the heavier and faster the drop
## (and the lighter the one flung: iron dropped on copper sends it high).
## Then the beam rocks back and the new arrival rolls across into the near
## cup, loaded for the next. Each piece dropped in fires the one before it.
## `side` is the side of the drop cup; the launch goes up and away from it.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ARM := 30.0
const TILT := 0.42
const V_MIN := 280.0
const V_MAX := 950.0

@export var side := 1.0

var launched := 0                # tests
var last_speed := 0.0
var _loaded: RigidBody2D = null
var _incoming: RigidBody2D = null
var _angle := 0.0                # + : the drop cup is down
var _settle := 0.0               # the new one rolling across


func _ready() -> void:
	z_index = 2
	_angle = -TILT * side
	if has_meta("ghost"):
		return
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 26)
	cs.shape = r
	cs.position = Vector2(side * ARM, -16)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_drop_in)


func _cup(s: float) -> Vector2:
	# the cup at the end on side s, following the beam's tilt
	return Vector2(s * ARM * cos(_angle), s * ARM * sin(_angle) * side) + Vector2(0, -7)


func _drop_in(b) -> void:
	if not (b is RigidBody2D) or b == _loaded or b == _incoming or b.has_meta("teeter_launched"):
		return
	var hit := maxf(b.linear_velocity.y, 0.0)
	if is_instance_valid(_loaded):
		# the slam: momentum from the drop into the loaded piece
		var v := clampf(V_MIN + hit * 0.9 * b.mass / maxf(_loaded.mass, 0.3), V_MIN, V_MAX)
		_loaded.gravity_scale = 1.0
		_loaded.set_meta("teeter_launched", true)
		_loaded.linear_velocity = Vector2(-side * 70.0, -v)
		last_speed = v
		launched += 1
		_angle = TILT * side
		FX.burst(get_parent(), _loaded.global_position, Color(1.0, 0.85, 0.5), 5, 70.0, 0.2, 1.0)
		SFX.play_small(self, SFX.sfx_bounce(), -6.0, 0.8)
		_loaded = null
	# the arrival is kept and rolled across into the near cup
	_incoming = b
	b.gravity_scale = 0.0
	_settle = 0.0


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	if is_instance_valid(_incoming):
		_settle += delta
		# the beam rocks back while it rolls across
		_angle = move_toward(_angle, -TILT * side, delta * 1.4)
		var from := global_position + _cup(side)
		var to := global_position + _cup(-side)
		var target := from.lerp(to, clampf(_settle / 0.7, 0.0, 1.0))
		_incoming.linear_velocity = (target - _incoming.global_position) / delta
		if _settle >= 0.7:
			_loaded = _incoming
			_incoming = null
	elif is_instance_valid(_loaded):
		_angle = move_toward(_angle, -TILT * side, delta * 1.4)
		var hold := global_position + _cup(-side)
		_loaded.linear_velocity = (hold - _loaded.global_position) / delta
		if "_timer" in _loaded:
			_loaded._timer = 0.0
	else:
		_loaded = null
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var wood := Color(0.55, 0.4, 0.22)
	# the fulcrum
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 16), Vector2(8, 16), Vector2(0, 0)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 15), Vector2(6, 15), Vector2(0, 2)]), Color(0.4, 0.3, 0.2))
	# the beam
	var d := Vector2(cos(_angle), sin(_angle) * side) * ARM
	draw_line(-d, d, dark, 6.0)
	draw_line(-d, d, wood, 4.0)
	# cups at the ends
	for s in [-1.0, 1.0]:
		var c := _cup(s) + Vector2(0, 7)
		draw_line(c + Vector2(-8, -9), c + Vector2(-6, 0), dark, 3.0)
		draw_line(c + Vector2(6, 0), c + Vector2(8, -9), dark, 3.0)
		draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), dark, 3.0)
		draw_line(c + Vector2(-6, -1), c + Vector2(6, -1), Color(0.85, 0.65, 0.35), 1.0)
	draw_circle(Vector2.ZERO, 3.0, Color(0.85, 0.65, 0.35))
