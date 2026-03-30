extends Node2D

## Direction ore is launched after bouncing, in degrees (0 = straight up).
@export_range(-80, 80, 1) var bounce_angle: float = 0.0

## Force multiplier applied on bounce.
@export_range(100, 2000, 10) var bounce_force: float = 700.0

@onready var _area: Area2D = $Area2D
@onready var _arrow: Polygon2D = $Arrow
@onready var _sprite: Polygon2D = $Sprite

var _selected := false
var _dragging := false
var _drag_offset := Vector2.ZERO

const COLOR_NORMAL := Color(0.2, 0.85, 0.3, 1)
const COLOR_SELECTED := Color(0.4, 1.0, 0.5, 1)
const ARROW_LEN := 40.0


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_update_visuals()


func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		var angle_rad := deg_to_rad(bounce_angle - 90)
		var direction := Vector2(cos(angle_rad), sin(angle_rad))
		body.linear_velocity = Vector2.ZERO
		body.apply_central_impulse(direction * bounce_force)


func _is_mouse_over() -> bool:
	var mouse := get_global_mouse_position()
	var half := Vector2(45, 10)  # half of Area2D shape (90x20)
	return absf(mouse.x - global_position.x) < half.x and absf(mouse.y - global_position.y) < half.y


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_mouse_over():
				_selected = true
				_dragging = true
				_drag_offset = global_position - get_global_mouse_position()
				_sprite.color = COLOR_SELECTED
				get_viewport().set_input_as_handled()
			else:
				_selected = false
				_dragging = false
				_sprite.color = COLOR_NORMAL
		else:
			_dragging = false

	if event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and _selected:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			bounce_angle = clampf(bounce_angle - 5, -80, 80)
			_update_visuals()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			bounce_angle = clampf(bounce_angle + 5, -80, 80)
			_update_visuals()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			bounce_force = clampf(bounce_force + 50, 100, 2000)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			bounce_force = clampf(bounce_force - 50, 100, 2000)
			get_viewport().set_input_as_handled()


func _update_visuals() -> void:
	# Tilt the platform to match bounce angle (half the angle looks natural)
	_sprite.rotation = deg_to_rad(bounce_angle * 0.5)

	# Point the arrow in the launch direction
	var angle_rad := deg_to_rad(bounce_angle - 90)
	var dir := Vector2(cos(angle_rad), sin(angle_rad))
	var tip := dir * ARROW_LEN
	var perp := dir.rotated(PI / 2) * 6
	_arrow.polygon = PackedVector2Array([
		tip,
		tip - dir * 12 + perp,
		tip - dir * 12 - perp,
	])
