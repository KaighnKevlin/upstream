extends Node2D
## Spinner: a four-bladed vane hung low over a track, the pinball kind.
## Every piece rolling under it flicks a blade and spins it up, and gives a
## little of its speed for it. While it turns it powers machines in reach
## like a gravity wheel: a steady line (about one a second at a good roll)
## runs it flat out, and it winds down a few seconds after the line stops.
## Put it in a marble run and the run drives its own sling or lift.

const R := 12.0                  # blade length, px
const RATED := 14.0              # rad/s = full power
const KICK := 0.022              # rad/s per (px/s of the piece) per pass
const TAKE := 0.88               # of its speed the piece keeps

var omega := 0.0
var passes := 0                  # tests
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
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 6 and p.y > -4 and p.y < R + 8 and absf(o.linear_velocity.x) > 30 and _seen.get(o.get_instance_id(), 0.0) < now:
			_seen[o.get_instance_id()] = now + 0.4
			omega += absf(o.linear_velocity.x) * KICK
			o.linear_velocity *= TAKE
			passes += 1
	omega = maxf(0.0, omega - (0.6 + omega * 0.3) * delta)
	_angle += omega * delta
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var iron := Color(0.42, 0.44, 0.5)
	# the bracket it hangs from
	draw_line(Vector2(-7, -18), Vector2(0, 0), dark, 3.0)
	draw_line(Vector2(7, -18), Vector2(0, 0), dark, 3.0)
	draw_line(Vector2(-7, -18), Vector2(0, 0), iron, 1.0)
	draw_line(Vector2(7, -18), Vector2(0, 0), iron, 1.0)
	draw_line(Vector2(-9, -18), Vector2(9, -18), iron, 2.0)
	# the blades, blurred to a disc when it's fast
	var blur := clampf(omega / RATED, 0.0, 1.0)
	if blur > 0.3:
		draw_circle(Vector2.ZERO, R, Color(0.85, 0.65, 0.35, 0.15 * blur))
	for i in 4:
		var d := Vector2.RIGHT.rotated(_angle + i * PI * 0.5)
		draw_line(Vector2.ZERO, d * R, dark, 4.0)
		draw_line(Vector2.ZERO, d * R, brass.lerp(Color(1, 0.95, 0.7), blur), 2.0)
	draw_circle(Vector2.ZERO, 3.0, dark)
	draw_circle(Vector2.ZERO, 2.0, brass)
	# a little power gauge on the bracket
	draw_rect(Rect2(-6, -24, 12, 3), dark)
	draw_rect(Rect2(-5, -23, 10 * blur, 1), Color(1.0, 0.85, 0.5))
