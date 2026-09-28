extends Node2D
## Sluice gate: a drop-gate across a chute that holds the stream back until
## something fires it (a tripwire, a pressure plate, a bell, a timer: it's
## triggerable, like the traps), then lifts for a few seconds and lets the
## whole backlog go at once. Store ore up, spend it the moment it's needed:
## a walker steps on the plate and the turret's feed floods. Click it to
## open it by hand. Put it across a chute, `side` being the way the stream
## runs. Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
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


func _ready() -> void:
	z_index = 2
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


func held() -> int:
	if _held == null:
		return 0
	return _held.get_overlapping_bodies().filter(func(b): return b is RigidBody2D).size()


func trigger() -> void:
	if _open_t <= 0:
		opened += 1
		SFX.play_small(self, SFX.sfx_ore_knock("wood"), -8.0, 0.7)
	_open_t = OPEN_FOR
	_gate.set_deferred("disabled", true)
	# wake whatever's resting against it
	for b in _held.get_overlapping_bodies():
		if b is RigidBody2D:
			b.sleeping = false
			b.linear_velocity += Vector2(side * 30.0, -10.0)


func _physics_process(delta: float) -> void:
	if _gate == null:
		return
	if _open_t > 0:
		_open_t -= delta
		_lift = minf(1.0, _lift + delta * 6.0)
		if _open_t <= 0:
			_gate.set_deferred("disabled", false)
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
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the frame: two uprights and a crossbar
	for x in [-5.0, 5.0]:
		draw_line(Vector2(x, 6), Vector2(x, -H - 18), dark, 3.0)
	draw_line(Vector2(-7, -H - 18), Vector2(7, -H - 18), dark, 4.0)
	# the gate board, lifted when open
	var up := -_lift * (H + 2)
	draw_rect(Rect2(-3, -H + up, 6, H + 4), dark)
	draw_rect(Rect2(-2, -H + 1 + up, 4, H + 2), Color(0.55, 0.42, 0.25))
	draw_line(Vector2(0, -H + up), Vector2(0, -H - 18), Color(0.6, 0.62, 0.66), 1.0)
	# how much it's holding back
	var n := held()
	if n > 0:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-side * 30 - 6, -26), "%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, brass)
