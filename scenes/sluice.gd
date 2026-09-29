extends Node2D
## Sluice gate: a drop-gate across a chute that holds the stream back until
## something fires it (a tripwire, a pressure plate, a bell, a timer: it's
## triggerable, like the traps), then lifts for a few seconds and lets the
## whole backlog go at once. Store ore up, spend it the moment it's needed:
## a walker steps on the plate and the turret's feed floods. Click it to
## open it by hand. Put it across a chute, `side` being the way the stream
## runs. Ore-only layer: walkers pass through.
##
## Rate: shut, none; open (OPEN_FOR s a trigger), no limit of its own: the
## backlog goes as fast as the chute rolls it.
##
## On a track (scripts/track/track_net.gd) its board is a mark on the chute
## under it (scripts/track/track_mark.gd): shut, the riders queue behind it
## (the track's own queue, backing up the line), open, they roll on. No
## zone. Set anywhere along a chute (or at its low end). Physics ore still
## meets the board's collision, as it always did.

const SFX = preload("res://scripts/sfx.gd")
const TrackMark = preload("res://scripts/track/track_mark.gd")
const ORE_ONLY := 64
const OPEN_FOR := 2.5
const H := 22.0

@export var side := 1.0

var released := 0                # tests
var opened := 0
var _gate: CollisionShape2D
var _open_t := 0.0
var _lift := 0.0
var _held: Area2D
var _board: Sprite2D
var _mark = null                 # its board on the track under it (TrackMark)


func _ready() -> void:
	z_index = 2
	# sprites (ghosts too): the frame behind our _draw (the cable, the
	# count), the board over it
	_sprite(preload("res://assets/sprites/sluice_frame.png"), Vector2(-11, -47)).show_behind_parent = true
	_board = _sprite(preload("res://assets/sprites/sluice_gate.png"), Vector2(-5, -23))
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	_gate = CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = Vector2(0, -H)
	s.b = Vector2(0, 4)
	_gate.shape = s
	body.add_child(_gate)
	add_child(body)
	_held = Area2D.new()
	_held.collision_layer = 0
	_held.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 24)
	cs.shape = r
	cs.position = Vector2(-side * 30, -8)
	_held.add_child(cs)
	add_child(_held)
	_held.set_meta("track_ignore", true)
	var past := Area2D.new()
	past.collision_layer = 0
	past.collision_mask = 2
	var pc := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(10, 24)
	pc.shape = pr
	pc.position = Vector2(side * 10, -8)
	past.add_child(pc)
	add_child(past)
	past.body_entered.connect(func(b): if b is RigidBody2D and _open_t > 0: released += 1)
	past.set_meta("track_ignore", true)
	_mark = TrackMark.new(self, Vector2.ZERO, 6.0, 10.0)
	_mark.gate(0, false)


func _exit_tree() -> void:
	if _mark:
		_mark.drop()


## For the track net's zones: none while its board is on the track, a watch
## round it while it isn't.
func ore_watch() -> Array:
	return _mark.watching() if _mark else []


## The net: a rider went under the open board.
func mark_event(_m, _kind: String, _v: float, ev: int) -> void:
	if ev == 1 and _open_t > 0:
		released += 1


func _sprite(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func held() -> int:
	if _held == null:
		return 0
	return _held.get_overlapping_bodies().filter(func(b): return b is RigidBody2D).size() + _mark.queued(8.0)


func trigger() -> void:
	if _open_t <= 0:
		opened += 1
		SFX.play_small(self, SFX.sfx_creak(), -10.0, 0.8)
	_open_t = OPEN_FOR
	_gate.set_deferred("disabled", true)
	_mark.gate(-1, true)
	var fi: int = _mark.front()
	if fi >= 0 and _mark.m.track.rv[fi] < 30.0:
		_mark.m.track.set_speed(fi, 30.0)
	# wake whatever's resting against it
	for b in _held.get_overlapping_bodies():
		if b is RigidBody2D:
			b.sleeping = false
			b.linear_velocity += Vector2(side * 30.0, -10.0)


func _physics_process(delta: float) -> void:
	if _gate == null:
		return
	_mark.update()
	if _open_t > 0:
		_open_t -= delta
		_lift = minf(1.0, _lift + delta * 6.0)
		if _open_t <= 0:
			_gate.set_deferred("disabled", false)
			_mark.gate(0, false)
	else:
		_lift = maxf(0.0, _lift - delta * 4.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -10)) < 14:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# the board, lifted when open, on its cable up to the winch drum
	var up := -_lift * (H + 2)
	_board.position = Vector2(0, up)
	draw_line(Vector2(0, -H + up), Vector2(0, -H - 22), Color(0.1, 0.08, 0.07), 2.0)
	draw_line(Vector2(0, -H + up), Vector2(0, -H - 22), Color(0.6, 0.62, 0.66), 1.0)
	# how much it's holding back
	var n := held()
	if n > 0:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-side * 30 - 6, -26), "%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.65, 0.35))
