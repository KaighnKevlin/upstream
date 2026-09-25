extends RigidBody2D

## Lifetime in seconds before the ore despawns.
@export var lifetime: float = 15.0
## What it is. Iron is three times as heavy and barely bounces: springs,
## bumpers and fans move it less, it pumps a pendulum harder, magpies
## struggle with it, and fired from a turret it hits harder and punches
## through tower shields.
@export var kind := "copper"

## size: sprite frame (square); frames: variants side by side; radius: body.
## shot and gear are made in an assembler, not mined (they're "ore" too:
## anything loose and bouncing that machines can carry and turrets can fire).
const KINDS := {
	"copper": {"mass": 1.0, "bounce": 0.5, "friction": 0.3, "tex": "res://assets/sprites/ore.png", "size": 12, "frames": 5, "radius": 6.5},
	"iron": {"mass": 3.0, "bounce": 0.12, "friction": 0.5, "tex": "res://assets/sprites/ore_iron.png", "size": 12, "frames": 5, "radius": 6.5},
	"shot": {"mass": 2.0, "bounce": 0.25, "friction": 0.4, "tex": "res://assets/sprites/iron_shot.png", "size": 8, "frames": 1, "radius": 3.6},
	"gear": {"mass": 1.5, "bounce": 0.3, "friction": 0.9, "tex": "res://assets/sprites/gear_item.png", "size": 16, "frames": 1, "radius": 7.5, "rolls": true},
}
static var _shapes := {}
static var _materials := {}

var _timer: float = 0.0


const ObjectSprites = preload("res://scripts/object_sprites.gd")
const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

func _ready() -> void:
	add_to_group("ore")
	collision_layer = 2
	collision_mask = 1 | 64  # terrain + chutes
	angular_damp = 1.5  # loose ore stops rolling on flat ground and can sleep

	contact_monitor = true
	max_contacts_reported = 4
	var spec: Dictionary = KINDS.get(kind, KINDS.copper)
	mass = spec.mass
	if kind != "copper":
		if not _materials.has(kind):
			var m := PhysicsMaterial.new()
			m.bounce = spec.bounce
			m.friction = spec.friction
			_materials[kind] = m
		physics_material_override = _materials[kind]
	if spec.radius != 6.5:
		if not _shapes.has(kind):
			var c := CircleShape2D.new()
			c.radius = spec.radius
			_shapes[kind] = c
		$CollisionShape2D.shape = _shapes[kind]
	if spec.get("rolls", false):
		angular_damp = 0.15  # a gear rolls away like a wheel

	# Replace polygon with pixel sprite
	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	# one of five faceted rock-and-copper chunks (tools/art/gen_items.py); it tumbles
	var atlas := AtlasTexture.new()
	atlas.atlas = load(spec.tex)
	var sz: int = spec.size
	atlas.region = Rect2(randi() % int(spec.frames) * sz, 0, sz, sz)
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


## Flying ore is a weapon: passing through an enemy's body fast (dropped
## from a hopper, fired from a funnel turret, a stray bounce) hurts it,
## scaled by speed, and knocks the ore back off it.
func _check_enemy_hit() -> void:
	if _hurt_cooldown > 0 or _prev_speed < 160.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("hit_center") or ("_dying" in e and e._dying):
			continue
		if e.get("_target") == self:
			continue  # a magpie closing its claw on this piece
		var c: Vector2 = e.hit_center()
		if global_position.distance_to(c) < e.hit_radius() + 7.0:
			_hurt_cooldown = 0.35
			if e.has_method("shield_blocks") and mass < 2.0:  # heavy ore punches through
				var n: Vector2 = e.shield_blocks(global_position, linear_velocity)
				if n != Vector2.ZERO:  # glances off the tower shield
					linear_velocity = linear_velocity.bounce(n) * 0.6 + Vector2(0, -60)
					e.shield_clang(global_position)
					return
			e.take_damage(clampi(int(_prev_speed / 110.0 * pow(mass, 0.6)), 1, 9))
			if mass >= 2.0:
				# heavy: shoves the target and ploughs on through
				if e.has_method("knock"):
					e.knock(Vector2(signf(linear_velocity.x) * 160.0, -120.0))
				linear_velocity *= 0.7
				return
			var away := (global_position - c).normalized()
			linear_velocity = linear_velocity.bounce(away) * 0.35 if linear_velocity.dot(away) < 0 else linear_velocity * 0.5
			return

func _on_impact(other: Node) -> void:
	_knock_sound(other)
	if _puff_cooldown > 0 or linear_velocity.length() < 120:
		return
	_puff_cooldown = 0.25
	FX.burst(get_parent(), global_position + Vector2(0, 5), Color(0.55, 0.45, 0.35, 0.8), 4, 45.0, 0.35, 1.5)


## Knock on landing: louder the harder it hit, by what it hit.
var _knock_cooldown := 0.0

func _knock_sound(other: Node) -> void:
	var speed := _prev_speed  # before the contact took it away
	# in a funnel the feeder keeps jostling the pile: only real arrivals knock
	var quiet := 170.0 if has_meta("store_material") else 90.0
	if speed < quiet or _knock_cooldown > 0:
		return
	_knock_cooldown = 0.12
	var surface := "ground"
	if other is RigidBody2D:
		surface = "ore"
	elif other is StaticBody2D:
		surface = "metal"
	var k := clampf(inverse_lerp(90.0, 700.0, speed), 0.0, 1.0)
	SFX.play_small(self, SFX.sfx_ore_knock(surface), lerpf(-26.0, -10.0, k), lerpf(1.12, 0.92, k))


func _physics_process(delta: float) -> void:
	_knock_cooldown -= delta
	_puff_cooldown -= delta
	_hurt_cooldown -= delta
	_prev_speed = linear_velocity.length()
	_check_enemy_hit()
	_timer += delta
	if _timer >= lifetime:
		queue_free()
	# Despawn if fallen way below the map
	if global_position.y > 1400:
		queue_free()
