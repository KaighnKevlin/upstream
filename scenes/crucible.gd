extends Node2D
## Crucible: a clay pot in an iron tripod, for bronze. A HOT copper ingot
## and a HOT iron ingot in the pot at the same time fuse, and a bronze bar
## pours out of the tap on the `side` end (a bronze bar is worth three
## repair stock in the dome). Each bar waits in the pot only while it stays
## hot: ingots cool over Ingot.COOL s from the smelter, so one kept waiting
## too long for its partner is tipped out the other end, cold. So is a bar
## that lands in already cold, a second of a kind already waiting, or ore.
## Nothing is lost: what's tipped out is still a good ingot. The puzzle is
## getting the copper and iron lines to arrive hot and together: match the
## lengths of their runs, pair the ore up before it's smelted (a pair gate
## doesn't mind waiting on cold ore), or send what's tipped out back over a
## furnace rail to heat it up again.
## Feet on the floor or a ledge, under the ends of two runs; click the pot
## to turn it round.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")
const INGOT := preload("res://scenes/ingot.tscn")

const RIM := -41.0            # the pot's mouth, from the feet
const HALF := 13.0            # mouth half-width
const MELT := 0.6             # s from a pair fusing to the bronze pouring
const TIP := Vector2(90, -120)   # a reject's toss (x to the -side end)
const POUR := Vector2(70, -30)   # the bronze out of the tap (x to the side end)
const COLORS := {"copper": Color(0.95, 0.6, 0.3), "iron": Color(0.7, 0.74, 0.8)}

## Which end the bronze pours from: 1 right, -1 left. Rejects go the other way.
@export var side := 1.0
## What fuses into one bronze bar: kind -> how many, all hot at once.
@export var need := {"copper": 1, "iron": 1}

var made := 0                 # bronze poured (tests)
var rejected := 0             # landed cold, surplus, or not an ingot we take (tests)
var cooled := 0               # went cold waiting in the pot (tests)
var events: Array = []        # [kind, heat, what] for each piece in: taken/cold/surplus/other/cooled (tests)
var _held: Array = []         # the bars waiting, in the pot
var _cool := {}               # id -> time it may be taken again (just tipped out)
var _melt := -1.0             # 0..MELT while a pour runs; < 0 idle
var _flash := 0.0
var _intake: Area2D
var _light: PointLight2D
var _spr: Sprite2D


func _ready() -> void:
	z_index = 2               # over the bars waiting in the pot
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/crucible.png")   # tools/art/gen_crucible.py
	_spr.centered = false
	_spr.offset = Vector2(-20, -46)
	_spr.flip_h = side < 0
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.show_behind_parent = true
	add_child(_spr)
	queue_redraw()
	if has_meta("ghost"):
		return
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2, 18)
	ic.shape = r
	ic.position = Vector2(0, RIM - 5)
	_intake.add_child(ic)
	add_child(_intake)
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(64)
	_light.texture_scale = 1.8
	_light.color = Color(1.0, 0.55, 0.2)
	_light.energy = 0.0
	_light.position = Vector2(0, RIM)
	add_child(_light)


