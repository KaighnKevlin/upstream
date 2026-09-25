extends Control
## Build toolbar: one slot per placeable piece, drawn from the pieces' own
## sprites, with its hotkey. Click a slot (or press the key) to build it;
## click the selected slot again to cancel. The slot for the current build
## lights up. Hovering a slot shows its name.

const SLOT := Vector2(41, 46)
const GAP := 5.0
const ICON_BOX := Vector2(36, 34)

const DARK := Color(0.1, 0.09, 0.07)
const WELL := Color(0.16, 0.13, 0.1)
const RIM := Color(0.45, 0.37, 0.26)
const RIM_ON := Color(1.0, 0.78, 0.35)
const KEY_COL := Color(0.9, 0.82, 0.62)

# [build type, hotkey label, name]
const PIECES := [
	[1, "1", "Trampoline"], [2, "2", "Vein tapper"], [3, "3", "Laser smelter"],
	[4, "4", "Upstream lift"], [5, "5", "Drop hopper"], [6, "6", "Funnel turret"],
	[7, "7", "Spikes"], [8, "8", "Catapult"], [9, "9", "Chute"], [10, "0", "Splitter"], [11, "B", "Bumper"], [12, "C", "Conveyor belt"], [13, "V", "Bellows fan"], [14, "M", "Wrecking pendulum"], [15, "N", "Gravity wheel"],
]

var font: Font
var _current := 0
var _hover := -1
var _name_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(PIECES.size() * (SLOT.x + GAP) - GAP, SLOT.y)
	for i in PIECES.size():
		var holder := Node2D.new()
		holder.position = _slot_rect(i).get_center() + Vector2(0, 2)
		add_child(holder)
		_build_icon(holder, PIECES[i][0])
	_name_label = Label.new()
	_name_label.visible = false
	_name_label.z_index = 5
	if font:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", KEY_COL)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_name_label)
	var bs := get_node("/root/BuildSystem")
	bs.build_mode_changed.connect(_on_build_mode)
	bs.ui_rects.append(get_global_rect)


func _on_build_mode(t: int) -> void:
	_current = t
	queue_redraw()


func _slot_rect(i: int) -> Rect2:
	return Rect2(Vector2(i * (SLOT.x + GAP), 0), SLOT)


func _slot_at(p: Vector2) -> int:
	for i in PIECES.size():
		if _slot_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _slot_at(event.position)
		if h != _hover:
			_hover = h
			_name_label.visible = h >= 0
			if h >= 0:
				_name_label.text = PIECES[h][2]
				_name_label.reset_size()
				_name_label.position = Vector2(clampf(_slot_rect(h).get_center().x - _name_label.size.x / 2, 0, size.x - _name_label.size.x), -30)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _slot_at(event.position)
		if i >= 0:
			var t: int = PIECES[i][0]
			get_node("/root/BuildSystem")._set_build(0 if t == _current else t)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		_name_label.visible = false
		queue_redraw()


