extends RigidBody2D

## Lifetime in seconds before the ingot despawns.
@export var lifetime: float = 20.0

var _timer: float = 0.0


func _ready() -> void:
	collision_layer = 2  # same as ore — layer 2
	collision_mask = 1   # walls only

	contact_monitor = true
	max_contacts_reported = 4


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	if global_position.y > 1400:
		queue_free()
