extends Node2D
## Research lab: drop science flasks into its funnel; it pours them into
## the bell jar and works them into the selected research (faster when a
## gravity wheel drives it). Each level of a tech costs a few flasks; the
## upgrade applies at once to every machine it affects (scripts/tech.gd).
## Click it to pick what to research. Anything that isn't a flask is spat
## back out.
## Art: tools/art/gen_lab.py (4 frames of 48x58, feet at the bottom).

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

const HOLD := 8
const WORK := 2.5            # seconds per flask at full power

@export var research := 0    # index into Tech.TECHS

var _flasks := 0
var _work := 0.0
var _spr: AnimatedSprite2D
var _label: Label
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
static var progress := {}    # tech id -> flasks put into the current level


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/lab.png")
	sf.set_animation_speed("default", 6.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 48, 0, 48, 58)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-24, -57)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_label = Label.new()
	_label.add_theme_font_override("font", PixelFont.get_font())
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, -76)
	_label.size = Vector2(120, 14)
	_label.z_index = 5
	add_child(_label)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for seg in [[Vector2(-19, -56), Vector2(-14, -48)], [Vector2(-3, -56), Vector2(-8, -48)]]:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = seg[0]
		sh.b = seg[1]
		cs.shape = sh
		body.add_child(cs)
	var jar := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	jar.shape = c
	jar.position = Vector2(0, -27)
	body.add_child(jar)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(8, 6)
	ic.shape = ir
	ic.position = Vector2(-11, -50)
	_intake.add_child(ic)
	add_child(_intake)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)
	_pick_unfinished()
	_update_label()


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func _tech() -> Dictionary:
	return Tech.TECHS[research]


func _pick_unfinished() -> void:
	for k in Tech.TECHS.size():
		if not Tech.maxed(Tech.TECHS[(research + k) % Tech.TECHS.size()].id):
			research = (research + k) % Tech.TECHS.size()
			return


func _update_label() -> void:
	if _label == null:
		return
	var t := _tech()
	if Tech.maxed(t.id):
		_label.text = "%s: done" % t.name
	else:
		_label.text = "%s %d  [%d/%d]" % [t.name, Tech.level(t.id) + 1, progress.get(t.id, 0), t.cost]


func _on_intake(b: Node2D) -> void:
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.get("kind") == "flask" and _flasks < HOLD:
		_flasks += 1
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("ore"), -8.0, 1.4)
	else:
		(b as RigidBody2D).linear_velocity = Vector2(-120.0, -220.0)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var t := _tech()
	if Tech.maxed(t.id):
		_spr.stop()
		return
	if _work <= 0:
		if _flasks <= 0:
			_spr.stop()
			return
		_flasks -= 1
		_work = WORK
		_spr.play()
	_work -= delta * _rate
	_spr.speed_scale = 0.5 + _rate
	if _work <= 0:
		progress[t.id] = progress.get(t.id, 0) + 1
		FX.burst(get_parent(), global_position + Vector2(0, -40), Color(1.0, 0.55, 0.4, 0.8), 5, 30.0, 0.6, 1.8, -40.0)
		if progress[t.id] >= int(t.cost):
			progress[t.id] = 0
			Tech.levels[t.id] = Tech.level(t.id) + 1
			SFX.play(self, SFX.sfx_ammo_received())
			var main := get_tree().current_scene
			if main.has_method("_show_banner"):
				main._show_banner("RESEARCHED", "%s %d: %s" % [t.name, Tech.level(t.id), t.desc])
			if Tech.maxed(t.id):
				_pick_unfinished()
		_update_label()


func _input(event: InputEvent) -> void:
	if _intake == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(-16, -46, 32, 44).has_point(to_local(get_global_mouse_position())):
			research = (research + 1) % Tech.TECHS.size()
			_update_label()
			SFX.play(self, SFX.sfx_clink())
			get_viewport().set_input_as_handled()
