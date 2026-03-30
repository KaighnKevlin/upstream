extends RigidBody2D

## Lifetime in seconds before the ore despawns.
@export var lifetime: float = 15.0

var _timer: float = 0.0


func _ready() -> void:
	add_to_group("ore")
	collision_layer = 2
	collision_mask = 1  # walls only

	contact_monitor = true
	max_contacts_reported = 4


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	# Despawn if fallen way below the map
	if global_position.y > 1200:
		queue_free()
