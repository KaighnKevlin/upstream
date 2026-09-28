extends Node2D
## Paddle wheel: a wheel of flat paddles set in a stream's fall, like a
## mill wheel under a race. Pieces falling through knock the paddles round
## and carry on down, a little slower and nudged aside; the spin drives the
## machines in reach like a gravity wheel. Unlike a gravity wheel it keeps
## nothing: the stream passes through to wherever it was going. Heavier,
## faster, steadier streams turn it harder.

const R := 20.0
const KICK := 0.0013             # spin per (mass x px/s) of a knock
const DRAG := 0.55               # spin lost per second
const RATED := 2.2               # spin for full power

var omega := 0.0
var knocks := 0                  # tests
var _angle := 0.0
var _seen := {}
var _wheel: Sprite2D


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too
	var frame := Sprite2D.new()
	frame.texture = preload("res://assets/sprites/paddle_wheel_frame.png")
	frame.centered = false
	frame.offset = Vector2(-14, -4)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.show_behind_parent = true
	add_child(frame)
	_wheel = Sprite2D.new()
	_wheel.texture = preload("res://assets/sprites/paddle_wheel.png")
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wheel.show_behind_parent = true
	add_child(_wheel)
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func power() -> float:
	return clampf(omega / RATED, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze:
			continue
		var p: Vector2 = o.global_position - global_position
		if p.length() < R + 4 and o.linear_velocity.y > 40 and _seen.get(o.get_instance_id(), 0.0) < now:
			_seen[o.get_instance_id()] = now + 0.5
			var vy: float = o.linear_velocity.y
			omega += o.mass * vy * KICK
			# the paddle takes some of its fall and turns it aside
			o.linear_velocity = Vector2(o.linear_velocity.x + 50.0, vy * 0.7)
			knocks += 1
	omega = maxf(0.0, omega - (DRAG + omega * 0.15) * delta)
	_angle += omega * delta
	queue_redraw()


func _draw() -> void:
	_wheel.rotation = _angle   # the trestle and wheel are sprites (see _ready)
	var p := power()
	if p > 0.01:
		draw_arc(Vector2.ZERO, R + 4, -PI * 0.5, -PI * 0.5 + TAU * p, 24, Color(1.0, 0.8, 0.35, 0.8), 2.0)
