extends Node2D
## Spring trap: a hinged plate set flush in the ground over a coiled
## spring, held down by a catch. The first walker to step on it is flung
## high into the air and back the way it came (landing hard). Then the plate
## stands sprung, and it takes pieces to cock it again: each one dropped
## into the little hopper beside it winds the spring down a notch, and
## LOADS set it. A choke point your marble line keeps re-arming.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const W := 26.0
const LOADS := 2
const FLING := Vector2(240, -460)
const DAMAGE := 3

var armed := true
var flung := 0                   # tests
var _load := 0
var _spring := 0.0               # 0 cocked .. 1 sprung (the plate's tilt)
var _plate_art: Sprite2D         # art: the plate, turned about its hinge
var _spring_art: Sprite2D        # art: the coil, a frame per step of _spring


func _ready() -> void:
	z_index = 1
	# the sprites first, so ghosts and build-bar icons get them too (see
	# tools/art/gen_spring_trap.py); the load lights stay in _draw
	_spr(preload("res://assets/sprites/spring_trap_base.png"), Vector2.ZERO, Vector2(-17, -3))
	_spring_art = _spr(preload("res://assets/sprites/spring_trap_spring.png"), Vector2.ZERO, Vector2(-6, -18))
	_spring_art.hframes = 8
	_plate_art = _spr(preload("res://assets/sprites/spring_trap_plate.png"), Vector2(-W * 0.5, 0), Vector2(-2, -3))
	_spr(preload("res://assets/sprites/spring_trap_hopper.png"), Vector2(W * 0.5 + 9, -8), Vector2(-8, -11))
	_pose()
	if has_meta("ghost"):
		return
	_snap_to_floor()
	add_to_group("triggerable")


func _spr(tex: Texture2D, at: Vector2, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


## Tip the plate and stretch the spring to match _spring.
func _pose() -> void:
	_plate_art.rotation = -0.9 * _spring
	_spring_art.frame = clampi(roundi(_spring * 7.0), 0, 7)


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


func _hopper() -> Vector2:
	return global_position + Vector2(W * 0.5 + 9, -8)


## A tripwire or bell can spring it too (flinging whoever's on it).
func trigger() -> void:
	if armed:
		_spring_it()


func _spring_it() -> void:
	armed = false
	_load = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var p: Vector2 = e.global_position - global_position
		if absf(p.x) < W * 0.5 + 6 and p.y > -30 and p.y < 6:
			var back := -signf(e.direction) if "direction" in e and e.direction != 0 else signf(p.x)
			if e.has_method("knock"):
				e.knock(Vector2(back * FLING.x, FLING.y))
			if e.has_method("take_damage"):
				e.take_damage(DAMAGE)
			flung += 1
	var pl := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if pl and absf(pl.global_position.x - global_position.x) < W * 0.5 + 6 and absf(pl.global_position.y - global_position.y) < 30 and pl.has_method("launch"):
		pl.launch(Vector2(0, -520))
	FX.burst(get_parent(), global_position + Vector2(0, -4), Color(0.55, 0.45, 0.35), 10, 120.0, 0.35, 2.0)
	SFX.play(get_tree().current_scene, SFX.sfx_latch(), 0.0, 0.5)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_spring = move_toward(_spring, 0.0 if armed else 1.0, delta * (12.0 if not armed else 2.0))
	_pose()
	if armed:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or ("_dying" in e and e._dying):
				continue
			var p: Vector2 = e.global_position - global_position
			if absf(p.x) < W * 0.5 and p.y > -24 and p.y < 6:
				_spring_it()
				break
	else:
		for o in get_tree().get_nodes_in_group("ore"):
			if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(_hopper()) < 8.0:
				o.queue_free()
				_load += 1
				SFX.play_small(self, SFX.sfx_ratchet(), -10.0, 1.1)
				if _load >= LOADS:
					armed = true
					SFX.play_small(self, SFX.sfx_latch(), -8.0, 1.4)
					break
	queue_redraw()


func _draw() -> void:
	# the frame, plate, spring and hopper are sprites (see _ready); here just
	# the hopper's load lights, one per piece fed in
	var brass := Color(0.85, 0.65, 0.35)
	var hp := _hopper() - global_position
	for i in LOADS:
		var lit := armed or i < _load
		draw_rect(Rect2(hp.x - 5 + i * 6, hp.y - 9, 4, 2), brass if lit else Color(0.25, 0.22, 0.2))
