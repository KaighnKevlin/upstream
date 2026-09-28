extends Node2D
## Gauss cannon: a short level rail with a magnet and a row of steel balls
## in it. A piece rolling into the row's near end is snatched by the magnet
## and stops dead; its momentum runs through the balls and kicks the piece
## waiting at the far end out, faster than the one that came in (the magnet
## adds its pull). Then the arrival is passed along to wait for the next.
## A gentle roll in, a fast shot out, toward `side`. The first piece in only
## loads it. Iron is snatched harder than copper and comes out faster.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const LEN := 44.0
const BOOST := 170.0             # the magnet's pull, added
const GAIN := 1.4
const V_MAX := 900.0

@export var side := 1.0

var fired := 0                   # tests
var last_speed := 0.0
var _loaded: RigidBody2D = null
var _pass: RigidBody2D = null
var _pass_t := 0.0
var _cool := {}


func _ready() -> void:
	# the rail, magnet and balls: one sprite, drawn firing to +x (ghosts too)
	var art := Sprite2D.new()
	art.texture = preload("res://assets/sprites/gauss.png")
	art.centered = false
	art.offset = Vector2(-40, -16)
	art.scale = Vector2(side, 1)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)


func _near() -> Vector2:
	return Vector2(-side * (LEN * 0.5 + 6), -7)


func _far() -> Vector2:
	return Vector2(side * (LEN * 0.5 + 6), -7)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not is_instance_valid(_pass):
		for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
			if not is_instance_valid(o) or o == _loaded or o.freeze or _cool.get(o.get_instance_id(), 0.0) > now:
				continue
			var p: Vector2 = o.global_position - (global_position + _near())
			if absf(p.x) < 9 and absf(p.y) < 10 and o.linear_velocity.x * side > 10:
				_arrive(o, now)
				break
	if is_instance_valid(_pass):
		_pass_t += delta
		var f := clampf(_pass_t / 0.5, 0.0, 1.0)
		var at := global_position + _near().lerp(_far(), f)
		_pass.linear_velocity = (at - _pass.global_position) / delta
		if f >= 1.0:
			_loaded = _pass
			_pass = null
	if is_instance_valid(_loaded):
		_loaded.linear_velocity = (global_position + _far() - _loaded.global_position) / delta
		if "_timer" in _loaded:
			_loaded._timer = 0.0
	queue_redraw()


func _arrive(o: RigidBody2D, now: float) -> void:
	var v_in: float = absf(o.linear_velocity.x)
	o.gravity_scale = 0.0
	if is_instance_valid(_loaded):
		var pull := BOOST * (1.4 if o.get("kind") in ["iron", "shot", "gear", "spring", "scrap"] else 1.0)
		var v := minf(V_MAX, v_in * GAIN + pull)
		_loaded.gravity_scale = 1.0
		_loaded.linear_velocity = Vector2(side * v, -20)
		_cool[_loaded.get_instance_id()] = now + 1.0
		last_speed = v
		fired += 1
		FX.burst(get_parent(), _loaded.global_position, Color(0.7, 0.85, 1.0), 6, 90.0, 0.2, 1.0)
		SFX.play_small(self, SFX.sfx_magnet(), -8.0, 1.5)
		_loaded = null
	_pass = o
	_pass_t = 0.0
