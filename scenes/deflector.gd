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
var _plate: Sprite2D


func _ready() -> void:
	z_index = 1
	# post and plate sprites (ghosts too); _draw turns and flashes the plate
	var post := Sprite2D.new()
	post.texture = preload("res://assets/sprites/deflector_post.png")
	post.centered = false
	post.offset = Vector2(-8, -2)
	post.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(post)
	_plate = Sprite2D.new()
	_plate.texture = preload("res://assets/sprites/deflector_plate.png")
	_plate.centered = false
	_plate.offset = Vector2(-25, -4)
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_plate)
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
	# the post and plate are sprites (see _ready): set the plate's tilt, and
	# light it up for a moment when it's struck
	if _plate:
		_plate.rotation = deg_to_rad(angle_deg)
		_plate.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.5), _flash)
