extends Node2D
## Treadwheel: a big wooden wheel the prospector walks inside, like a
## medieval crane. Stand in it and walk (either way) and it turns, driving
## the machines in reach over belts like a gravity wheel: power by hand for
## before there's ore to spare, or when the feed runs dry. Stop walking and
## it coasts down. Jump to get out.

const R := 34.0
const SPIN_UP := 0.9             # power gained per second of walking
const COAST := 0.35              # lost per second when not

var level := 0.0                 # 0..1
var _angle := 0.0
var walked := 0.0                # tests: seconds walked in it


func _ready() -> void:
	z_index = 0                      # (behind the cave backdrop at -1)
	process_physics_priority = 10    # after the player moves, so it can hold them in place
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func power() -> float:
	return level


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var walking := false
	var pl := get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if pl and pl.global_position.distance_to(global_position + Vector2(0, R * 0.4)) < R and absf(pl.velocity.x) > 20.0 and pl.is_on_floor():   # jump to get out
		walking = true
		# the floor turns under your feet: you walk in place
		pl.global_position.x = global_position.x + clampf(pl.global_position.x - global_position.x, -3.0, 3.0)
		_angle += signf(pl.velocity.x) * delta * 2.2
		walked += delta
	if walking:
		level = minf(1.0, level + SPIN_UP * delta)
	else:
		level = maxf(0.0, level - COAST * delta)
		_angle += level * delta * 2.0
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.16, 0.12, 0.08)
	var wood := Color(0.55, 0.4, 0.22)
	# the frame on the ground
	draw_line(Vector2(0, 0), Vector2(-20, R + 6), dark, 4.0)
	draw_line(Vector2(0, 0), Vector2(20, R + 6), dark, 4.0)
	# the wheel: two rims, rungs between them (the tread), spokes
	for k in 12:
		var a := _angle + k * TAU / 12.0
		var d := Vector2(cos(a), sin(a))
		draw_line(Vector2.ZERO, d * R, Color(dark, 0.7), 2.0)
		draw_line(d * (R - 3), d * (R + 3), wood.lightened(0.15), 3.0)
	draw_arc(Vector2.ZERO, R + 3, 0, TAU, 40, dark, 3.0)
	draw_arc(Vector2.ZERO, R - 3, 0, TAU, 40, wood, 2.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.65, 0.35))
	if level > 0.01:
		draw_arc(Vector2.ZERO, R + 7, -PI * 0.5, -PI * 0.5 + TAU * level, 32, Color(1.0, 0.8, 0.35, 0.8), 2.0)
