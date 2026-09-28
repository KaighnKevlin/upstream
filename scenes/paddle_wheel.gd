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


func _ready() -> void:
	z_index = 2
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
	var dark := Color(0.16, 0.12, 0.08)
	var wood := Color(0.55, 0.4, 0.22)
	draw_line(Vector2(0, 0), Vector2(-10, R + 16), dark, 3.0)
	draw_line(Vector2(0, 0), Vector2(10, R + 16), dark, 3.0)
	for k in 8:
		var a := _angle + k * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(d * 4.0, d * R, dark, 2.0)
		draw_line(d * (R - 8), d * R, wood, 5.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.65, 0.35))
	var p := power()
	if p > 0.01:
		draw_arc(Vector2.ZERO, R + 4, -PI * 0.5, -PI * 0.5 + TAU * p, 24, Color(1.0, 0.8, 0.35, 0.8), 2.0)
