extends Node2D
## Bellows fan: blows a stream of air where it's aimed. Ore in the stream is
## pulled toward the wind's velocity, so a fan bends shots in flight, carries
## ore across a gap, or, aimed up and strong enough to beat gravity, holds a
## column of ore floating in its updraft. Fliers get shoved too: a fan by
## the works makes magpies struggle.
## Aim: click it, drag the handle (direction = aim, distance = wind speed);
## the streaks show the stream's reach.
## Art: tools/art/gen_bellows.py (4 frames, nozzle pointing right).

const WIND_MIN := 120.0
const WIND_MAX := 520.0
const DRAG := 4.0              # how hard the air grips ore (1/s)
const FLIER_DRAG := 1.2
const WIDTH := 26.0
const NOZZLE := 22.0           # mouth distance from the pivot
const HANDLE_MIN := 24.0
const HANDLE_MAX := 110.0
const POST_MAX := 220.0

## Aim in degrees (0 = straight up, positive = right), and wind speed.
@export_range(-180, 180, 1) var aim_angle: float = 70.0
@export_range(120, 520, 5) var wind_speed: float = 320.0

var _spr: AnimatedSprite2D
var _area: Area2D
var _shape: RectangleShape2D
var _handle: Polygon2D
var _selected := false
var _dragging := false
var _streaks := []             # [distance along the stream, sideways offset]


func _aim_dir() -> Vector2:
	var a := deg_to_rad(aim_angle)
	return Vector2(sin(a), -cos(a))


func reach() -> float:
	return 50.0 + wind_speed * 0.4


func _ready() -> void:
	z_index = 1
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/bellows.png")
	sf.set_animation_speed("default", 10.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 36, 0, 36, 24)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-12, -12)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play()
	add_child(_spr)
	for k in 12:
		_streaks.append([randf() * 200.0, randf_range(-1, 1)])
	if has_meta("ghost"):
		_apply_aim()
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2   # ore, ingots
	var cs := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	cs.shape = _shape
	_area.add_child(cs)
	add_child(_area)
	_handle = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(Vector2.from_angle(k * TAU / 12) * 5)
	_handle.polygon = pts
	_handle.color = Color(1.0, 0.7, 0.2)
	_handle.visible = false
	_handle.z_index = 21
	add_child(_handle)
	_apply_aim()
	_build_post()


func _apply_aim() -> void:
	var dir := _aim_dir()
	_spr.rotation = dir.angle()
	_spr.flip_v = dir.x < 0   # keep the crank on top when blowing left
	if _shape:
		_shape.size = Vector2(reach(), WIDTH)
		var cs := _area.get_child(0) as CollisionShape2D
		cs.position = dir * (NOZZLE + reach() / 2)
		cs.rotation = dir.angle()
	if _handle:
		_handle.position = dir * remap(wind_speed, WIND_MIN, WIND_MAX, HANDLE_MIN, HANDLE_MAX)
	_spr.speed_scale = wind_speed / 300.0
	queue_redraw()


## Wind at a point (its strength falls off along the stream).
func wind_at(p: Vector2) -> Vector2:
	var dir := _aim_dir()
	var along := (p - global_position).dot(dir) - NOZZLE
	var k := clampf(1.0 - along / reach() * 0.7, 0.3, 1.0)
	return dir * wind_speed * k


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	for body in _area.get_overlapping_bodies():
		var b := body as RigidBody2D
		if b == null or b.freeze or b.has_meta("caught_by") or b.has_meta("store_material"):
			continue
		var w := wind_at(b.global_position)
		b.linear_velocity += (w - b.linear_velocity) * minf(1.0, DRAG / maxf(b.mass, 0.1) * delta)  # iron hardly lifts
		b.sleeping = false
		if "_timer" in b:
			b._timer = 0.0   # kept aloft: still in play
	# fliers (magpies) get shoved about
	for e in get_tree().get_nodes_in_group("enemies"):
		if not ("velocity" in e) or not e.has_method("hit_center") or e is CharacterBody2D:
			continue
		if _in_stream(e.global_position):
			e.velocity += (wind_at(e.global_position) - e.velocity) * minf(1.0, FLIER_DRAG * delta)


func _in_stream(p: Vector2) -> bool:
	var dir := _aim_dir()
	var rel := p - global_position
	var along := rel.dot(dir) - NOZZLE
	return along > 0 and along < reach() and absf(rel.dot(dir.orthogonal())) < WIDTH / 2


func _process(delta: float) -> void:
	for s in _streaks:
		var along: float = s[0]
		s[0] = along + wind_speed * clampf(1.0 - along / reach() * 0.7, 0.3, 1.0) * delta
		if s[0] > reach():
			s[0] = randf() * 10.0
			s[1] = randf_range(-1, 1)
	queue_redraw()


func _draw() -> void:
	# air streaks: short pale dashes riding the stream, fading along it
	var dir := _aim_dir()
	var side := dir.orthogonal()
	for s in _streaks:
		var along: float = s[0]
		var p: Vector2 = dir * (NOZZLE + along) + side * s[1] * (WIDTH / 2 - 2) * (0.6 + along / reach() * 0.4)
		var a := (1.0 - along / reach()) * (0.55 if not _selected else 0.9)
		draw_line(p, p - dir * 6.0, Color(0.85, 0.95, 1.0, a), 1.0)
	if _selected:
		var r := reach()
		var c := [dir * NOZZLE + side * WIDTH / 2, dir * (NOZZLE + r) + side * WIDTH / 2,
			dir * (NOZZLE + r) - side * WIDTH / 2, dir * NOZZLE - side * WIDTH / 2]
		for k in 4:
			draw_line(c[k], c[(k + 1) % 4], Color(1.0, 0.7, 0.2, 0.35), 1.0)


func _build_post() -> void:
	var space := get_world_2d().direct_space_state
	var top := global_position + Vector2(0, 6)
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(top, top + Vector2(0, POST_MAX), 1))
	if hit.is_empty() or hit.position.y - top.y < 4:
		return
	var leg := Line2D.new()
	leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
	leg.texture = preload("res://assets/sprites/strut.png")
	leg.texture_mode = Line2D.LINE_TEXTURE_TILE
	leg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	leg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leg.width = 5.0
	leg.z_index = -2
	add_child(leg)


# ── aiming UI (as the catapult) ────────────────────────────────────────

func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	_handle.visible = on
	modulate = Color(1.2, 1.15, 1.05) if on else Color.WHITE
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _handle == null:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			_set_selected(false)
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			_set_selected(false)
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _selected and mouse.distance_to(to_global(_handle.position)) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif mouse.distance_to(global_position) < 16:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var v := mouse - global_position
		if v.length() > 4:
			aim_angle = wrapf(rad_to_deg(v.angle() + PI / 2), -180, 180)
			wind_speed = clampf(remap(v.length(), HANDLE_MIN, HANDLE_MAX, WIND_MIN, WIND_MAX), WIND_MIN, WIND_MAX)
			_apply_aim()
		get_viewport().set_input_as_handled()
