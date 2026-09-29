extends RefCounted
## Every built piece gives off a soft warm glow, so a machine lights its own
## corner of the cave (no torches to plant). Dragged pieces (chutes, rails)
## glow from their middle, and wider so the whole run shows.

const LightTextures = preload("res://scripts/light_textures.gd")
static var _tex: Texture2D
static var enabled := true          # main turns it off while the caves are fully lit


static func add(piece: Node2D) -> void:
	if not enabled or piece == null or piece.has_node("PieceLight"):
		return
	if _tex == null:
		_tex = LightTextures.create_radial_light(128)
	var l := PointLight2D.new()
	l.name = "PieceLight"
	l.texture = _tex
	l.color = Color(1.0, 0.82, 0.58)
	l.energy = 0.55
	l.texture_scale = 1.4
	l.shadow_enabled = false
	var off = piece.get("end_offset")
	if off is Vector2:
		l.position = off * 0.5 + Vector2(0, -8)
		l.texture_scale = clampf(1.2 + off.length() / 120.0, 1.2, 3.2)
	else:
		l.position = Vector2(0, -14)
	piece.add_child(l)
