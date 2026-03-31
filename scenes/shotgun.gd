extends Node2D

@export var pellet_count: int = 5
@export var spread_angle: float = 30.0  # degrees
@export var pellet_speed: float = 400.0
@export var pellet_damage: int = 2
@export var fire_cooldown: float = 0.6

var _timer := 0.0
var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")


func _physics_process(delta: float) -> void:
	if _timer > 0:
		_timer -= delta

	# Aim toward mouse
	var mouse := get_global_mouse_position()
	var dir := (mouse - global_position).normalized()
	rotation = dir.angle()

	# Fire with F key
	if Input.is_key_pressed(KEY_F) and _timer <= 0:
		_fire(dir)


func _fire(dir: Vector2) -> void:
	_timer = fire_cooldown

	var base_angle := dir.angle()
	var spread_rad := deg_to_rad(spread_angle)

	for i in pellet_count:
		var offset := remap(i, 0, pellet_count - 1, -spread_rad / 2, spread_rad / 2)
		if pellet_count == 1:
			offset = 0.0
		var pellet_dir := Vector2.from_angle(base_angle + offset)

		var bullet := _bullet_scene.instantiate()
		bullet.global_position = global_position + dir * 12
		bullet.velocity = pellet_dir * pellet_speed
		bullet.damage = pellet_damage
		bullet.lifetime = 0.8  # short range
		# Make pellets smaller and white
		get_tree().current_scene.add_child(bullet)

	# Recoil animation
	var tween := create_tween()
	tween.tween_property(self, "position", position - dir.normalized() * 4, 0.05)
	tween.tween_property(self, "position", position, 0.1)
