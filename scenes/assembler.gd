extends Node2D
## Assembler: drop ingredients into its funnel; when it holds a recipe's
## worth it works them (faster when a gravity wheel drives it) and ejects
## the product from its spout as new loose items, ready for the next part
## of the machine. Anything it can't use is spat back out of the funnel.
## Click it to switch recipe (what it holds is kept).
## Recipes turn smelted ingots into things: iron shot (heavy turret ammo)
## and gears (they roll).
## Art: tools/art/gen_assembler.py (4 frames of 48x60, feet at the bottom).

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const Tech = preload("res://scripts/tech.gd")

## in: ingredient -> count. Ingredients are "<kind>_ingot" for ingots,
## "<kind>" for loose items (ore, shot, gears).
const RECIPES := [
	{"name": "Iron shot", "in": {"iron_ingot": 1}, "out": "shot", "count": 4, "time": 1.2},
	{"name": "Gear", "in": {"iron_ingot": 1, "copper_ingot": 1}, "out": "gear", "count": 1, "time": 1.8},
	{"name": "Science flask", "in": {"gear": 1, "copper_ingot": 1}, "out": "flask", "count": 1, "time": 2.0},
]
const HOLD := 3            # keeps up to this many batches of each ingredient
const SPOUT := Vector2(23, -16)
const EJECT := Vector2(170, -70)

@export var recipe := 0

var made := 0              # items produced (tests)
var _held := {}
var _work := 0.0           # seconds of work left on the current batch; <= 0 idle
var _batch := 0            # the recipe the current batch was started as
var _spr: AnimatedSprite2D
var _icon: Sprite2D
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/assembler.png")
	sf.set_animation_speed("default", 8.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 48, 0, 48, 60)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-24, -59)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_icon = Sprite2D.new()
	_icon.position = Vector2(0, -14)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.z_index = 1
	add_child(_icon)
	_show_recipe()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	# the cabinet and funnel are solid; the funnel's throat is the intake
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for seg in [[Vector2(-13, -58), Vector2(-5, -43)], [Vector2(13, -58), Vector2(5, -43)]]:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = seg[0]
		sh.b = seg[1]
		cs.shape = sh
		body.add_child(cs)
	var box := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 33)
	box.shape = r
	box.position = Vector2(0, -23.5)
	body.add_child(box)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(14, 8)
	ic.shape = ir
	ic.position = Vector2(0, -46)
	_intake.add_child(ic)
	add_child(_intake)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)


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


func _key(b: Node) -> String:
	var k: String = b.get("kind") if b.get("kind") != null else "copper"
	return k + "_ingot" if b.is_in_group("ingots") else k


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.has_meta("caught_by"):
		return
	var need: Dictionary = RECIPES[recipe]["in"]
	var k := _key(b)
	if need.has(k) and _held.get(k, 0) < need[k] * HOLD:
		_held[k] = _held.get(k, 0) + 1
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -10.0, 0.9)
		queue_redraw()
	else:
		# not for this recipe: the funnel spits it back out
		var side := -1.0 if randf() < 0.5 else 1.0
		(b as RigidBody2D).linear_velocity = Vector2(side * 110.0, -230.0)
		FX.burst(get_parent(), b.global_position, Color(0.85, 0.85, 0.8, 0.7), 4, 40.0, 0.4, 2.0, -30.0)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	if _work > 0:
		_work -= delta * _rate * Tech.mult("assembly")
		_spr.speed_scale = 0.5 + _rate
		if _work <= 0:
			_finish()
		queue_redraw()
		return
	# enough for a batch? start it
	var rec: Dictionary = RECIPES[recipe]
	for k in rec["in"]:
		if _held.get(k, 0) < rec["in"][k]:
			if _spr.is_playing():
				_spr.stop()
			return
	for k in rec["in"]:
		_held[k] -= rec["in"][k]
	_work = rec["time"]
	_batch = recipe
	_spr.play()
	queue_redraw()


func _finish() -> void:
	var rec: Dictionary = RECIPES[_batch]
	SFX.play(self, SFX.sfx_clink())
	for n in rec["count"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = rec["out"]
		o.global_position = to_global(SPOUT) + Vector2(0, randf_range(-1.5, 1.5))
		get_tree().current_scene.add_child(o)
		o.linear_velocity = EJECT + Vector2(randf_range(-25, 25), randf_range(-20, 20))
		made += 1
		if rec["count"] > 1:
			await get_tree().create_timer(0.08).timeout
	FX.burst(get_parent(), to_global(SPOUT), Color(0.85, 0.85, 0.8, 0.7), 4, 40.0, 0.5, 2.0, -40.0)


func _show_recipe() -> void:
	var rec: Dictionary = RECIPES[recipe]
	var tex := load({"shot": "res://assets/sprites/iron_shot.png", "gear": "res://assets/sprites/gear_item.png",
		"flask": "res://assets/sprites/flask.png"}[rec["out"]]) as Texture2D
	_icon.texture = tex
	var k := minf(8.0 / tex.get_width(), 5.0 / tex.get_height()) * 1.0
	_icon.scale = Vector2(k, k) if tex.get_width() > 8 else Vector2.ONE * 0.75
	queue_redraw()


# progress bar under the plate, and pips for what it holds

func _draw() -> void:
	if _intake == null:
		return
	var rec: Dictionary = RECIPES[recipe]
	if _work > 0:
		var f := 1.0 - _work / float(RECIPES[_batch]["time"])
		draw_rect(Rect2(-6, -8, 12, 2), Color(0.09, 0.07, 0.1))
		draw_rect(Rect2(-6, -8, 12 * f, 2), Color(0.45, 0.85, 0.95))
	var x := -13.0
	for k in rec["in"]:
		var have: int = _held.get(k, 0)
		var col := Color(0.62, 0.66, 0.7) if k.begins_with("iron") else Color(0.9, 0.62, 0.3)
		for n in mini(have, 6):
			draw_rect(Rect2(x, -37, 2, 2), col)
			x += 3
		x += 2


func _input(event: InputEvent) -> void:
	if _intake == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := to_local(get_global_mouse_position())
		if Rect2(-16, -42, 32, 38).has_point(p):
			recipe = (recipe + 1) % RECIPES.size()
			_show_recipe()
			SFX.play(self, SFX.sfx_clink())
			get_viewport().set_input_as_handled()
