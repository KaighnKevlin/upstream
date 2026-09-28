extends Node2D
## Deflector: a springy steel plate on a post, set at an angle (click: turn
## it 15 degrees). Ore flying into it ricochets off with most of its speed,
## like a pinball rebound, so a trampoline's or catapult's shot can be
## banked round a corner or knocked down into a funnel. Heavy ore and light
## ore come off a trampoline on different arcs, so one plate in the right
## place catches one and misses the other.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const HALF := 22.0
const STEP := 15

@export var angle_deg := -45     # the plate's tilt: 0 flat, -45 like "/", 45 like "\" (y is down)

var hits := 0                    # tests
var _body: StaticBody2D
var _shape: CollisionShape2D
var _flash := 0.0


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.bounce = 0.85
	m.friction = 0.1
	_body.physics_material_override = m
	_shape = CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = Vector2(-HALF, 0)
	s.b = Vector2(HALF, 0)
	_shape.shape = s
	_body.add_child(_shape)
	add_child(_body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2, 14)
	ac.shape = r
	a.add_child(ac)
	_body.add_child(a)
	a.body_entered.connect(_hit)
	_apply()


func _hit(b) -> void:
	if not (b is RigidBody2D):
		return
	hits += 1
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 1.2)


func _apply() -> void:
	if _body:
		_body.rotation = deg_to_rad(angle_deg)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < HALF:
		angle_deg += STEP
		if angle_deg > 75:
			angle_deg = -75
		_apply()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	# the post
	draw_line(Vector2.ZERO, Vector2(0, 26), Color(0.16, 0.13, 0.1), 3.0)
	draw_line(Vector2(-6, 26), Vector2(6, 26), Color(0.16, 0.13, 0.1), 3.0)
	var d := Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg))) * HALF
	draw_line(-d, d, dark, 6.0)
	draw_line(-d, d, Color(0.72, 0.74, 0.78).lerp(Color(1, 1, 0.85), _flash), 3.0)
	draw_line(-d * 0.9 + d.orthogonal().normalized() * -1.5, d * 0.9 + d.orthogonal().normalized() * -1.5, Color(1, 1, 1, 0.3), 1.0)
	draw_circle(Vector2.ZERO, 3.0, dark)
	draw_circle(Vector2.ZERO, 2.0, Color(0.85, 0.65, 0.35))
