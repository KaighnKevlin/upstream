extends Node2D
## Trapdoor (X): two hinged iron leaves skinned with turf, laid over a pit.
## You, ore and machines can stand on it; the moment an enemy walker steps
## on, it springs open and drops them in, then winds itself shut again
## (faster when a gravity wheel drives it). Bridge engines and masons take
## it for solid ground, so they neither bridge nor brick the pit under it.
## Place it on the top row of a pit (three tiles wide, centred on the cell).
## Art: tools/art/gen_trapdoor.py.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const HALF := 24.0             # each leaf spans this much
const ARM := 0.12              # delay between a step and the drop
const RESET := 1.1             # seconds to wind shut at full power
const DROP_ANGLE := 1.45

var sprung := 0                # tests
var is_open := false
var _body: StaticBody2D
var _shapes: Array[CollisionShape2D] = []
var _leaves: Array[Sprite2D] = []
var _sense: Area2D
var _arm := -1.0
var _reset := 0.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0


## Snaps a placement point to the top of its tile cell (the build ghost uses this too).
func snap_pos(p: Vector2) -> Vector2:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return p
	var c := tm.to_global(tm.map_to_local(tm.local_to_map(tm.to_local(p))))
	return Vector2(c.x, c.y - 8.0)


func _ready() -> void:
	z_index = 1
	global_position = snap_pos(global_position)
	var fr := Sprite2D.new()
	fr.texture = preload("res://assets/sprites/trapdoor_frame.png")
	fr.centered = false
	fr.offset = Vector2(-28, -1)
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fr)
	for s in [-1.0, 1.0]:
		var l := Sprite2D.new()
		l.texture = preload("res://assets/sprites/trapdoor_leaf.png")
		l.centered = false
		l.flip_h = s > 0
		l.offset = Vector2(-24 if s > 0 else 0, -2)
		l.position = Vector2(s * HALF, 0)
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(l)
		_leaves.append(l)
	if has_meta("ghost"):
		return
	add_to_group("trapdoors")
	add_to_group("power_users")
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	for s in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(HALF, 6)
		cs.shape = r
		cs.one_way_collision = true   # solid from above; what's in the pit can still climb out
		cs.position = Vector2(s * HALF * 0.5, 3)
		_body.add_child(cs)
		_shapes.append(cs)
	add_child(_body)
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 8
	var sc := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(HALF * 2 - 6, 10)
	sc.shape = sr
	sc.position = Vector2(0, -4)
	_sense.add_child(sc)
	add_child(_sense)


## For bridge engines and masons: is this x covered by a trapdoor at ground level y?
static func covers(tree: SceneTree, x: float, y: float) -> bool:
	for t in tree.get_nodes_in_group("trapdoors"):
		if absf(t.global_position.x - x) <= HALF + 4 and absf(t.global_position.y - y) < 14:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	if is_open:
		_reset -= delta * _rate
		if _reset <= 0 and not _someone_in_the_way():
			_close()
		return
	if _arm >= 0:
		_arm -= delta
		if _arm < 0:
			_open()
		return
	for b in _sense.get_overlapping_bodies():
		if b.is_in_group("enemies") and not ("_dying" in b and b._dying):
			_arm = ARM
			SFX.play_small(self, SFX.sfx_clink(), -8.0, 1.4)
			return


func _someone_in_the_way() -> bool:
	for b in _sense.get_overlapping_bodies():
		if b.is_in_group("enemies"):
			return true
	return false


func _open() -> void:
	is_open = true
	sprung += 1
	_reset = RESET
	for cs in _shapes:
		cs.set_deferred("disabled", true)
	SFX.play(self, SFX.sfx_ore_knock("metal"), -2.0, 0.6)
	FX.burst(get_parent(), global_position + Vector2(0, -2), Color(0.55, 0.45, 0.35), 10, 60.0, 0.4, 1.8)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var t := _leaves[i].create_tween()
		t.tween_property(_leaves[i], "rotation", -s * DROP_ANGLE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_leaves[i], "rotation", -s * (DROP_ANGLE - 0.12), 0.08)
		t.tween_property(_leaves[i], "rotation", -s * DROP_ANGLE, 0.1)
	# anything resting on it drops too: wake it
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and o.global_position.distance_to(global_position) < HALF + 8:
			o.sleeping = false


func _close() -> void:
	is_open = false
	SFX.play_small(self, SFX.sfx_clink(), -6.0, 0.7)
	for i in 2:
		var t := _leaves[i].create_tween()
		t.tween_property(_leaves[i], "rotation", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(0.5).timeout.connect(func():
		if not is_open:
			for cs in _shapes:
				cs.disabled = false)
