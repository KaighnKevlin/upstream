extends Node2D
## Gabion: a tall wire cage on the ground that fills with whatever's dropped
## in its top (end a chute over it). Each piece raises the wall inside it
## (12 fill it: a wall three tiles high), and the wall is solid: walkers
## stop at it and hack at it, each blow knocking pieces out through the
## wire. Keep a line feeding it and it mends itself as fast as they break it.
## Iron fills it the same as copper, but a blow knocks out fewer.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const CAP := 12
const W := 20.0
const H := 48.0

var kinds: Array = []            # what's in it, bottom up
var took := 0                    # tests
var knocked := 0
var _shape: RectangleShape2D
var _cs: CollisionShape2D
var _shake := 0.0
var _front: Sprite2D             # art: the near mesh, drawn over the fill
var _jig := 0.0                  # art: the jiggle's x offset, px
const _CU := preload("res://assets/sprites/gabion_copper.png")
const _FE := preload("res://assets/sprites/gabion_iron.png")


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # the fill textures in _draw
	# the sprites first, so ghosts and build-bar icons get them too: the far
	# mesh behind our _draw (the fill), the near mesh over it
	_spr(preload("res://assets/sprites/gabion_back.png"), Vector2(-10, -48)).show_behind_parent = true
	_front = _spr(preload("res://assets/sprites/gabion_front.png"), Vector2(-12, -50))
	if has_meta("ghost"):
		return
	_snap_to_floor()
	add_to_group("walls")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_cs = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_cs.shape = _shape
	body.add_child(_cs)
	add_child(body)
	_fit()


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


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


func height() -> float:
	return H * kinds.size() / float(CAP)


## The solid part is as tall as the fill.
func _fit() -> void:
	var h := height()
	_cs.disabled = h < 1.0
	_shape.size = Vector2(W - 2, maxf(1.0, h))
	_cs.position = Vector2(0, -h * 0.5)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_shake = maxf(0.0, _shake - delta * 4.0)
	_jiggle()
	if kinds.size() >= CAP:
		return
	var top := -height()
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.has_meta("store_material"):
			continue
		if o.get_meta("gabion_until", 0.0) > Time.get_ticks_msec() / 1000.0:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < W * 0.5 - 1 and p.y < top and p.y > top - 14 and o.linear_velocity.y >= -20:
			kinds.append(o.kind if "kind" in o else "copper")
			took += 1
			o.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 0.9)
			_fit()
			if kinds.size() >= CAP:
				break


## A walker's blow: pieces burst out through the wire toward it (iron
## holds: a blow takes out half as many if the top one's iron).
func take_damage(d: int) -> void:
	if kinds.is_empty():
		return
	var n := maxi(1, d / 4)
	if kinds[-1] == "iron":
		n = maxi(1, n / 2)
	_shake = 1.0
	var toward := 1.0
	var scene := get_tree().current_scene
	for i in mini(n, kinds.size()):
		var k: String = kinds.pop_back()
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = global_position + Vector2(randf_range(-6, 6), -height() - 4)
		o.set_meta("gabion_until", Time.get_ticks_msec() / 1000.0 + 1.5)
		scene.add_child(o)
		toward = -1.0 if randf() < 0.5 else 1.0
		o.linear_velocity = Vector2(toward * randf_range(60, 140), randf_range(-220, -140))
		knocked += 1
	FX.burst(get_parent(), global_position + Vector2(0, -height() * 0.5), Color(0.6, 0.6, 0.65), 6, 90.0, 0.25, 1.5)
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.8)
	_fit()


## Art: while it's shaking, the fill and the near mesh rattle side to side.
func _jiggle() -> void:
	var j := roundf(sin(Time.get_ticks_msec() * 0.06) * _shake * 1.4)
	if j != _jig:
		_jig = j
		_front.position.x = j
		queue_redraw()


func _draw() -> void:
	# the cage is two sprites (the far mesh behind, the near one over); the
	# fill between them: pieces stacked two abreast
	for i in kinds.size():
		var c := Vector2(-9 + (i % 2) * 9 + _jig, -8 - (i / 2) * 8)
		draw_texture(_FE if kinds[i] == "iron" else _CU, c)
