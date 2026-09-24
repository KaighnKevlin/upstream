extends RigidBody2D

## Lifetime in seconds before the ore despawns.
@export var lifetime: float = 15.0

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")
const FX = preload("res://scripts/fx.gd")

func _ready() -> void:
	add_to_group("ore")
	collision_layer = 2
	collision_mask = 1 | 8  # terrain + enemies: flying ore is a weapon

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

	# dusty streak while it flies, a puff when it lands hard
	var trail := preload("res://scripts/flight_trail.gd").new()
	trail.head_color = Color(0.9, 0.68, 0.42, 0.6)
	add_child(trail)
	body_entered.connect(_on_impact)


var _puff_cooldown := 0.0

var _prev_speed := 0.0
var _hurt_cooldown := 0.0

func _on_impact(other: Node) -> void:
	# enemies take damage from ore that hits them fast (dropped from a hopper,
	# a stray bounce), scaled by the speed it was travelling before contact
	if other.is_in_group("enemies") and other.has_method("take_damage") and _hurt_cooldown <= 0 \
			and _prev_speed > 160.0:
		_hurt_cooldown = 0.3
		other.take_damage(clampi(int(_prev_speed / 110.0), 1, 6))
	if _puff_cooldown > 0 or linear_velocity.length() < 120:
		return
	_puff_cooldown = 0.25
	FX.burst(get_parent(), global_position + Vector2(0, 5), Color(0.55, 0.45, 0.35, 0.8), 4, 45.0, 0.35, 1.5)


func _physics_process(delta: float) -> void:
	_puff_cooldown -= delta
	_hurt_cooldown -= delta
	_prev_speed = linear_velocity.length()
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	# Despawn if fallen way below the map
	if global_position.y > 1400:
		queue_free()
