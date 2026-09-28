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
var _plate: Sprite2D
var _body: Sprite2D


func _ready() -> void:
	z_index = 2
	# sprites (ghosts too), both under our _draw (the mode lamp); the
	# cylinder over the punch's rod, which slides out of it
	_plate = _sprite(preload("res://assets/sprites/kicker_plate.png"), Vector2(-24, -8))
	_body = _sprite(preload("res://assets/sprites/kicker_body.png"), Vector2(-30, -11))
	_place_art()
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


func _sprite(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


## Drawn punching right (side +1); mirrored for -1.
func _place_art() -> void:
	var s := 1.0 if side >= 0 else -1.0
	_body.scale = Vector2(s, 1)
	_plate.scale = Vector2(s, 1)
	_plate.position = Vector2(-side * (9 - _stroke * 10), 4)


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
	_place_art()
	# the mode lamp, lit in its bezel
	var back := Vector2(-side * 20, 4)
	var col: Color = {"trigger": Color(0.9, 0.8, 0.55), "iron": Color(0.62, 0.64, 0.7), "copper": Color(0.85, 0.5, 0.3), "scrap": Color(0.6, 0.5, 0.4)}[MODES[mode]]
	draw_circle(back + Vector2(0, -10), 2.0, col)
