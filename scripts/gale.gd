extends Node2D
## A gale (a random event; F3 in sandbox): for DURATION seconds a strong
## wind blows across the surface. Every loose piece in the air above ground
## is pushed downwind (so bounces, lobs and turret shots all drift: covered
## runs, chutes and tubes don't care), fliers are buffeted and the birds
## stay down in the grass. The wind swells and slackens in gusts; streaks
## of it tear across the view.

const WorldGen = preload("res://scripts/world_gen.gd")

const DURATION := 25.0
const PUSH := 420.0              # px/s^2 at full gust
const FLIER_PUSH := 40.0

var direction := 1.0             # +1 blows right, -1 left
var pushed := 0                  # tests: piece-frames pushed
var _t := 0.0
var _streaks := []               # [position, length, speed]
var _ramp := 0.0


func _ready() -> void:
	z_index = 6
	direction = [-1.0, 1.0].pick_random()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # streaks show at night too
	material = mat
	for k in 60:
		_streaks.append([Vector2(randf_range(-700, 700), randf_range(-400, 300)), randf_range(30, 80), randf_range(0.8, 1.3)])


## 0..1: ramps in and out, and gusts in between.
func strength() -> float:
	var ramp := clampf(_t / 3.0, 0.0, 1.0) * clampf((DURATION - _t) / 3.0, 0.0, 1.0)
	return ramp * (0.65 + 0.35 * sin(_t * 1.7) * sin(_t * 0.6 + 1.0))


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	var k := strength()
	var ground := float(WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE)
	for group in ["ore", "ingots"]:
		for o in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(o) or o.freeze or o.sleeping or o.has_meta("store_material") or o.has_meta("caught_by"):
				continue
			if o.global_position.y > ground - 4:
				continue          # under cover: in the ground, down a shaft
			o.linear_velocity.x += direction * PUSH * k * delta / sqrt(maxf(o.mass, 0.3))
			pushed += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and "velocity" in e and not (e is CharacterBody2D) and not (e is RigidBody2D) and e.global_position.y < ground:
			e.velocity.x += direction * FLIER_PUSH * k * delta
	queue_redraw()


func _process(delta: float) -> void:
	var k := strength()
	for s in _streaks:
		s[0].x += direction * 900.0 * s[2] * (0.4 + k) * delta
		if s[0].x > 760:
			s[0] = Vector2(-760, randf_range(-400, 300))
		elif s[0].x < -760:
			s[0] = Vector2(760, randf_range(-400, 300))


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var at := to_local(cam.get_screen_center_position())
	var k := strength()
	for s in _streaks:
		var p: Vector2 = at + s[0] / cam.zoom.x
		draw_line(p, p - Vector2(direction * s[1] * (0.5 + k), 0), Color(0.88, 0.9, 0.92, 0.42 * k), 1.0)
