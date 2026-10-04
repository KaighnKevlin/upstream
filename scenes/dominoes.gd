extends Node2D
## Domino row: drag from one end to the other and a line of brass slabs
## stands along the ground, every SPACING px. They're real bodies: knock
## the first one over (a thrown chunk, a bumper, a walker blundering in, a
## fan's gust) and they go down one after another, and the last can land
## on a pressure plate to trip whatever's wired to it. Click either end of
## the row to stand them all back up. Wired to a trigger (a timer, a
## tripwire, a plate) it flicks its own first slab over when it's standing
## and stands back up when it's down, so a timer keeps a row cycling.
## Art: tools/art/gen_domino.py (8x28).

const SFX = preload("res://scripts/sfx.gd")

const LEN_MIN := 30.0
const LEN_MAX := 420.0
const SPACING := 15.0
const SLAB := Vector2(5, 26)
const LAYER := 256               # its own layer: collides with ground, ore, walkers, each other

@export var end_offset := Vector2(150, 0)

var slabs: Array[RigidBody2D] = []
static var _material: PhysicsMaterial


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	add_to_group("dominoes")
	add_to_group("triggerable")
	stand_up.call_deferred()


## A trigger: flick the first slab over, or reset a row that's fallen.
func trigger() -> void:
	if slabs.is_empty():
		return
	if fallen() > slabs.size() / 2:
		stand_up()
		return
	var first: RigidBody2D = slabs[0]
	if is_instance_valid(first) and absf(first.rotation) < 0.3:
		var dir := signf(end_offset.x) if end_offset.x != 0 else 1.0
		first.apply_impulse(Vector2(dir * 40.0, 0), Vector2(0, -12))
		SFX.play_small(first, SFX.sfx_clink(), -8.0, 1.6)


func _ground_y(x: float, from_y: float) -> float:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return from_y
	var cell := tm.local_to_map(tm.to_local(Vector2(x, from_y)))
	for i in 10:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	return tm.to_global(tm.map_to_local(cell)).y + 8


## (Re)build the row: every slab upright on the ground along the line.
func stand_up() -> void:
	for s in slabs:
		if is_instance_valid(s):
			s.queue_free()
	slabs.clear()
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.7
		_material.bounce = 0.02
	var n := int(absf(end_offset.x) / SPACING) + 1
	var dir := signf(end_offset.x) if end_offset.x != 0 else 1.0
	for k in n:
		var x := global_position.x + dir * k * SPACING
		var gy := _ground_y(x, global_position.y + end_offset.y * float(k) / maxf(1, n - 1) - 6)
		var b := RigidBody2D.new()
		b.collision_layer = LAYER
		b.collision_mask = 1 | 2 | 8 | 64 | LAYER
		b.mass = 1.0
		b.physics_material_override = _material
		b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = SLAB
		cs.shape = r
		b.add_child(cs)
		var spr := Sprite2D.new()
		spr.texture = preload("res://assets/sprites/domino.png")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(spr)
		b.global_position = Vector2(x, gy - SLAB.y * 0.5 - 0.5)
		b.z_index = 1
		b.add_to_group("domino_slabs")
		b.body_entered.connect(_clack.bind(b))
		b.contact_monitor = true
		b.max_contacts_reported = 2
		get_parent().add_child(b)
		slabs.append(b)


func _clack(_other, b: RigidBody2D) -> void:
	if is_instance_valid(b) and b.angular_velocity != 0.0 and absf(b.angular_velocity) > 1.0:
		SFX.play_small(b, SFX.sfx_ore_knock("wood"), -16.0, randf_range(1.3, 1.6))


## How many have gone over (tests).
func fallen() -> int:
	var n := 0
	for s in slabs:
		if is_instance_valid(s) and absf(wrapf(s.rotation, -PI, PI)) > 1.0:
			n += 1
	return n


func _draw() -> void:
	if not has_meta("ghost"):
		return
	# the ghost: where the slabs will stand
	var n := int(absf(end_offset.x) / SPACING) + 1
	var dir := signf(end_offset.x) if end_offset.x != 0 else 1.0
	for k in n:
		var p := Vector2(dir * k * SPACING, end_offset.y * float(k) / maxf(1, n - 1))
		draw_rect(Rect2(p + Vector2(-2.5, -26), Vector2(5, 26)), Color(0.85, 0.65, 0.35, 0.7))


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := Pointer.world(self)
		for end in [global_position, global_position + Vector2(end_offset.x, 0)]:
			if absf(m.x - end.x) < 10 and absf(m.y - _ground_y(end.x, end.y - 6) + 13) < 20:
				stand_up()
				SFX.play(self, SFX.sfx_clink())
				get_viewport().set_input_as_handled()
				return


func _exit_tree() -> void:
	for s in slabs:
		if is_instance_valid(s):
			s.queue_free()
