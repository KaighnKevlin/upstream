extends "res://scenes/rocker.gd"
## Overflow gate: the priority splitter. A rocker held tipped toward its
## primary side (`side`), so everything goes that way, until what it feeds
## is full: it watches a point (`watch`, an offset: a turret's funnel, a
## dip at a line's end) and when `full` pieces sit still there it tips the
## other way and the stream overflows to the secondary side, tipping back
## as they're used. Feed a machine first and send only the surplus on.
## Drag its ring onto the spot to watch. (Loose ore passes through ore, so
## lines never queue back to the gate: it has to look where they end.)

const STILL := 25.0              # px/s: slower than this is queued, not passing
const HOLD := 0.3                # s a piece must sit before it counts

@export var side := 1.0
@export var watch := Vector2(80, 40)   # where the primary line ends up
@export var full := 4

var overflowed := 0              # tests
var primary := 0
var _still_t := 0.0
var _held := 0
var _dragging := false


## Drag the watch ring onto where the primary line ends.
func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_mouse_position().distance_to(global_position + watch) < 18:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		watch = get_global_mouse_position() - global_position
		queue_redraw()


func _ready() -> void:
	super._ready()
	if has_meta("ghost"):
		return
	tilt = side
	_apply()


func _count_held() -> int:
	var at := global_position + watch
	var n := 0
	for b in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(b) and b.global_position.distance_to(at) < 18.0 and b.linear_velocity.length() < STILL:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if has_meta("ghost") or _shape == null:
		return
	var h := _count_held()
	if h != _held:
		_held = h
		queue_redraw()
	_still_t = _still_t + delta if _held >= full else 0.0
	var want := -side if _still_t > HOLD else side
	if want != tilt:
		tilt = want
		_apply()
		SFX.play_small(self, SFX.sfx_ore_knock("wood"), -16.0, 1.1)


func _on_leave(b) -> void:
	# counted, but no flip-flopping: the queue sets which way it leans
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	var went := 1 if b.global_position.x > global_position.x else 0
	sent[went] += 1
	if (went == 1) == (side > 0):
		primary += 1
	else:
		overflowed += 1


func _draw() -> void:
	super._draw()
	# the watched point, with a dotted line to it, lit when it's full
	var lit := _still_t > HOLD
	var n := 10
	for i in n:
		draw_circle(watch * (i + 0.5) / n, 0.8, Color(0.85, 0.65, 0.35, 0.5))
	draw_arc(watch, 18.0, 0, TAU, 20, Color(1.0, 0.5, 0.2, 0.8) if lit else Color(0.6, 0.8, 1.0, 0.4), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, watch + Vector2(-8, -22), "%d/%d" % [_held, full], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
	draw_string(font, Vector2(side * 14 - 4, -28), "1st", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
