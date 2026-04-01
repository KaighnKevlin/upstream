extends Node2D

const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

## How fast items float upward through the shaft (pixels/sec)
@export var lift_speed: float = 100.0

## Shaft dimensions (must match the sprite/collision)
const SHAFT_WIDTH := 40.0
const SHAFT_HEIGHT := 120.0

@onready var _area: Area2D = $Area2D

var _held_items: Array[RigidBody2D] = []


func _ready() -> void:
	_area.monitoring = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	# Behind player/enemies/ore, but in front of background/tiles
	z_index = 0
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/upstream-sprite.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	# Blue glow
	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(128)
	light.texture_scale = 2.0
	light.energy = 0.7
	light.color = Color(0.3, 0.5, 1.0)
	add_child(light)


func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		SFX.play(self, SFX.sfx_bounce())
		body.set_physics_process(false)  # pause despawn timer immediately on entry


func _on_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		if body in _held_items:
			body.set_physics_process(true)  # resume despawn timer
			body.gravity_scale = 1
		_held_items.erase(body)
	elif body is CharacterBody2D:
		if "in_shaft" in body:
			body.in_shaft = false


func _physics_process(delta: float) -> void:
	var shaft_top := global_position.y - SHAFT_HEIGHT / 2.0
	var shaft_bottom := global_position.y + SHAFT_HEIGHT / 2.0

	# Clean up invalid items
	_held_items = _held_items.filter(func(b: RigidBody2D) -> bool: return is_instance_valid(b))

	# Assign stable slot positions to held items (order preserved from entry)
	for i in _held_items.size():
		var body := _held_items[i]
		body.linear_velocity = Vector2.ZERO
		body.gravity_scale = 0

		var col := i % 2
		var row := i / 2
		var target_x := global_position.x - 8 + col * 16
		var target_y := shaft_top + 10 + row * 18

		# Clamp within shaft
		target_y = minf(target_y, shaft_bottom - 10)

		body.global_position.x = move_toward(body.global_position.x, target_x, 300 * delta)
		body.global_position.y = move_toward(body.global_position.y, target_y, 300 * delta)

	# Max items that fit: 2 columns, rows spaced 18px in shaft height
	var max_items := int((SHAFT_HEIGHT - 20) / 18) * 2

	# Handle bodies in the area that aren't held yet
	for body in _area.get_overlapping_bodies():
		if body is RigidBody2D:
			if body not in _held_items:
				if _held_items.size() >= max_items:
					# Full — reject, let it fall back out
					body.gravity_scale = 1
				else:
					# Float upward toward top
					var at_top := body.global_position.y <= shaft_top + 16 + _held_items.size() / 2 * 18
					if at_top:
						_held_items.append(body)
					else:
						body.linear_velocity.y = -lift_speed
						body.linear_velocity.x = move_toward(body.linear_velocity.x, 0, 150 * delta)
						body.gravity_scale = 0

		elif body is CharacterBody2D:
			if "in_shaft" in body:
				body.in_shaft = true

			# If player is jumping (strong upward velocity), don't interfere
			if body.velocity.y < -200:
				continue

			var near_top := body.global_position.y <= shaft_top + 24
			if near_top:
				# At top: treat as ground — stop vertical movement
				body.velocity.y = 0
				body.global_position.y = shaft_top + 24
			else:
				# Below top: slow upward float, cancel gravity
				body.velocity.y = clampf(body.velocity.y - 980.0 * delta - 20.0, -lift_speed * 0.7, lift_speed)

			# Slow horizontal movement in the shaft
			body.velocity.x *= 0.85
