extends Node2D
## Flywheel: a heavy iron disc on a frame, belted to the machines around it
## like a gravity wheel. It stores power: while a gravity wheel in reach is
## running at full power it spins up on the surplus, and when the feed dries
## up it keeps the machines it reaches running, slowing as they draw on it
## (the more machines, the faster it runs down). The accumulator of the
## marble machine: smooths a bursty feed into steady power.

const Power = preload("res://scripts/power.gd")
const CHARGE := 0.12             # spin gained per second off a full-power wheel
const IDLE := 0.008              # lost per second, bearing drag
const PER_USER := 0.012          # lost per second per machine drawing on it

var spin := 0.0                  # 0..1: stored energy
var _angle := 0.0
var _scan := 0.0
var _users := 0
var _feeding := false


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


## As a power source: full until it's run down to a third, then fading.
func power() -> float:
	return clampf(spin * 1.5, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_scan -= delta
	if _scan <= 0:
		_scan = 0.25
		_feeding = false
		for w in get_tree().get_nodes_in_group("power_wheels"):
			if w != self and is_instance_valid(w) and not w.has_method("_is_flywheel") \
					and w.global_position.distance_to(global_position) <= Power.REACH and w.power() >= 0.95:
				_feeding = true
		_users = 0
		for u in get_tree().get_nodes_in_group("power_users"):
			if is_instance_valid(u) and u.global_position.distance_to(global_position) <= Power.REACH:
				_users += 1
	if _feeding:
		spin = minf(1.0, spin + CHARGE * delta)
	else:
		spin = maxf(0.0, spin - (IDLE + PER_USER * _users) * delta)
	_angle += spin * 9.0 * delta
	queue_redraw()


func _is_flywheel() -> bool:
	return true


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	# the frame
	draw_line(Vector2(0, 0), Vector2(-14, 30), Color(0.16, 0.13, 0.1), 3.0)
	draw_line(Vector2(0, 0), Vector2(14, 30), Color(0.16, 0.13, 0.1), 3.0)
	draw_line(Vector2(-18, 30), Vector2(18, 30), Color(0.16, 0.13, 0.1), 3.0)
	# the disc: a heavy rim and spokes, spinning with what it's storing
	draw_circle(Vector2.ZERO, 20.0, dark)
	draw_circle(Vector2.ZERO, 18.0, Color(0.36, 0.38, 0.42))
	draw_circle(Vector2.ZERO, 13.0, Color(0.22, 0.23, 0.26))
	for k in 5:
		var a := _angle + k * TAU / 5.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 13.0, Color(0.5, 0.52, 0.56), 2.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.65, 0.35))
	# the charge, as a brass arc round the rim
	if spin > 0.01:
		draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * spin, 32, Color(1.0, 0.8, 0.35, 0.85), 2.0)
