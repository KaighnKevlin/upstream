extends Node2D
## Speed trap: a brass box with an eye hung over a line that clocks every
## piece passing under it. Faster than its setting (click: 150 / 250 / 350
## px/s) and it fires what's at its pull-wire's end (drag it; unwired,
## around itself), like a tally wheel. Wire it to a kicker or a points
## switch to route by speed: slow ore one way, a fast shot the other.
## Shows the last speed it read.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const LIMITS := [150.0, 250.0, 350.0]

@export var mode := 1
@export var wire_to := Vector2(50, 30)

var fired := 0                   # tests
var clocked := 0
var last := 0.0
var _flash := 0.0
var _seen := {}
var _dragging := false


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 24)
	cs.shape = r
	cs.position = Vector2(0, 10)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_clock)


func _clock(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _seen.get(b.get_instance_id(), 0.0) > now:
		return
	_seen[b.get_instance_id()] = now + 1.0
	last = b.linear_velocity.length()
	clocked += 1
	if last > LIMITS[mode]:
		fire()
	queue_redraw()


func fire() -> void:
	fired += 1
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_ratchet(), -12.0, 1.8)
	var points := [global_position + wire_to] if wire_to != Vector2.ZERO else [global_position]
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed and wire_to != Vector2.ZERO and m.distance_to(global_position + wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and m.distance_to(global_position + Vector2(0, -8)) < 10:
			mode = (mode + 1) % LIMITS.size()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(8, -8), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	# the box, its eye looking down, and the beam it watches with
	draw_rect(Rect2(-9, -16, 18, 14), dark)
	draw_rect(Rect2(-8, -15, 16, 12), brass)
	draw_circle(Vector2(0, -4), 3.0, dark)
	draw_circle(Vector2(0, -4), 2.0, Color(1.0, 0.3, 0.2).lerp(Color(1, 1, 0.6), _flash))
	draw_line(Vector2(0, -1), Vector2(0, 22), Color(1.0, 0.3, 0.2, 0.25 + _flash * 0.5), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-14, -20), ">%d" % int(LIMITS[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
	if clocked > 0:
		draw_string(font, Vector2(11, -6), "%d" % int(last), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.5) if last > LIMITS[mode] else Color(0.7, 0.66, 0.55))
