extends Node2D

## Direction ore is launched after bouncing, in degrees (0 = straight up).
@export_range(-80, 80, 1) var bounce_angle: float = 0.0

## Force multiplier applied on bounce.
@export_range(100, 2000, 10) var bounce_force: float = 700.0

@onready var _area: Area2D = $Area2D
@onready var _arrow: Polygon2D = $Arrow
@onready var _sprite: Polygon2D = $Sprite
@onready var _angle_handle: Polygon2D = $AngleHandle
@onready var _force_handle: Polygon2D = $ForceHandle
@onready var _force_line: Polygon2D = $ForceLine

enum DragMode { NONE, BODY, ANGLE, FORCE }
var _selected := false
var _drag_mode: DragMode = DragMode.NONE
var _drag_offset := Vector2.ZERO

const COLOR_NORMAL := Color(0.2, 0.85, 0.3, 1)
const COLOR_SELECTED := Color(0.4, 1.0, 0.5, 1)
const ANGLE_HANDLE_DIST := 45.0
const FORCE_MIN_DIST := 65.0
const FORCE_MAX_DIST := 120.0
const HANDLE_GRAB_RADIUS := 14.0


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_hide_handles()
	_update_visuals()


func _on_body_entered(body: Node2D) -> void:
	var angle_rad := deg_to_rad(bounce_angle - 90)
	var direction := Vector2(cos(angle_rad), sin(angle_rad))

	# Blend: reflect incoming momentum along trampoline normal + add boost
	# Result feels like a real bounce — entry angle matters
	if body is RigidBody2D:
		var incoming: Vector2 = body.linear_velocity
		var along_tramp: float = incoming.dot(direction)
		# Keep momentum perpendicular to launch dir, replace component along launch dir
		var perpendicular: Vector2 = incoming - direction * along_tramp
		var new_vel: Vector2 = direction * bounce_force + perpendicular * 0.4
		body.linear_velocity = new_vel
	elif body is CharacterBody2D and body.has_method("launch"):
		var incoming: Vector2 = body.velocity
		var along_tramp: float = incoming.dot(direction)
		var perpendicular: Vector2 = incoming - direction * along_tramp
		var new_vel: Vector2 = direction * bounce_force + perpendicular * 0.4
		body.launch(new_vel)


func _launch_dir() -> Vector2:
	var angle_rad := deg_to_rad(bounce_angle - 90)
	return Vector2(cos(angle_rad), sin(angle_rad))


func _angle_handle_global() -> Vector2:
	return global_position + _launch_dir() * ANGLE_HANDLE_DIST


func _force_handle_global() -> Vector2:
	var dist := remap(bounce_force, 100, 2000, FORCE_MIN_DIST, FORCE_MAX_DIST)
	return global_position + _launch_dir() * dist


func _mouse_near(point: Vector2) -> bool:
	return get_global_mouse_position().distance_to(point) < HANDLE_GRAB_RADIUS


func _mouse_over_body() -> bool:
	var mouse := get_global_mouse_position()
	return absf(mouse.x - global_position.x) < 45 and absf(mouse.y - global_position.y) < 12


func select() -> void:
	_selected = true
	_sprite.color = COLOR_SELECTED
	_show_handles()
	_update_visuals()


func deselect() -> void:
	_selected = false
	_drag_mode = DragMode.NONE
	_sprite.color = COLOR_NORMAL
	_hide_handles()


func _input(event: InputEvent) -> void:
	# Escape always deselects
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _selected:
			deselect()
			return

	# Skip if in build mode
	if BuildSystem.current_build != BuildSystem.BuildType.NONE:
		if _selected:
			deselect()
		return

	# Mouse button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# If selected, check handle clicks first
			if _selected:
				if _mouse_near(_angle_handle_global()):
					_drag_mode = DragMode.ANGLE
					get_viewport().set_input_as_handled()
					return
				if _mouse_near(_force_handle_global()):
					_drag_mode = DragMode.FORCE
					get_viewport().set_input_as_handled()
					return
				# Clicking the body while selected = start dragging body
				if _mouse_over_body():
					_drag_mode = DragMode.BODY
					_drag_offset = global_position - get_global_mouse_position()
					get_viewport().set_input_as_handled()
					return
				# Clicked elsewhere — deselect
				deselect()
			else:
				# Not selected — click to select
				if _mouse_over_body():
					select()
					get_viewport().set_input_as_handled()
		else:
			# Mouse released — stop dragging
			_drag_mode = DragMode.NONE

	# Mouse motion — handle dragging
	if event is InputEventMouseMotion and _drag_mode != DragMode.NONE:
		var mouse := get_global_mouse_position()
		match _drag_mode:
			DragMode.BODY:
				global_position = mouse + _drag_offset
			DragMode.ANGLE:
				var dir := (mouse - global_position)
				if dir.length() > 5:
					var raw_angle := rad_to_deg(dir.angle() + PI / 2)
					bounce_angle = clampf(raw_angle, -80, 80)
			DragMode.FORCE:
				var dist := mouse.distance_to(global_position)
				bounce_force = clampf(
					remap(dist, FORCE_MIN_DIST, FORCE_MAX_DIST, 100.0, 2000.0),
					100, 2000)
		_update_visuals()
		get_viewport().set_input_as_handled()


func _show_handles() -> void:
	_angle_handle.visible = true
	_force_handle.visible = true
	_force_line.visible = true


func _hide_handles() -> void:
	_angle_handle.visible = false
	_force_handle.visible = false
	_force_line.visible = false


func _update_visuals() -> void:
	# Tilt the platform perpendicular to launch direction
	_sprite.rotation = deg_to_rad(bounce_angle)

	var dir := _launch_dir()
	var perp := dir.rotated(PI / 2)

	# Arrow
	var tip := dir * 30.0
	_arrow.polygon = PackedVector2Array([
		tip,
		tip - dir * 12 + perp * 6,
		tip - dir * 12 - perp * 6,
	])

	# Angle handle position
	_angle_handle.position = dir * ANGLE_HANDLE_DIST

	# Force handle position
	var force_dist := remap(bounce_force, 100, 2000, FORCE_MIN_DIST, FORCE_MAX_DIST)
	_force_handle.position = dir * force_dist

	# Line connecting them
	var line_start := dir * (ANGLE_HANDLE_DIST + 10)
	var line_end := dir * (force_dist - 10)
	if line_start.distance_to(line_end) > 5:
		_force_line.polygon = PackedVector2Array([
			line_start - perp * 1, line_end - perp * 1,
			line_end + perp * 1, line_start + perp * 1,
		])
	else:
		_force_line.polygon = PackedVector2Array()
