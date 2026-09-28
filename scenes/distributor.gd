extends Node2D
## Rotary distributor: a hopper over a turning spout with three outlets,
## left, down and right. Each piece that drops in is sent out of the next
## outlet in turn, round and round: a three-way splitter (the flip-flop
## only does two), for feeding three machines evenly off one stream.
## Click it to skip an outlet (turn it on a step by hand).

const SFX = preload("res://scripts/sfx.gd")
const OUTS := [Vector2(-150, -60), Vector2(0, 80), Vector2(150, -60)]   # launch velocities
const SPOUT := [Vector2(-10, 10), Vector2(0, 14), Vector2(10, 10)]

var turn := 0
var sent := [0, 0, 0]            # tests
var _cool := {}
var _angle := 0.0
var _spout: Sprite2D             # turns on its pivot, (0, -2)


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw (the outlet lamps)
	var bd := Sprite2D.new()
	bd.texture = preload("res://assets/sprites/distributor_body.png")
	bd.centered = false
	bd.offset = Vector2(-20, -24)
	bd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bd.show_behind_parent = true
	add_child(bd)
	_spout = Sprite2D.new()
	_spout.texture = preload("res://assets/sprites/distributor_spout.png")
	_spout.centered = false
	_spout.offset = Vector2(-6, -5)
	_spout.position = Vector2(0, -2)
	_spout.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spout.show_behind_parent = true
	add_child(_spout)
	if has_meta("ghost"):
		return
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 16)
	cs.shape = r
	cs.position = Vector2(0, -6)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_take)


func _take(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _cool.get(b.get_instance_id(), 0.0) > now:
		return
	_cool[b.get_instance_id()] = now + 1.0
	var k := turn
	b.global_position = global_position + SPOUT[k]
	b.linear_velocity = OUTS[k]
	sent[k] += 1
	turn = (turn + 1) % 3
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 0.9 + k * 0.15)
	queue_redraw()


func _process(delta: float) -> void:
	var want := (turn - 1) * PI * 0.5 * 0.7
	_angle = lerp_angle(_angle, want, minf(1.0, delta * 12.0))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 16:
		turn = (turn + 1) % 3
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# hopper, housing and spout are sprites (see _ready); the spout points
	# along (sin, cos) of _angle
	_spout.rotation = -_angle
	# the three outlets, next one lit
	for k in 3:
		var p: Vector2 = SPOUT[k] * 1.6
		draw_circle(p, 2.5, Color(1.0, 0.8, 0.4) if k == turn else Color(0.35, 0.3, 0.25))
