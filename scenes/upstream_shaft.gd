extends Node2D
## The upstream: a column of rising blue current. Anything that falls in
## (ore, ingots, you) is carried up and held at the top, stacking double-file.
##
## Expandable: build another lift on top of this one and it grows by a
## segment instead (up to MAX_SEGMENTS), so a tall upstream can lift ore
## from a deep mine to the surface or up to a hopper high on a tower. The
## node's position is the centre of the bottom segment; the column grows
## upward from there.
## Art: Kaighn's drawing, animated (tools/art/gen_upstream.py): cap, stream
## column and base are cut from it and the column is repeated.

const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

## How fast items float upward through the shaft (pixels/sec)
@export var lift_speed: float = 100.0
## How many segments tall (each SEGMENT px)
@export var segments := 1
## What happens at the top: 0 holds the items there, -1 / 1 tips them off
## the cap to the left / right one at a time (click the cap to cycle)
@export var spill := 0
const SPILL_EVERY := 0.4
var spilled := 0            # tests
var _spill_t := 0.0

const SHAFT_WIDTH := 40.0
const SEGMENT := 120.0
const MAX_SEGMENTS := 6
# rows of the 128px-tall art: the cap, the stream column, the base
const CAP := Vector2i(0, 32)
const COLUMN := Vector2i(32, 100)
const BASE := Vector2i(100, 128)

@onready var _area: Area2D = $Area2D

var _held_items: Array[RigidBody2D] = []
var _art: Node2D
var _spray: CPUParticles2D
var _light: PointLight2D


func height() -> float:
	return SEGMENT * segments


func top_y() -> float:
	return global_position.y + SEGMENT * 0.5 - height()


func bottom_y() -> float:
	return global_position.y + SEGMENT * 0.5


func _ready() -> void:
	_area.monitoring = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	# Behind player/enemies/ore, but in front of background/tiles
	z_index = 0
	_art = Node2D.new()
	add_child(_art)

	# Spray where the stream spills over the top of the column
	_spray = CPUParticles2D.new()
	_spray.amount = 18
	_spray.lifetime = 0.7
	_spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_spray.emission_rect_extents = Vector2(12, 1)
	_spray.direction = Vector2(0, -1)
	_spray.spread = 60.0
	_spray.initial_velocity_min = 45.0
	_spray.initial_velocity_max = 75.0
	_spray.gravity = Vector2(0, 160)
	_spray.scale_amount_min = 1.0
	_spray.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.9, 1.0, 1.0))
	ramp.set_color(1, Color(0.3, 0.55, 0.95, 0.0))
	_spray.color_ramp = ramp
	_spray.z_index = 1
	add_child(_spray)

	# Blue glow
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(128)
	_light.energy = 0.4
	_light.color = Color(0.3, 0.5, 1.0)
	add_child(_light)
	_rebuild()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if has_meta("ghost") or (has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0):
		return
	var m := get_global_mouse_position()
	if absf(m.x - global_position.x) < 24.0 and absf(m.y - (top_y() + 8.0)) < 20.0:
		spill = [0, 1, -1][([0, 1, -1].find(spill) + 1) % 3]   # hold -> right -> left -> hold
		SFX.play(self, SFX.sfx_clink())
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if spill == 0 or has_meta("ghost"):
		return
	# a little brass arrow on the cap showing which way it tips
	var y := top_y() - global_position.y - 6.0
	var tip := Vector2(spill * 30.0, y)
	var tail := Vector2(spill * 18.0, y)
	draw_line(tail, tip, Color(0.16, 0.15, 0.12), 4.0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(spill * 3, 0), tip + Vector2(-spill * 3, -4), tip + Vector2(-spill * 3, 4)]), Color(0.16, 0.15, 0.12))
	draw_line(tail, tip, Color(0.85, 0.72, 0.45), 2.0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(spill * 2, 0), tip + Vector2(-spill * 2, -3), tip + Vector2(-spill * 2, 3)]), Color(0.85, 0.72, 0.45))


## Another segment on top (a lift built on this one's top). False when it's
## already as tall as it goes.
func extend() -> bool:
	if segments >= MAX_SEGMENTS:
		return false
	segments += 1
	_rebuild()
	SFX.play(self, SFX.sfx_bounce(), -4.0, 0.7)
	return true


func _rebuild() -> void:
	var h := height()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SHAFT_WIDTH, h)
	var cs := _area.get_node("CollisionShape2D") as CollisionShape2D
	cs.shape = shape
	cs.position = Vector2(0, SEGMENT * 0.5 - h * 0.5)
	for c in _art.get_children():
		c.queue_free()
	# local y of the art's top and bottom: the single-segment art is 128 tall,
	# centred on the 120px segment (4px past each end)
	var top := SEGMENT * 0.5 - h - 4.0
	var bottom := SEGMENT * 0.5 + 4.0
	_piece(CAP.x, COLUMN.y, top)                        # cap and first stretch of column
	var y := top + float(COLUMN.y)
	var end := bottom - float(BASE.y - BASE.x)
	while y < end - 0.5:
		var n := minf(float(COLUMN.y - COLUMN.x), end - y)
		_piece(COLUMN.x, COLUMN.x + int(n), y)
		y += n
	_piece(BASE.x, BASE.y, end)
	_spray.position = Vector2(0, top + 7)
	_light.position = Vector2(0, SEGMENT * 0.5 - h * 0.5)
	_light.texture_scale = 2.0 + 0.8 * (segments - 1)
	queue_redraw()


## A horizontal band of the animated art (rows r0..r1), placed with its top at y.
func _piece(r0: int, r1: int, y: float) -> void:
	var anim_tex := load("res://assets/sprites/upstream_anim.png") as Texture2D
	var spr := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 10.0)
	for i in 8:
		var a := AtlasTexture.new()
		a.atlas = anim_tex
		a.region = Rect2(i * 48, r0, 48, r1 - r0)
		sf.add_frame("default", a)
	spr.sprite_frames = sf
	spr.centered = false
	spr.offset = Vector2(-24, 0)
	spr.position = Vector2(0, y)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.add_child(spr)
	spr.play()


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
	var shaft_top := top_y()
	var shaft_bottom := bottom_y()

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

	# tip the top item off the cap
	_spill_t -= delta
	if spill != 0 and _spill_t <= 0 and not _held_items.is_empty():
		_spill_t = SPILL_EVERY
		var b: RigidBody2D = _held_items.pop_front()
		b.set_meta("spilled_at", Time.get_ticks_msec())
		b.gravity_scale = 1
		b.set_physics_process(true)
		b.global_position = Vector2(global_position.x + spill * 26.0, shaft_top - 6.0)
		b.linear_velocity = Vector2(spill * 150.0, -140.0)
		spilled += 1
		SFX.play_small(self, SFX.sfx_bounce(), -10.0, 1.3)

	# Max items that fit: 2 columns, rows spaced 18px down the whole column
	var max_items := int((height() - 20) / 18) * 2

	# Handle bodies in the area that aren't held yet
	for body in _area.get_overlapping_bodies():
		if body is RigidBody2D:
			if body.has_meta("spilled_at") and Time.get_ticks_msec() - int(body.get_meta("spilled_at")) < 900:
				continue   # just tipped out: let it go
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
