extends Node2D
## Pressure plate: a brass plate sunk flush with the ground. Anything with
## weight pressing on it (ore, a walker, you) trips every linked machine
## within LINK, the same set a tripwire would (tripwire.gd linked_to):
## kegs blow, trapdoors drop, pendulums get kicked, hoppers dump, tesla
## coils overload. It trips once per press: lift off and press again.
## Ore makes it a timer or a switch for contraptions: a belt that delivers
## a chunk onto the plate every few seconds fires whatever it's wired to.
## Art: tools/art/gen_plate.py (2 frames of 26x8: up, pressed).

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")

const REARM := 0.4           # least time between trips

var tripped := 0             # tests
var _spr: AnimatedSprite2D
var _sense: Area2D
var _down := false
var _rearm := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/plate.png")
	for i in 2:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 26, 0, 26, 8)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-13, -7)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("plates")
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 2 | 8 | 32     # ore, walkers, the player
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 6)
	cs.shape = r
	cs.position = Vector2(0, -6)
	_sense.add_child(cs)
	add_child(_sense)


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


func _pressed() -> bool:
	for b in _sense.get_overlapping_bodies():
		if b.has_meta("store_material") or ("_dying" in b and b._dying):
			continue
		return true
	return false


func _physics_process(delta: float) -> void:
	if _sense == null:
		return
	_rearm -= delta
	var now := _pressed()
	if now and not _down and _rearm <= 0:
		trip()
	if now != _down:
		_down = now
		_spr.frame = 1 if now else 0
		if not now:
			SFX.play_small(self, SFX.sfx_clink(), -14.0, 1.7)
	if _build_mode():
		queue_redraw()


func trip() -> void:
	tripped += 1
	_rearm = REARM
	SFX.play_small(self, SFX.sfx_clink(), -4.0, 1.2)
	for n in Tripwire.linked_to(get_tree(), [global_position]):
		n.trigger()


func _build_mode() -> bool:
	var bs := get_node_or_null("/root/BuildSystem")
	return bs != null and bs.current_build != 0


## Links to its machines while you build (like a tripwire's).
func _draw() -> void:
	if has_meta("ghost") or not _build_mode():
		return
	for n in Tripwire.linked_to(get_tree(), [global_position]):
		var d: Vector2 = to_local(n.global_position) - Vector2(0, -4)
		var steps := int(d.length() / 6.0)
		for k in steps:
			if k % 2 == 0:
				draw_line(Vector2(0, -4) + d * (float(k) / steps), Vector2(0, -4) + d * (float(k + 1) / steps), Color(1.0, 0.8, 0.4, 0.45), 1.0)
