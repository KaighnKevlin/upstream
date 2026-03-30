extends Node2D

@export var fire_rate: float = 1.0  # shots per second
@export var fire_range: float = 400.0

var _ammo_port: Node = null
var _timer: float = 0.0


func setup(ammo_port: Node) -> void:
	_ammo_port = ammo_port


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer < 1.0 / fire_rate:
		return
	_timer = 0.0

	# Find nearest enemy first — don't consume ammo if nothing to shoot
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := fire_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest == null:
		return  # no targets, save ammo

	# Try to consume ammo
	if _ammo_port == null or not _ammo_port.consume_ammo():
		# No ammo — barrel flash red
		var barrel := $Barrel as Polygon2D
		var tween := create_tween()
		tween.tween_property(barrel, "modulate", Color(1, 0.3, 0.3), 0.1)
		tween.tween_property(barrel, "modulate", Color.WHITE, 0.2)
		return

	# Fire
	if nearest.has_method("take_damage"):
		nearest.take_damage(1)

	# Muzzle flash
	var barrel := $Barrel as Polygon2D
	var tween := create_tween()
	tween.tween_property(barrel, "modulate", Color(1, 1, 0.5), 0.03)
	tween.tween_property(barrel, "modulate", Color.WHITE, 0.08)
