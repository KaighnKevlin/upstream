extends RigidBody2D

## Lifetime in seconds before the ingot despawns.
@export var lifetime: float = 20.0

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	contact_monitor = true
	max_contacts_reported = 4

	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	spr.texture = ObjectSprites.create_ingot_texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	if global_position.y > 1400:
		queue_free()
