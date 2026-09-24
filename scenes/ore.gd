extends RigidBody2D

## Lifetime in seconds before the ore despawns.
@export var lifetime: float = 15.0

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")

func _ready() -> void:
	add_to_group("ore")
	collision_layer = 2
	collision_mask = 1

	contact_monitor = true
	max_contacts_reported = 4

	# Replace polygon with pixel sprite
	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	# one of three rock-and-copper chunks (tools/art/gen_items.py); it tumbles
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/ore.png")
	atlas.region = Rect2(randi() % 3 * 12, 0, 12, 12)
	spr.texture = atlas
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	# Despawn if fallen way below the map
	if global_position.y > 1400:
		queue_free()
