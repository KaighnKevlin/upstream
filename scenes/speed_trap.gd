extends Node2D
## Speed trap: a brass box with an eye hung over a line that clocks every
## piece passing under it. Faster than its setting (click: 150 / 250 / 350
## px/s) and it fires what's at its pull-wire's end (drag it; unwired,
## around itself), like a tally wheel. Wire it to a kicker or a points
## switch to route by speed: slow ore one way, a fast shot the other.
## Shows the last speed it read.
##
## Rate: clocks every one, whatever the rate (no limit of its own).
##
## On a track (scripts/track/track_net.gd) it clocks the riders passing
## under it (a mark on the chute, scripts/track/track_mark.gd): each once,
## at its speed along the chute, no zone. Physics ore under it is clocked
## as before.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const TrackMark = preload("res://scripts/track/track_mark.gd")
const LIMITS := [150.0, 250.0, 350.0]

@export var mode := 1
@export var wire_to := Vector2(50, 30)

var fired := 0                   # tests
var clocked := 0
var last := 0.0
var _flash := 0.0
var _seen := {}
var _dragging := false
var _mark = null                 # where it reads the riders on the track under it (TrackMark)
var _box_art: Sprite2D           # art: the brass box, lit on a fire


func _ready() -> void:
	z_index = 2
	# the sprite first, so ghosts and build-bar icons get it too; behind our
	# own _draw (the lens, beam, wire and readouts)
	_box_art = Sprite2D.new()
	_box_art.texture = preload("res://assets/sprites/speed_trap.png")
	_box_art.centered = false
	_box_art.offset = Vector2(-10, -17)
	_box_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box_art.show_behind_parent = true
	add_child(_box_art)
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
	a.set_meta("track_ignore", true)
	_mark = TrackMark.new(self, Vector2.ZERO, 0.0, 30.0)


func _exit_tree() -> void:
	if _mark:
		_mark.drop()


## For the track net's zones: none while it reads the track, a watch round
## it while it isn't.
func ore_watch() -> Array:
	return _mark.watching() if _mark else []


func _physics_process(_delta: float) -> void:
	if _mark:
		_mark.update()


## The net: a rider went under it, at v along the chute.
func mark_event(_m, _kind: String, v: float, ev: int) -> void:
	if ev == 1:
		_clock_speed(absf(v))


func _clock(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _seen.get(b.get_instance_id(), 0.0) > now:
		return
	_seen[b.get_instance_id()] = now + 1.0
	_clock_speed(b.linear_velocity.length())


func _clock_speed(speed: float) -> void:
	last = speed
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
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(8, -8), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	# (the box is a sprite) its eye looking down, and the beam it watches with
	_box_art.self_modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 1.05), _flash)
	draw_circle(Vector2(0, -4), 1.6, Color(1.0, 0.3, 0.2).lerp(Color(1, 1, 0.6), _flash))
	draw_line(Vector2(0, -1), Vector2(0, 22), Color(1.0, 0.3, 0.2, 0.25 + _flash * 0.5), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-14, -20), ">%d" % int(LIMITS[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
	if clocked > 0:
		draw_string(font, Vector2(11, -6), "%d" % int(last), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.5) if last > LIMITS[mode] else Color(0.7, 0.66, 0.55))
