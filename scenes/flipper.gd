extends Node2D
## Flipper: a pinball paddle on a pivot. It rests down, a shallow ramp that
## pieces roll onto and sit at the pivot end of; fired (by a trigger, a
## tally wheel, a plate, a bell, or a click) it snaps up and bats whatever
## is on it high and away toward `side`. Batting on a signal: every tenth
## ore flipped over the wall, the stack flung when a walker steps on the plate.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const LEN := 40.0
const REST := 0.35               # rad down (toward the pivot, so pieces settle there)
const UP := -0.5
const BAT := 720.0

@export var side := 1.0          # the free end, and the way it bats

var flips := 0                   # tests
var batted := 0
var _shape: CollisionShape2D
var _area: Area2D
var _angle := REST
var _up_t := 0.0
var _base: Sprite2D              # stand and stop post, mirrored for side -1
var _paddle: Sprite2D            # turns about the pivot, mirrored for side -1


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too
	_base = Sprite2D.new()
	_base.texture = preload("res://assets/sprites/flipper_base.png")
	_base.centered = false
	_base.offset = Vector2(-10, -14)
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.show_behind_parent = true
	add_child(_base)
	_paddle = Sprite2D.new()
	_paddle.texture = preload("res://assets/sprites/flipper_paddle.png")
	_paddle.centered = false
	_paddle.offset = Vector2(-6, -7)
	_paddle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paddle.show_behind_parent = true
	add_child(_paddle)
	_pose()
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	m.bounce = 0.5
	m.friction = 1.0
	body.physics_material_override = m
	_shape = CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = Vector2.ZERO
	s.b = Vector2(side * LEN, 0)
	_shape.shape = s
	body.add_child(_shape)
	# a stop behind the pivot: what rolls down sits there
	var stop := CollisionShape2D.new()
	var ss := SegmentShape2D.new()
	ss.a = Vector2(-side * 3, 0)
	ss.b = Vector2(-side * 3, -12)
	stop.shape = ss
	body.add_child(stop)
	add_child(body)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(LEN, 16)
	cs.shape = r
	cs.position = Vector2(side * LEN * 0.5, -8)
	_area.add_child(cs)
	add_child(_area)
	_apply()


func _apply() -> void:
	# the free end drops toward the pivot at rest (rotation is about the pivot)
	_shape.rotation = -_angle * side
	_area.rotation = -_angle * side


func _pose() -> void:
	var s := 1.0 if side >= 0 else -1.0
	_base.scale.x = s
	_paddle.scale.x = s
	_paddle.rotation = -_angle * side


func trigger() -> void:
	if _up_t > 0:
		return
	flips += 1
	_up_t = 0.25
	_angle = UP
	_apply()
	var out := Vector2(side * 0.55, -1.0).normalized() * BAT
	for b in _area.get_overlapping_bodies():
		if b is RigidBody2D:
			b.sleeping = false
			b.linear_velocity = out
			batted += 1
	SFX.play_small(self, SFX.sfx_bumper(), -8.0, 1.2)


func _physics_process(delta: float) -> void:
	if _shape == null:
		return
	if _up_t > 0:
		_up_t -= delta
		if _up_t <= 0:
			_angle = REST
			_apply()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(side * LEN * 0.5, 0)) < 16:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_pose()                      # paddle, pivot, stand and stop post are sprites (see _ready)
