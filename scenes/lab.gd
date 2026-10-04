extends Node2D
## Research lab: drop science flasks into its funnel; it pours them into
## the bell jar and works them into the selected research (faster when a
## gravity wheel drives it). Each level of a tech costs a few flasks; the
## upgrade applies at once to every machine it affects (scripts/tech.gd).
## Click it to open the research screen. Anything that isn't a flask is spat
## back out.
## Factory mode (main.factory): it works on a Tech.TREE tech instead
## (tree_id), whose cost can be several kinds of science ({flask: 5,
## flask_clock: 5}); it takes only flasks that tech still needs, and when
## every kind is paid the tech is researched, its pieces unlock on the build
## bar (main.refresh_unlocks) and it moves on to the next it can do.
## Art: tools/art/gen_lab.py (4 frames of 48x58, feet at the bottom).

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

const HOLD := 8
const WORK := 2.5            # seconds per flask at full power

@export var research := 0    # index into Tech.TECHS
@export var tree_id := ""    # Factory: the Tech.TREE tech being researched ("" none)

var _flasks := 0
var _held := {}              # Factory: science kind -> flasks waiting in the jar
var _kind := ""              # Factory: the kind of the flask being worked
var _work := 0.0
var _spr: AnimatedSprite2D
var _label: Label
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
static var progress := {}    # tech id -> flasks put into the current level
static var tree_progress := {}   # Factory: TREE tech id -> {science kind: flasks put in}


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
	if _tree_mode() and not Tech.researchable(tree_id):
		_pick_tree()
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


## Factory rules: research the unlock tree, not the upgrades.
func _tree_mode() -> bool:
	if not is_inside_tree():
		return false
	var m := get_tree().current_scene
	return m != null and m.get("factory") == true


## The first tree tech this lab can take on ("" when there's none yet).
func _pick_tree() -> void:
	tree_id = ""
	for t in Tech.TREE:
		if Tech.researchable(t.id):
			tree_id = t.id
			return


## "2/5", or per kind "r 2/5 c 0/5".
func tree_cost_text(id: String) -> String:
	var cost := Tech.cost_of(Tech.tree_tech(id))
	var prog: Dictionary = tree_progress.get(id, {})
	var parts := []
	for k in cost:
		var n := "%d/%d" % [prog.get(k, 0), cost[k]]
		parts.append(n if cost.size() == 1 else "%s %s" % [Tech.kind_name(k).left(1), n])
	return " ".join(parts)


func _update_label() -> void:
	if _label == null:
		return
	if _tree_mode():
		if tree_id == "":
			_label.text = "click: pick research"
		else:
			_label.text = "%s  [%s]" % [Tech.title(Tech.tree_tech(tree_id)), tree_cost_text(tree_id)]
		return
	var t := _tech()
	if Tech.maxed(t.id):
		_label.text = "%s: done" % t.name
	else:
		_label.text = "%s %d  [%d/%d]" % [t.name, Tech.level(t.id) + 1, progress.get(t.id, 0), t.cost]


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if _tree_mode():
		var k = b.get("kind")
		if k is String and _wants(k):
			_held[k] = _held.get(k, 0) + 1
			b.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("ore"), -8.0, 1.4)
		else:
			(b as RigidBody2D).linear_velocity = Vector2(-120.0, -220.0)
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
	if _tree_mode():
		_tree_tick(delta)
		return
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


## Factory: does the tech on hand still need a flask of this kind (counting
## those put in, waiting and being worked)?
func _wants(kind: String) -> bool:
	if tree_id == "" or Tech.researched(tree_id):
		return false
	var cost := Tech.cost_of(Tech.tree_tech(tree_id))
	if not cost.has(kind):
		return false
	var waiting := 0
	for k in _held:
		waiting += _held[k]
	if waiting >= HOLD:
		return false
	var have: int = tree_progress.get(tree_id, {}).get(kind, 0) + _held.get(kind, 0) + (1 if _work > 0 and _kind == kind else 0)
	return have < int(cost[kind])


func _tree_tick(delta: float) -> void:
	if tree_id != "" and Tech.researched(tree_id):
		# done by another lab: a flask part-worked goes back in the jar
		if _work > 0 and _kind != "":
			_held[_kind] = _held.get(_kind, 0) + 1
		_work = 0.0
		tree_id = ""
	if tree_id == "":
		if _rate_t == 0.25:   # just refreshed: look for one now and then
			_pick_tree()
			_update_label()
		if tree_id == "":
			_spr.stop()
			return
	var t := Tech.tree_tech(tree_id)
	var cost := Tech.cost_of(t)
	var prog: Dictionary = tree_progress.get(tree_id, {})
	if _work <= 0:
		_kind = ""
		for k in cost:
			if _held.get(k, 0) > 0 and prog.get(k, 0) < int(cost[k]):
				_kind = k
				break
		if _kind == "":
			_spr.stop()
			return
		_held[_kind] -= 1
		_work = WORK
		_spr.play()
	_work -= delta * _rate
	_spr.speed_scale = 0.5 + _rate
	if _work > 0:
		return
	prog[_kind] = prog.get(_kind, 0) + 1
	tree_progress[tree_id] = prog
	FX.burst(get_parent(), global_position + Vector2(0, -40), Color(1.0, 0.55, 0.4, 0.8), 5, 30.0, 0.6, 1.8, -40.0)
	var done := true
	for k in cost:
		if prog.get(k, 0) < int(cost[k]):
			done = false
	if done:
		_finish_tree(t)
	_update_label()


func _finish_tree(t: Dictionary) -> void:
	tree_progress.erase(t.id)
	Tech.levels[t.id] = 1
	SFX.play(self, SFX.sfx_ammo_received())
	var main := get_tree().current_scene
	if main.has_method("refresh_unlocks"):
		main.refresh_unlocks()
	if main.has_method("_show_banner"):
		var names := Tech.unlock_names(t)
		main._show_banner("UNLOCKED", "%s: %s" % [Tech.title(t), ", ".join(names)] if not names.is_empty() else "%s (no pieces yet)" % Tech.title(t))
	_pick_tree()


func _input(event: InputEvent) -> void:
	if _intake == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(-16, -46, 32, 44).has_point(to_local(Pointer.world(self))):
			open_panel()
			get_viewport().set_input_as_handled()


## The research screen (scripts/tech_panel.gd), for this lab.
func open_panel() -> void:
	var scene := get_tree().current_scene
	var panel := scene.get_node_or_null("TechPanel")
	if panel == null:
		panel = preload("res://scripts/tech_panel.gd").new()
		panel.name = "TechPanel"
		scene.add_child(panel)
	panel.open(self)
