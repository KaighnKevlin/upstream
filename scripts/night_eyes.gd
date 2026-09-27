extends Node2D
## Night eyes: after dark the clockwork enemies' eye lamps glow red, a
## soft bloom around a hot pip near each head, fading in as the light goes
## (daynight.gd daylight()). A night wave marching in reads as a line of red
## lamps in the dark. Drawn unshaded and additive in one pass for all of
## them (no light nodes). Cave dwellers have lights of their own and are
## skipped, as are plugged rollers and anything buried or dormant.

const SKIP := ["crawlers", "cinderbats", "wyrms", "ruins"]

var _dn: Node = null


func _ready() -> void:
	z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(_delta: float) -> void:
	if _dn == null or not is_instance_valid(_dn):
		_dn = get_parent().get_node_or_null("DayNight")
	queue_redraw()


func _night() -> float:
	if _dn == null or not _dn.has_method("daylight"):
		return 0.0
	return clampf(1.0 - _dn.daylight() * 1.6, 0.0, 1.0)


func _draw() -> void:
	var k := _night()
	if k <= 0.02:
		return
	var t := Time.get_ticks_msec() * 0.001
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("hit_center") or ("_dying" in e and e._dying):
			continue
		if ("buried" in e and e.buried) or e.get("plugged"):
			continue
		var skip := false
		for g in SKIP:
			skip = skip or e.is_in_group(g)
		if skip:
			continue
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 10.0
		var face: float = 1.0
		if e.get("_facing") != null:
			face = signf(e._facing) if e._facing != 0 else 1.0
		elif e.get("direction") != null:
			face = signf(e.direction) if e.direction != 0 else 1.0
		var at: Vector2 = to_local(e.hit_center()) + Vector2(face * r * 0.45, -r * 0.55)
		if e.get("enemy_type") == 0 and e.get("colossus") != null:
			# a titan's visor sits high on its head (twice as high on the Colossus)
			var s: float = 2.0 if e.colossus else 1.0
			at = to_local(e.global_position) + Vector2(face * 5.0, -71.0) * s
			r = 12.0 * s
		var flick := 0.85 + 0.15 * sin(t * 7.0 + e.get_instance_id() % 97)
		var a := k * flick
		draw_circle(at, r * 0.55, Color(0.9, 0.15, 0.08, 0.10 * a))
		draw_circle(at, r * 0.28, Color(1.0, 0.3, 0.15, 0.22 * a))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.55, 0.35, 0.9 * a))
