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
	# science flask: light, glass. Lands too hard and it shatters.
	# springsteel coil: bounces off nearly everything and keeps its speed
	# through an enemy (ricochet), so one shot can clatter through a crowd.
	"spring": {"mass": 1.2, "bounce": 0.92, "friction": 0.15, "tex": "res://assets/sprites/spring_item.png", "size": 12, "frames": 1, "radius": 5.0, "ricochet": true},
	"flask": {"mass": 0.6, "bounce": 0.15, "friction": 0.6, "tex": "res://assets/sprites/flask.png", "size": 12, "h": 14, "frames": 1, "radius": 5.0, "fragile": 300.0},
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
	atlas.region = Rect2(randi() % int(spec.frames) * sz, 0, sz, spec.get("h", sz))
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
var _last_hit: Node = null


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
		if e == _last_hit and _hurt_cooldown > -0.3:
			continue  # a ricocheting spring: each enemy once per pass
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
			if KINDS.get(kind, {}).get("ricochet", false):
				# springs off it with most of its speed, glancing up a little,
				# and is ready to hit the next one almost at once
				_hurt_cooldown = 0.04
				_last_hit = e
				linear_velocity = linear_velocity.rotated(-signf(linear_velocity.x) * randf_range(0.05, 0.25)) * 0.88
				SFX.play_small(self, SFX.sfx_bounce(), -10.0, randf_range(1.3, 1.6))
				FX.burst(get_parent(), global_position, Color(0.8, 0.9, 0.95), 3, 70.0, 0.2, 1.0)
				return
			linear_velocity = linear_velocity.bounce(away) * 0.35 if linear_velocity.dot(away) < 0 else linear_velocity * 0.5
			return

func _on_impact(other: Node) -> void:
	var fragile: float = KINDS.get(kind, {}).get("fragile", 0.0)
	if fragile > 0.0 and _prev_speed > fragile:
		_shatter()
		return
	_knock_sound(other)
	if kind == "spring" and _prev_speed > 140 and _knock_cooldown <= 0.06:
		SFX.play_small(self, SFX.sfx_bounce(), lerpf(-24.0, -12.0, clampf(_prev_speed / 600.0, 0.0, 1.0)), randf_range(1.2, 1.5))
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


## Glass breaking: shards and a splash of tincture, a bright tinkle.
func _shatter() -> void:
	if is_queued_for_deletion():
		return
	FX.burst(get_parent(), global_position, Color(0.8, 0.92, 0.95, 0.9), 8, 120.0, 0.35, 1.2)
	FX.burst(get_parent(), global_position, Color(0.9, 0.3, 0.25, 0.85), 6, 60.0, 0.5, 1.8)
	SFX.play(get_tree().current_scene, SFX.sfx_clink())
	queue_free()
