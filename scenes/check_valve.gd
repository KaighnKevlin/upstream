extends Node2D
## Check valve: a hinged flap hung across a track. Pieces going the way it
## opens (`side`) push it aside and roll on through; coming back the other
## way they meet a wall and bounce off. Stops a line rolling back on itself
## (a bouncy landing, a stalled climb) and makes one-way loops. Click it to
## turn it round. Put its node on the track where the flap should hang.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const H := 16.0

@export var side := 1.0

var passed := 0                  # tests: went through the way it opens
var stopped := 0                 # and turned back
var _flap: CollisionShape2D
var _open := 0.0
var _seen := {}


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	_flap = CollisionShape2D.new()
	var s := SegmentShape2D.new()
	# a one-way segment, solid only from its local up: laid flat here and
	# turned upright in _apply, its solid face toward the side it closes on
	s.a = Vector2(-(H + 2) * 0.5, 0)
	s.b = Vector2((H + 2) * 0.5, 0)
	_flap.shape = s
	_flap.position = Vector2(0, -H * 0.5 + 1)
	_flap.one_way_collision = true
	_flap.one_way_collision_margin = 6.0
	body.add_child(_flap)
	add_child(body)
	_apply()
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, H + 4)
	cs.shape = r
	cs.position = Vector2(0, -H * 0.5)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_touch)


func _apply() -> void:
	# upright, its up facing `side`: what comes from that side moving back is
	# stopped, what goes `side` passes
	_flap.rotation = PI * 0.5 * side


func _touch(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _seen.get(b.get_instance_id(), 0.0) > now:
		return
	_seen[b.get_instance_id()] = now + 0.5
	if b.linear_velocity.x * side > 0:
		passed += 1
		_open = 1.0
		SFX.play_small(self, SFX.sfx_latch(), -22.0, 1.5)
	else:
		stopped += 1


func _process(delta: float) -> void:
	if _open > 0:
		_open = maxf(0.0, _open - delta * 4.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -H * 0.5)) < 10:
		side = -side
		_apply()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the hinge bracket overhead and the flap, swinging open toward `side`
	draw_line(Vector2(-5, -H - 3), Vector2(5, -H - 3), dark, 3.0)
	var tip := Vector2(0, -H) + Vector2(0, H + 2).rotated(-_open * 1.1 * side)
	draw_line(Vector2(0, -H), tip, dark, 4.0)
	draw_line(Vector2(0, -H), tip, brass, 2.0)
	draw_circle(Vector2(0, -H), 2.0, Color(0.42, 0.44, 0.5))
	# an arrow showing the way through
	var c := Vector2(side * 9, -H - 8)
	draw_line(c - Vector2(side * 5, 0), c, brass, 1.0)
	draw_line(c, c + Vector2(-side * 3, -2), brass, 1.0)
	draw_line(c, c + Vector2(-side * 3, 2), brass, 1.0)
