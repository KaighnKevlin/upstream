extends StaticBody2D

## Angle of ore ejection in degrees (0 = straight up, positive = rightward).
@export_range(-60, 60, 1) var eject_angle: float = 0.0

## Force applied to ejected ore (pixels/s).
@export_range(100, 2000, 10) var eject_force: float = 800.0

## Seconds between ore ejections.
@export_range(0.3, 5.0, 0.1) var eject_interval: float = 1.5

var _ore_scene: PackedScene = preload("res://scenes/ore.tscn")
var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= eject_interval:
		_timer -= eject_interval
		_eject_ore()


func _eject_ore() -> void:
	var ore := _ore_scene.instantiate() as RigidBody2D
	# Spawn ore just above the miner
	ore.global_position = global_position + Vector2(0, -30)

	# Calculate direction from angle (0 = up, positive = clockwise)
	var angle_rad := deg_to_rad(eject_angle - 90)  # -90 because 0 rad = right in Godot
	var direction := Vector2(cos(angle_rad), sin(angle_rad))

	# Add to scene tree first, then apply impulse
	get_tree().current_scene.add_child(ore)
	ore.apply_central_impulse(direction * eject_force)
