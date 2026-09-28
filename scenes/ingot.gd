extends RigidBody2D

## Lifetime in seconds before the ingot despawns.
@export var lifetime: float = 20.0
## copper (a brass bar) or iron (a gunmetal bar, twice as heavy).
@export var kind := "copper"

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 64  # terrain + chutes
	add_to_group("ingots")
	mass = 2.0 if kind == "iron" else 1.0

	contact_monitor = true
	max_contacts_reported = 4

	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/ingot_iron.png" if kind == "iron" else "res://assets/sprites/ingot.png")  # tools/art/gen_items.py
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


## On track (the ore-only layer) a bar rolls on like a marble: the default
## spin damping would brake it (the spin is tied to the roll); on terrain it
## gets it back so bars settle as before. Same rule as ore._roll_on_track.
const TRACK_LAYER := 64
const TRACK_ANGULAR_DAMP := 0.1
var _on_track := false


func _roll_on_track() -> void:
	var want := _on_track
	for b in get_colliding_bodies():
		if b is TileMapLayer or (b is CollisionObject2D and b.collision_layer & 1):
			want = false
			break
		elif b is CollisionObject2D and b.collision_layer & TRACK_LAYER:
			want = true
	if want == _on_track:
		return
	_on_track = want
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE if want else RigidBody2D.DAMP_MODE_COMBINE
	angular_damp = TRACK_ANGULAR_DAMP if want else 0.0


func _physics_process(delta: float) -> void:
	_roll_on_track()
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	if global_position.y > 1400:
		queue_free()
