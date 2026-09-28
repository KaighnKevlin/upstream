extends Node2D
## Caltrop spreader: a squat iron drum on the ground with a hopper on top
## and a spinning spout on one side (click to flip). Every piece dropped in
## the hopper is beaten into caltrops (iron makes 4, copper 3, grit 1) that
## the spout flings out low across the floor, 30-140 px toward its side.
## A walker that treads on one takes a spike and limps a while. Up to CAP
## lie out at once (the oldest go). Feed it and the approach stays sown.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const CALTROP := preload("res://scenes/caltrop.gd")
const CAP := 24
const MAKES := {"iron": 4, "copper": 3, "grit": 1, "shot": 2}
const NEAR := 30.0               # the throw's range, px from the drum
const FAR := 140.0
const GAP := 0.12                # s between throws

@export var side := 1

var thrown := 0                  # tests
var took := 0
var _queue := 0                  # caltrops made, waiting for the spout
var _cool := 0.0
var _live: Array = []            # our caltrops on the floor, oldest first
var _whirl := 0.0                # the spinner's speed, turns/s
var _turn := 0.0
var _spout_art: Sprite2D         # art: the spout + spinner, 4 frames


func _ready() -> void:
	z_index = 1
	# the sprites first, so ghosts and build-bar icons get them too (see
	# tools/art/gen_caltrop_spreader.py)
	_spout_art = _spr(preload("res://assets/sprites/caltrop_spreader_spout.png"), Vector2(10, -7), Vector2(-1, -6))
	_spout_art.hframes = 4
	_spr(preload("res://assets/sprites/caltrop_spreader.png"), Vector2.ZERO, Vector2(-14, -32))
	_face()
	if has_meta("ghost"):
		return
	_snap_to_floor()


func _spr(tex: Texture2D, at: Vector2, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _face() -> void:
	side = 1 if side >= 0 else -1
	_spout_art.position = Vector2(10 * side, -7)
	_spout_art.scale.x = side


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
	return global_position + Vector2(0, -26)


func _nozzle() -> Vector2:
	return global_position + Vector2(21 * side, -6.5)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.has_meta("store_material"):
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 8.0 and p.y > -32 and p.y < -18:
			var k: String = o.kind if "kind" in o else "copper"
			_queue += MAKES.get(k, 3)
			took += 1
			o.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.8)
	_cool -= delta
	if _queue > 0:
		_whirl = move_toward(_whirl, 6.0, delta * 30.0)
		if _cool <= 0.0:
			_cool = GAP
			_queue -= 1
			_throw()
	else:
		_whirl = move_toward(_whirl, 0.0, delta * 4.0)
	_turn = fmod(_turn + _whirl * delta, 1.0)
	_spout_art.frame = int(_turn * 16.0) % 4   # 4 vanes: a frame is 1/16 turn


func _throw() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	var d := randf_range(NEAR, FAR)
	var to := Vector2(global_position.x + side * d, global_position.y)
	if tm:
		to = _landing(tm, d)
	var c: Node2D = CALTROP.new()
	get_parent().add_child(c)
	c.fling(_nozzle(), to, 6.0 + absf(to.x - global_position.x) * 0.1)
	c.add_to_group("caltrops")
	_live = _live.filter(func(x): return is_instance_valid(x) and not x.spent)
	_live.append(c)
	thrown += 1
	while _live.size() > CAP:
		var old = _live.pop_front()
		if is_instance_valid(old):
			old.vanish()
	SFX.play_small(self, SFX.sfx_clink(), -16.0, randf_range(1.8, 2.4))


## Where a throw `d` px out comes down: short of any wall in the way, on
## the floor there (a step up or a few tiles down).
func _landing(tm: TileMapLayer, d: float) -> Vector2:
	var y := global_position.y - 10.0
	var x := global_position.x
	var step := 6.0
	var went := 12.0
	while went < d:
		var nx := global_position.x + side * minf(went + step, d)
		if tm.get_cell_source_id(tm.local_to_map(tm.to_local(Vector2(nx, y)))) != -1:
			break
		went += step
		x = nx
	var cell := tm.local_to_map(tm.to_local(Vector2(x, y)))
	for i in 10:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	return Vector2(x, tm.to_global(tm.map_to_local(cell)).y + 8)


func live_count() -> int:
	var n := 0
	for c in _live:
		if is_instance_valid(c) and not c.spent:
			n += 1
	return n


func _exit_tree() -> void:
	if has_meta("ghost"):
		return
	for c in _live:
		if is_instance_valid(c):
			c.vanish()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -8)) < 12:
		side = -side
		_face()
		get_viewport().set_input_as_handled()
