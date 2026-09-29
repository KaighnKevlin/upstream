extends RigidBody2D

const Hold = preload("res://scripts/hold.gd")

## Lifetime in seconds before the ingot despawns.
@export var lifetime: float = 20.0
## copper (a brass bar), iron (a gunmetal bar, twice as heavy) or bronze
## (copper and iron fused hot in a crucible: a dark gold bar).
@export var kind := "copper"

## Heat: 1 fresh out of a smelter, down to 0 over COOL seconds. A hot bar
## glows and lights the cave around it. Cold bars are still ingots for
## everything that takes ingots (the dome, turrets, the tesla ...); only
## forging wants them hot: a crucible fuses copper and iron into bronze
## only while both are hot, and the gear stamp strikes hot iron twice as
## fast. A furnace rail heats a cold bar back up. Set it before adding
## the ingot to the tree to spawn one part-cooled (0 = cold).
const COOL := 8.0
var heat := 1.0

const TINT := {"bronze": Color(0.78, 0.56, 0.36)}   # on the copper bar's sprite
const HOT := Color(2.6, 1.3, 0.5)                  # white-hot modulate at heat 1

var _timer: float = 0.0
var _spr: Sprite2D
var _glow: PointLight2D
var _trail: Line2D


const ObjectSprites = preload("res://scripts/object_sprites.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 64  # terrain + chutes
	add_to_group("ingots")
	mass = {"iron": 2.0, "bronze": 1.5}.get(kind, 1.0)

	contact_monitor = true
	max_contacts_reported = 4

	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/ingot_iron.png" if kind == "iron" else "res://assets/sprites/ingot.png")  # tools/art/gen_items.py
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	_spr = spr

	# Fresh out of the smelter: glowing hot, cooling to its own colour; the
	# glow lights the cave while it lasts (see _show_heat)
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.create_radial_light(64)
	_glow.texture_scale = 1.6
	_glow.color = Color(1.0, 0.55, 0.2)
	add_child(_glow)
	# a hot streak that cools with the bar
	_trail = preload("res://scripts/flight_trail.gd").new()
	_trail.head_color = Color(1.0, 0.62, 0.25, 0.7)
	add_child(_trail)
	_show_heat()


## True while the bar is hot enough to forge.
func is_hot() -> bool:
	return heat > 0.0


## Heat the bar back up by `amount` (a furnace rail does, a little each frame).
func reheat(amount: float) -> void:
	heat = minf(1.0, heat + amount)
	if _spr:
		_show_heat()


func _show_heat() -> void:
	var base: Color = TINT.get(kind, Color.WHITE)
	var h := clampf(heat, 0.0, 1.0)
	_spr.modulate = base.lerp(HOT, h)
	_glow.energy = 0.75 * h
	_glow.enabled = h > 0.01
	_trail.modulate = Color(0.95, 0.85, 0.6, 0.6).lerp(Color.WHITE, h)


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
	if has_meta(Hold.META):
		Hold.lapse(self)   # its holder was removed, or let it go without saying
	if heat > 0.0:
		heat = maxf(0.0, heat - delta / COOL)
		_show_heat()
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	if global_position.y > 1400:
		queue_free()
