extends CanvasLayer
## The research screen. Clicking a lab opens it: every tech with its level
## pips, what it does, its flask cost and the flasks already put into the
## next level. The one this lab is working on is highlighted; click a tech
## to set the lab to it. Esc, or a click outside, closes it.

const Tech = preload("res://scripts/tech.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const SFX = preload("res://scripts/sfx.gd")

const TEXT := Color(0.95, 0.88, 0.7)
const DIM := Color(0.7, 0.64, 0.52)
const DONE := Color(0.55, 0.85, 0.6)
const PIP_ON := Color(0.45, 0.85, 0.95)
const PIP_OFF := Color(0.25, 0.22, 0.2)
const ROW_H := 44.0
const COL_W := 330.0

var _lab: Node = null
var _root: Control
var _rows: Array[Control] = []


func _ready() -> void:
	layer = 6
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_backdrop_input)
	add_child(_root)


func open(lab: Node) -> void:
	_lab = lab
	_build()
	visible = true
	SFX.play(lab, SFX.sfx_clink())


func close() -> void:
	visible = false
	_lab = null


func _label(text: String, at: Vector2, size: int, color: Color, parent: Control, width := 300.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = at
	l.size = Vector2(width, size + 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	_rows.clear()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var n := Tech.TECHS.size()
	var rows := int(ceil(n / 2.0))
	var size := Vector2(COL_W * 2 + 40, rows * ROW_H + 78)
	var at := (Vector2(1280, 720) - size) * 0.5
	var p := NinePatchRect.new()
	p.texture = preload("res://assets/ui/panel.png")
	p.patch_margin_left = 8
	p.patch_margin_top = 8
	p.patch_margin_right = 8
	p.patch_margin_bottom = 8
	p.position = at
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_label("RESEARCH", at + Vector2(20, 14), 20, TEXT, _root)
	_label("click a tech to set this lab to it  -  flasks go into the chosen tech", at + Vector2(170, 20), 10, DIM, _root, 480.0)
	var cur: int = _lab.research if _lab else -1
	for i in n:
		var t: Dictionary = Tech.TECHS[i]
		var col := i % 2
		var row := i / 2
		var r := Control.new()
		r.position = at + Vector2(20 + col * (COL_W + 0), 50 + row * ROW_H)
		r.size = Vector2(COL_W - 10, ROW_H - 4)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.gui_input.connect(_on_row_input.bind(i))
		_root.add_child(r)
		_rows.append(r)
		var bg := ColorRect.new()
		bg.size = r.size
		bg.color = Color(0.45, 0.36, 0.22, 0.55) if i == cur else Color(0.12, 0.1, 0.09, 0.55)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(bg)
		var lvl := Tech.level(t.id)
		var maxed := Tech.maxed(t.id)
		_label(t.name, Vector2(8, 4), 10, DONE if maxed else TEXT, r)
		_label(t.desc, Vector2(8, 22), 10, DIM, r, COL_W - 20)
		for k in int(t.max):
			var pip := ColorRect.new()
			pip.position = Vector2(COL_W - 90 + k * 12, 7)
			pip.size = Vector2(8, 8)
			pip.color = PIP_ON if k < lvl else PIP_OFF
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.add_child(pip)
		var prog: int = preload("res://scenes/lab.gd").progress.get(t.id, 0)
		_label("done" if maxed else "%d/%d" % [prog, int(t.cost)], Vector2(COL_W - 90 + int(t.max) * 12 + 6, 4), 10, DONE if maxed else DIM, r, 60.0)


func _on_row_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _lab and is_instance_valid(_lab) and not Tech.maxed(Tech.TECHS[i].id):
			_lab.research = i
			_lab._update_label()
			SFX.play(_lab, SFX.sfx_clink())
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
