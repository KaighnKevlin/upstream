extends Node
## Small one-shot visual effects: particle bursts, camera shake, squash/pop.

## Tile atlas x -> debris colour (dirt, stone, iron, copper, deep stone, grass)
const TILE_COLORS := {
	0: Color(0.62, 0.4, 0.3),
	1: Color(0.55, 0.55, 0.6),
	2: Color(0.78, 0.5, 0.3),
	3: Color(0.72, 0.38, 0.62),
	4: Color(0.36, 0.36, 0.44),
	5: Color(0.35, 0.62, 0.22),
}


## Square pixel particles flung out from `pos`, affected by gravity.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 10,
		speed := 90.0, lifetime := 0.5, size := 2.0, gravity := 400.0) -> void:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.5
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	p.z_index = 3
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Decaying random offset on the active camera.
static func shake(node: Node, strength := 4.0, duration := 0.25) -> void:
	var cam := node.get_viewport().get_camera_2d()
	if cam == null:
		return
	var tween := cam.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tween.tween_property(cam, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.03)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.03)


## Quick scale pop, e.g. when something catches or bounces an item.
static func pop(node: CanvasItem, amount := Vector2(1.25, 0.8), duration := 0.14) -> void:
	# Remember the rest scale, so overlapping pops don't ratchet it
	if not node.has_meta("fx_base_scale"):
		node.set_meta("fx_base_scale", node.scale)
	var base: Vector2 = node.get_meta("fx_base_scale")
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base * amount, duration * 0.35)
	tween.tween_property(node, "scale", base, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Brief colour flash on a CanvasItem, returning to its current modulate.
static func flash(node: CanvasItem, color := Color(2, 2, 2), duration := 0.12) -> void:
	if not node.has_meta("fx_base_modulate"):
		node.set_meta("fx_base_modulate", node.modulate)
	var base: Color = node.get_meta("fx_base_modulate")
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.3)
	tween.tween_property(node, "modulate", base, duration * 0.7)


## Clockwork debris: real physics bits (gears, bolts, springs, plate, core
## glass from assets/sprites/debris.png) that bounce on the terrain, then fade.
static func debris(parent: Node, pos: Vector2, count := 6, speed := 170.0, glass := true) -> void:
	var tex := preload("res://assets/sprites/debris.png")
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.6
	for i in count:
		var b := RigidBody2D.new()
		b.collision_layer = 0
		b.collision_mask = 1  # terrain + walls only
		b.physics_material_override = mat
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 2.5
		shape.shape = circle
		b.add_child(shape)
		var spr := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var piece := randi() % (6 if glass else 5)
		atlas.region = Rect2(piece * 8, 0, 8, 8)
		spr.texture = atlas
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(spr)
		b.z_index = 3
		b.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		b.linear_velocity = Vector2(randf_range(-0.7, 0.7) * speed, -randf_range(0.5, 1.0) * speed)
		b.angular_velocity = randf_range(-18, 18)
		# deferred: deaths can happen inside physics callbacks
		parent.add_child.call_deferred(b)
		var tween := parent.create_tween()
		tween.tween_interval(randf_range(1.8, 2.6))
		tween.tween_property(b, "modulate:a", 0.0, 0.5)
		tween.tween_callback(b.queue_free)


## A mined tile breaks into quarters of its own texture that pop out,
## tumble and fall, fading. Purely visual: the cell is already cleared.
static func tile_break(parent: Node, tilemap: TileMapLayer, cell: Vector2i, source_id: int,
		atlas_coords: Vector2i, from_dir := Vector2.ZERO) -> void:
	var src := tilemap.tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null:
		return
	var region := Rect2(src.get_tile_texture_region(atlas_coords))
	var center := tilemap.to_global(tilemap.map_to_local(cell))
	var half := region.size / 2
	for q in 4:
		var qx := q % 2
		var qy := q / 2
		var spr := Sprite2D.new()
		var a := AtlasTexture.new()
		a.atlas = src.texture
		a.region = Rect2(region.position + Vector2(qx * half.x, qy * half.y), half)
		spr.texture = a
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 0  # behind the prospector (so a column dig doesn't bury him)
		var start := center + Vector2((qx - 0.5) * half.x, (qy - 0.5) * half.y)
		spr.global_position = start
		parent.add_child(spr)
		# fly away from the pick, outward from the centre, then fall
		var out := Vector2(qx - 0.5, qy - 0.5) * 2.0
		var vel := (out * 55.0 - from_dir * 40.0) + Vector2(randf_range(-20, 20), -randf_range(60, 110))
		var spin := randf_range(-9.0, 9.0)
		var life := randf_range(0.45, 0.6)
		var t := spr.create_tween()
		t.tween_method(func(k: float):
			spr.global_position = start + vel * k + Vector2(0, 520.0 * k * k)
			spr.rotation = spin * k
			spr.scale = Vector2.ONE * (1.0 - 0.45 * k / life),
			0.0, life, life)
		t.parallel().tween_property(spr, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)
		t.tween_callback(spr.queue_free)


## A damage number popping off whatever was hit: rises and fades. Big hits
## are bigger and hotter.
static var _dmg_font: Font

static func damage_number(parent: Node, pos: Vector2, amount: int) -> void:
	if parent == null or amount <= 0:
		return
	if _dmg_font == null:
		_dmg_font = preload("res://scripts/pixel_font.gd").get_font()
	var l := Label.new()
	l.text = str(amount)
	l.add_theme_font_override("font", _dmg_font)
	var big := amount >= 6
	l.add_theme_font_size_override("font_size", 10 if not big else 20)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75) if not big else Color(1.0, 0.62, 0.25))
	l.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.05, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.z_index = 12
	l.position = pos + Vector2(randf_range(-8, 2), -22)
	parent.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 18.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)