func _draw() -> void:
	for i in PIECES.size():
		var r := _slot_rect(i)
		var on: bool = PIECES[i][0] == _current
		draw_rect(r, RIM_ON if on else RIM)
		draw_rect(r.grow(-2), DARK)
		draw_rect(r.grow(-3), WELL.lightened(0.12) if i == _hover and not on else WELL)
		if font:
			var k: String = PIECES[i][1]
			draw_string(font, r.position + Vector2(5, 15), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
			draw_string(font, r.position + Vector2(4, 14), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RIM_ON if on else KEY_COL)


# ── icons: each piece's own sprites, fitted into the slot ───────────────

func _part(holder: Node2D, path: String, region: Rect2, at: Vector2, flip := false) -> void:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	if region.size != Vector2.ZERO:
		s.region_enabled = true
		s.region_rect = region
	s.position = at
	s.flip_h = flip
	holder.add_child(s)


func _build_icon(slot: Node2D, t: int) -> void:
	var art := Node2D.new()
	slot.add_child(art)
	var S := "res://assets/sprites/"
	match t:
		1:
			_part(art, S + "trampoline_top.png", Rect2(0, 0, 48, 28), Vector2(-24, -12))
			_part(art, S + "trampoline_base.png", Rect2(), Vector2(-14, 12))
		2:
			_part(art, S + "tapper.png", Rect2(0, 0, 40, 46), Vector2(-20, -30))
		3:
			_part(art, S + "electrode.png", Rect2(), Vector2(-26, -10))
			_part(art, S + "electrode.png", Rect2(), Vector2(10, -10), true)
			var arc := Line2D.new()
			arc.points = PackedVector2Array([Vector2(-10, 0), Vector2(-5, -3), Vector2(0, 2), Vector2(5, -2), Vector2(10, 0)])
			arc.width = 2.0
			arc.default_color = Color(0.75, 0.97, 1.0)
			art.add_child(arc)
		4:
			_part(art, S + "upstream-sprite.png", Rect2(), Vector2(-24, -64))
		5:
			_part(art, S + "hopper_back.png", Rect2(), Vector2(-32, -36))
			_part(art, S + "hopper_front.png", Rect2(), Vector2(-32, -36))
		6:
			_part(art, S + "turret_back.png", Rect2(), Vector2(-30, -46))
			_part(art, S + "turret_front.png", Rect2(), Vector2(-30, -46))
			_part(art, S + "turret_barrel.png", Rect2(), Vector2(-5, 28))
		7:
			_part(art, S + "spikes.png", Rect2(), Vector2(-8, -8))
		15:
			_part(art, S + "wheel_stand.png", Rect2(), Vector2(-25, -6))
			_part(art, S + "gravity_wheel.png", Rect2(), Vector2(-33, -33))
		14:
			_part(art, S + "pendulum_hub.png", Rect2(), Vector2(-8, -30))
			_part(art, S + "wrecking_ball.png", Rect2(), Vector2(-13, -8))
		13:
			_part(art, S + "bellows.png", Rect2(0, 0, 36, 24), Vector2(-12, -12))
		8:
			_part(art, S + "catapult_base.png", Rect2(), Vector2(-18, -12))
			_part(art, S + "catapult_arm.png", Rect2(), Vector2(-4, -6))
		9, 10, 11, 12:
			var n: Node2D = load(["res://scenes/chute.tscn", "res://scenes/splitter.tscn", "res://scenes/bumper.tscn", "res://scenes/belt.tscn"][t - 9]).instantiate()
			n.set_meta("ghost", true)   # no physics, just the drawing
			n.set_process_input(false)
			if t == 9:
				n.end_offset = Vector2(56, 24)
				n.position = Vector2(-28, -12)
			elif t == 12:
				n.end_offset = Vector2(56, -16)
				n.position = Vector2(-28, 8)
			art.add_child(n)
	# fit: small pieces at 1:1 (crisp), big ones scaled down smoothly
	var box := _bounds(art)
	var k := minf(1.0, minf(ICON_BOX.x / box.size.x, ICON_BOX.y / box.size.y))
	if t == 7:
		k = 2.0   # spikes are tiny: show them at 2x
	elif t == 10:
		k = 1.3
	elif t == 11:
		k = 1.4
	art.scale = Vector2(k, k)
	art.position = -box.get_center() * k
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if k >= 1.0 else CanvasItem.TEXTURE_FILTER_LINEAR


func _bounds(art: Node2D) -> Rect2:
	var r := Rect2()
	var first := true
	for c in art.get_children():
		var cr: Rect2
		if c is Sprite2D:
			var sz: Vector2 = c.region_rect.size if c.region_enabled else c.texture.get_size()
			cr = Rect2(c.position, sz)
		elif c is Line2D:
			cr = Rect2(c.points[0], Vector2(20, 5))
		elif c.has_method("_on_touch"):
			cr = Rect2(c.position + Vector2(-11, -27), Vector2(22, 27))
		elif "end_offset" in c:
			cr = Rect2(c.position + Vector2(0, minf(0.0, c.end_offset.y) - 8), Vector2(56, absf(c.end_offset.y) + 12))
		else:
			cr = Rect2(c.position + Vector2(-18, -18), Vector2(36, 26))
		r = cr if first else r.merge(cr)
		first = false
	return r
