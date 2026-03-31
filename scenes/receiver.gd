extends Area2D

signal ammo_changed(current: int, max_ammo: int)

@export var max_buffer: int = 20
var buffer: int = 0


@onready var _buffer_fill: Polygon2D = $BufferFill

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	_update_bar()


func _on_body_entered(body: Node2D) -> void:
	# Only accept ingots (RigidBody2D not in "ore" group)
	if not body is RigidBody2D:
		return
	if body.is_in_group("ore"):
		body.queue_free()  # raw ore is destroyed, not accepted
		return

	# It's an ingot — accept it
	if buffer < max_buffer:
		buffer += 1
		ammo_changed.emit(buffer, max_buffer)
		_update_bar()
		var sprite := $Sprite as Polygon2D
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	body.queue_free()


func consume_ammo() -> bool:
	if buffer > 0:
		buffer -= 1
		ammo_changed.emit(buffer, max_buffer)
		_update_bar()
		return true
	return false


func _update_bar() -> void:
	var fill_ratio := float(buffer) / float(max_buffer)
	var w := 50.0 * fill_ratio  # half-width of fill
	_buffer_fill.polygon = PackedVector2Array([
		Vector2(-50, -4), Vector2(-50 + w * 2, -4),
		Vector2(-50 + w * 2, 4), Vector2(-50, 4),
	])
	# Color shifts from green to red as buffer empties
	if fill_ratio > 0.5:
		_buffer_fill.color = Color(0.2, 0.9, 0.3, 1)
	elif fill_ratio > 0.2:
		_buffer_fill.color = Color(0.9, 0.8, 0.1, 1)
	else:
		_buffer_fill.color = Color(0.9, 0.2, 0.1, 1)
