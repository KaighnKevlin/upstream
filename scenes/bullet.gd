extends Area2D

var velocity := Vector2.ZERO
var damage := 1
var lifetime := 3.0
var _timer := 0.0

const HIT_RADIUS := 14.0


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	# Manual hit detection — more reliable than body_entered for fast projectiles
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < HIT_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			queue_free()
			return