func _count(k: String) -> int:
	return _held.filter(func(b): return b.kind == k).size()


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_held = _held.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	for b in _intake.get_overlapping_bodies():
		if not (b is RigidBody2D) or b.is_queued_for_deletion() or b.freeze or b in _held:
			continue
		if _cool.get(b.get_instance_id(), 0.0) > now or not Hold.free_to_take(b, self):
			continue
		var k = b.get("kind")
		if b.is_in_group("ingots") and need.has(k) and b.is_hot() and _count(k) < need[k]:
			_held.append(b)
			Hold.claim(b, self)
			b.gravity_scale = 0.0
			events.append([k, b.heat, "taken"])
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.7)
		else:
			rejected += 1
			var why := "other"
			if b.is_in_group("ingots") and need.has(k):
				why = "cold" if not b.is_hot() else "surplus"
			events.append([k, b.get("heat") if b.get("heat") != null else 0.0, why])
			_tip(b, now)
	# a bar that went cold waiting is no good to the pour: out it goes
	for b in _held.duplicate():
		if not b.is_hot():
			_held.erase(b)
			cooled += 1
			events.append([b.kind, 0.0, "cooled"])
			_tip(b, now)
	# all there and all hot: they fuse
	if _melt < 0 and need.keys().all(func(k): return _count(k) >= need[k]):
		for k in need:
			for i in need[k]:
				var b = _held.filter(func(x): return x.kind == k)[0]
				_held.erase(b)
				b.queue_free()
		_melt = 0.0
		_flash = 1.0
		FX.burst(get_parent(), global_position + Vector2(0, RIM), Color(1.0, 0.75, 0.3), 10, 70.0, 0.4, 1.5, 300.0)
		SFX.play_small(self, SFX.sfx_hiss(), -10.0, 1.2)
	if _melt >= 0:
		_melt += delta
		if _melt >= MELT:
			_melt = -1.0
			_pour()
	# the rest wait in the pot, side by side, stacked up
	var i := 0
	for b in _held:
		var at := global_position + Vector2(-5 + 10 * (i % 2), RIM + 14 - 7 * int(i / 2.0))
		Hold.claim(b, self)
		b.linear_velocity = (at - b.global_position) / delta
		b.angular_velocity = 0.0
		b._timer = 0.0
		i += 1
	_flash = maxf(0.0, _flash - delta * 2.0)
	var glow := _flash
	for b in _held:
		glow = maxf(glow, b.heat * 0.6)
	if _melt >= 0:
		glow = 1.0
	_light.energy = 0.6 * glow
	queue_redraw()


func _tip(b: RigidBody2D, now: float) -> void:
	Hold.release(b, self)
	b.sleeping = false
	b.global_position.y = minf(b.global_position.y, global_position.y + RIM - 10)
	b.linear_velocity = Vector2(-side * TIP.x, TIP.y)
	_cool[b.get_instance_id()] = now + 1.0
	SFX.play_small(self, SFX.sfx_clink(), -14.0, 0.8)


func _pour() -> void:
	made += 1
	var o: RigidBody2D = INGOT.instantiate()
	o.kind = "bronze"
	o.global_position = global_position + Vector2(side * 22, -20)
	o.linear_velocity = Vector2(side * POUR.x, POUR.y)
	get_tree().current_scene.add_child(o)
	FX.burst(get_parent(), o.global_position, Color(1.0, 0.7, 0.3), 8, 60.0, 0.4, 1.4, 350.0)
	SFX.play_small(self, SFX.sfx_thud(), -10.0, 1.4)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	var p := to_local(Pointer.world(self))
	if absf(p.x) < HALF + 3 and p.y > RIM - 3 and p.y < -14:
		side = -side
		_spr.flip_h = side < 0
		SFX.play(self, SFX.sfx_clink())
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	# the pot and stand are the sprite; on it, what's molten in the mouth,
	# a pip per bar the recipe wants (lit as bright as that bar is hot),
	# and a chevron at the tap end
	var dark := Color(0.1, 0.08, 0.07)
	var o := Vector2(side * 21, -12)
	var brass := Color(0.85, 0.65, 0.35)
	draw_line(o + Vector2(-side * 3, -3), o, brass, 1.0)
	draw_line(o + Vector2(-side * 3, 3), o, brass, 1.0)
	if _intake == null:
		return
	if _melt >= 0 or _flash > 0:
		var m := clampf(maxf(_flash, 1.0 if _melt >= 0 else 0.0), 0.0, 1.0)
		draw_rect(Rect2(-11, RIM - 1, 22, 2), Color(1.0, 0.75, 0.35, m))
	var slots := []
	for k in need:
		for n in need[k]:
			slots.append(k)
	var x0 := -(slots.size() * 6 - 2) / 2.0
	var taken := {}
	for j in slots.size():
		var k: String = slots[j]
		var p := Vector2(x0 + j * 6, -30)
		draw_rect(Rect2(p, Vector2(4, 4)), dark)
		var got = null
		for b in _held:
			if b.kind == k and not taken.has(b):
				got = b
				break
		if got != null:
			taken[got] = true
			var c: Color = COLORS.get(k, Color.WHITE)
			draw_rect(Rect2(p + Vector2(0.5, 0.5), Vector2(3, 3)), c.lerp(Color(1.0, 0.85, 0.5), got.heat * 0.5) * Color(1, 1, 1, 0.35 + 0.65 * got.heat))
