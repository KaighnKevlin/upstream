extends Node2D
## Kicker: a spring piston set over a chute, punching pieces down through
## the rail and out of the line (they fall clear below it, nudged toward
## `side`). In a filter mode it
## kicks every passing piece of one kind (iron / copper / scrap), a sorter
## you can drop anywhere on a run; in trigger mode it kicks whatever is in
## front of it when something fires it (a tally wheel, load cell, plate).
## Click to cycle. Put its node just over the chute.

const SFX = preload("res://scripts/sfx.gd")
const MODES := ["trigger", "iron", "copper", "scrap"]
const PUNCH := Vector2(90, 160)
const ORE_ONLY := 64
const THROUGH := 0.35            # s the punched piece passes through track
const RELOAD := 0.3

@export var mode := 1
@export var side := 1.0

var kicked := 0                  # tests
var _area: Area2D
var _cool := 0.0
var _stroke := 0.0
var _hit := {}


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	cs.shape = r
	cs.position = Vector2(0, 2)
	_area.add_child(cs)
	add_child(_area)


func _punch(b: RigidBody2D) -> void:
	b.sleeping = false
	b.linear_velocity = Vector2(PUNCH.x * side, PUNCH.y)
	# through the rail: it ignores track for a moment and drops out underneath
	b.collision_mask &= ~ORE_ONLY
	get_tree().create_timer(THROUGH).timeout.connect(func():
		if is_instance_valid(b):
			b.collision_mask |= ORE_ONLY)
	_hit[b.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + 1.0
	kicked += 1
	_stroke = 1.0
	_cool = RELOAD
	SFX.play_small(self, SFX.sfx_bumper(), -12.0, 1.4)


func trigger() -> void:
	if _area == null or _cool > 0:
		return
	for b in _area.get_overlapping_bodies():
		if b is RigidBody2D:
			_punch(b)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	_cool -= delta
	_stroke = maxf(0.0, _stroke - delta * 5.0)
	if mode > 0 and _cool <= 0:
		var now := Time.get_ticks_msec() / 1000.0
		for b in _area.get_overlapping_bodies():
			if b is RigidBody2D and b.get("kind") == MODES[mode] and _hit.get(b.get_instance_id(), 0.0) < now:
				_punch(b)
				break
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(-side * 16, 0)) < 10:
		mode = (mode + 1) % MODES.size()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the cylinder behind the line, the rod and the punch plate
	var back := Vector2(-side * 20, 4)
	draw_rect(Rect2(back + Vector2(-5, -5), Vector2(10, 10)), dark)
	draw_rect(Rect2(back + Vector2(-4, -4), Vector2(8, 8)), Color(0.42, 0.44, 0.5))
	var plate := Vector2(-side * (9 - _stroke * 10), 4)
	draw_line(back, plate, Color(0.7, 0.72, 0.76), 2.0)
	draw_line(plate + Vector2(0, -6), plate + Vector2(0, 6), dark, 4.0)
	draw_line(plate + Vector2(0, -6), plate + Vector2(0, 6), brass, 2.0)
	var col: Color = {"trigger": Color(0.9, 0.8, 0.55), "iron": Color(0.62, 0.64, 0.7), "copper": Color(0.85, 0.5, 0.3), "scrap": Color(0.6, 0.5, 0.4)}[MODES[mode]]
	draw_circle(back + Vector2(0, -10), 3.0, dark)
	draw_circle(back + Vector2(0, -10), 2.0, col)
