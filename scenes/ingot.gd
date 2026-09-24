extends RigidBody2D

## Lifetime in seconds before the ingot despawns.
@export var lifetime: float = 20.0

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	contact_monitor = true
	max_contacts_reported = 4

	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/ingot.png")  # brass bar (tools/art/gen_items.py)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	# Fresh out of the laser: glowing hot, cooling to silver
	spr.modulate = Color(2.6, 1.3, 0.5)
	var glow := PointLight2D.new()
	glow.texture = LightTextures.create_radial_light(64)
	glow.color = Color(1.0, 0.55, 0.2)
	glow.energy = 0.6
	add_child(glow)
	var tween := create_tween().set_parallel()
	tween.tween_property(spr, "modulate", Color.WHITE, 2.0)
	tween.tween_property(glow, "energy", 0.0, 2.0)
	tween.chain().tween_callback(glow.queue_free)
	# a hot streak that cools with the bar
	var trail := preload("res://scripts/flight_trail.gd").new()
	trail.head_color = Color(1.0, 0.62, 0.25, 0.7)
	add_child(trail)
	var cool := trail.create_tween()
	cool.tween_property(trail, "modulate", Color(0.95, 0.85, 0.6, 0.6), 2.0)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	if global_position.y > 1400:
		queue_free()
