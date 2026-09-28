extends Node2D
## Water wheel: an undershot wheel on a frame, set over a flume so its
## lowest paddles dip in the running water. The current turns it, and it
## powers machines in reach like a gravity wheel: steadily, whether or not
## anything's floating by. Out of the water it stands still. Turns the way
## the flume runs. The flume carries on as before (pieces float under it).

const R := 20.0                  # paddle tips
const RATED := 3.0               # rad/s = full power
const SPIN_UP := 1.2

var omega := 0.0
var _angle := 0.0
var _check := 0.0
var _flow := 0.0                 # -1/0/+1: the water under it


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func power() -> float:
	return clampf(absf(omega) / RATED, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_flow = 0.0
		var dip := global_position + Vector2(0, R - 4)
		for f in get_tree().get_nodes_in_group("flumes"):
			if is_instance_valid(f):
				var w: float = f.water_at(dip)
				if w != 0.0:
					_flow = w
					break
	omega = move_toward(omega, _flow * RATED, SPIN_UP * delta)
	_angle += omega * delta
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var wood := Color(0.5, 0.34, 0.2)
	var iron := Color(0.42, 0.44, 0.5)
	# the A-frame it turns on, standing either side of the trough
	for s in [-1.0, 1.0]:
		draw_line(Vector2(0, 0), Vector2(s * 14, R + 6), dark, 4.0)
		draw_line(Vector2(0, 0), Vector2(s * 14, R + 6), wood.darkened(0.2), 2.0)
	# the rim, spokes and paddles
	draw_arc(Vector2.ZERO, R - 5, 0, TAU, 24, dark, 3.0)
	draw_arc(Vector2.ZERO, R - 5, 0, TAU, 24, wood, 1.0)
	for i in 8:
		var d := Vector2.RIGHT.rotated(_angle + i * TAU / 8.0)
		draw_line(Vector2.ZERO, d * (R - 5), dark, 2.0)
		draw_line(Vector2.ZERO, d * (R - 5), wood, 1.0)
		var n := d.orthogonal()
		var a := d * (R - 7)
		var b := d * R
		draw_colored_polygon(PackedVector2Array([a - n * 2, b - n * 2, b + n * 2, a + n * 2]), dark)
		draw_colored_polygon(PackedVector2Array([a - n * 1, b - n * 1, b + n * 1, a + n * 1]), wood.lightened(0.1))
	draw_circle(Vector2.ZERO, 3.5, dark)
	draw_circle(Vector2.ZERO, 2.5, iron)
	# spray where it bites the water
	if absf(omega) > 0.5:
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var x := sin(t * 7.0 + i * 2.1) * 8.0
			draw_circle(Vector2(x, R - 2 - fposmod(t * 20.0 + i * 5.0, 8.0)), 1.0, Color(0.75, 0.88, 1.0, 0.6))
