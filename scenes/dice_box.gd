extends Node2D
## Dice box: a brass box with a hopper on top and a die tumbling in a
## window. Each piece that drops in is sent out of one of its outlets at
## random, the die showing which: left or right, or (click it) left, down
## or right. Over a long run every outlet gets its fair share, but never
## in a pattern, so it mixes two streams into one, or shares a stream
## between machines without the steady beat of the distributor.

const SFX = preload("res://scripts/sfx.gd")
## Launch velocities and spout positions: [left, down, right].
const OUTS := [Vector2(-150, -60), Vector2(0, 80), Vector2(150, -60)]
const SPOUT := [Vector2(-14, 4), Vector2(0, 12), Vector2(14, 4)]
const DIE := Vector2(0, -3)      # the die's window

## How many ways it sends: 2 (left, right) or 3 (left, down, right).
@export var outlets := 2

var sent := [0, 0, 0]            # tests: pieces out of each outlet (left, down, right)
var last := -1                   # the outlet the last piece went to
var _cool := {}
var _roll := 0.0                 # tumbling time left
var _spin := 0.0
var _face := 1                   # pips showing
var _rng := RandomNumberGenerator.new()   # its own die, apart from the world's dice


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	_rng.randomize()
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 14)
	cs.shape = r
	cs.position = Vector2(0, -14)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_take)


## The outlet indexes in use, into OUTS.
func ways() -> Array:
	return [0, 2] if outlets == 2 else [0, 1, 2]


func _take(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _cool.get(b.get_instance_id(), 0.0) > now:
		return
	_cool[b.get_instance_id()] = now + 1.0
	var w := ways()
	var i := _rng.randi_range(0, w.size() - 1)
	var k: int = w[i]
	b.global_position = global_position + SPOUT[k]
	b.linear_velocity = OUTS[k]
	sent[k] += 1
	last = k
	_face = i + 1
	_roll = 0.25
	SFX.play_small(self, SFX.sfx_ratchet(), -20.0, 1.3 + 0.1 * i)
	queue_redraw()


func _process(delta: float) -> void:
	if _roll > 0.0:
		_roll = maxf(0.0, _roll - delta)
		_spin += delta * 30.0
		queue_redraw()
	elif _spin != 0.0:
		_spin = 0.0
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 16:
		outlets = 3 if outlets == 2 else 2
		get_viewport().set_input_as_handled()
		queue_redraw()


## Pip layouts for faces 1..3 (the die only ever needs as many as outlets).
func _pips(face: int) -> Array:
	match face:
		1:
			return [Vector2.ZERO]
		2:
			return [Vector2(-2, -2), Vector2(2, 2)]
		_:
			return [Vector2(-2, -2), Vector2.ZERO, Vector2(2, 2)]


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	# the hopper: a brass funnel on top
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -22), Vector2(13, -22), Vector2(6, -11), Vector2(-6, -11)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -21), Vector2(11, -21), Vector2(5, -12), Vector2(-5, -12)]), brass.darkened(0.25))
	draw_line(Vector2(-13, -22), Vector2(13, -22), brass, 2.0)
	# the box
	draw_rect(Rect2(-12, -11, 24, 19), dark)
	draw_rect(Rect2(-11, -10, 22, 17), steel.darkened(0.15))
	draw_rect(Rect2(-11, -10, 22, 2), steel.lightened(0.15))
	for p in [Vector2(-9, -8), Vector2(9, -8), Vector2(-9, 5), Vector2(9, 5)]:
		draw_circle(p, 0.9, brass)
	# the window, and the die tumbling in it
	draw_rect(Rect2(DIE - Vector2(6, 6), Vector2(12, 12)), dark)
	draw_rect(Rect2(DIE - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 0.16, 0.13))
	var face := _face
	if _roll > 0.0:
		face = 1 + int(_spin * 0.5) % maxi(outlets, 2)
	draw_set_transform(DIE, _spin, Vector2.ONE)
	draw_rect(Rect2(-3.5, -3.5, 7, 7), Color(0.93, 0.9, 0.82))
	for p in _pips(face):
		draw_circle(p, 0.9, Color(0.6, 0.12, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the outlets: little spouts, the one just used lit
	for k in ways():
		var s: Vector2 = SPOUT[k]
		draw_circle(s, 3.2, dark)
		draw_circle(s, 2.2, Color(1.0, 0.8, 0.4) if k == last else Color(0.35, 0.3, 0.25))
