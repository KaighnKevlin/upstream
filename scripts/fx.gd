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
