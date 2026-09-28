extends Node2D
## Ropeway: an overhead cable slung from a tall post down to another, with
## hooks running along it. A piece that drops onto the landing at the high
## post is hooked and carried down the cable, gathering speed like a zip
## line, and let go over the low post: ore crosses gaps, pits and walkers'
## paths in the air. Drag from the high post to the low one (it only runs
## downhill). The node is the high post's landing.

const SFX = preload("res://scripts/sfx.gd")
const LEN_MIN := 80.0
const LEN_MAX := 420.0
const G := 980.0
const START := 90.0              # px/s off the landing
const MAX_V := 380.0

@export var end_offset := Vector2(260, 60)

var carried := 0                 # tests
var _riders := {}                # id -> [body, s (px along), v]
var _cool := {}
var _low: Sprite2D
var _pulleys: Array[Sprite2D] = []
var _turn := 0.0                 # the pulleys' angle, turning while it carries


func _ready() -> void:
	# sprites (ghosts too): the posts behind our _draw (the cable, the
	# hooks), the pulleys over the cable
	_sprite(preload("res://assets/sprites/ropeway_post_high.png"), Vector2(-16, -32)).show_behind_parent = true
	_low = _sprite(preload("res://assets/sprites/ropeway_post_low.png"), Vector2(-10, -32))
	_low.show_behind_parent = true
	for k in 2:
		_pulleys.append(_sprite(preload("res://assets/sprites/ropeway_pulley.png"), Vector2(-5, -5)))
	_place_art()


func _sprite(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _place_art() -> void:
	_low.position = end_offset
	_pulleys[0].position = Vector2(0, -26)
	_pulleys[1].position = end_offset + Vector2(0, -26)
	for p in _pulleys:
		p.rotation = _turn


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 20)
	if end_offset.y < 10:
		end_offset.y = 10.0      # it only runs downhill
	queue_redraw()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var l := end_offset.length()
	var dir := end_offset / l
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 12 and p.y > -14 and p.y < 8:
			_riders[o.get_instance_id()] = [o, 0.0, START]
			o.gravity_scale = 0.0
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.4)
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		var v: float = minf(MAX_V, r[2] + G * dir.y * delta * 0.8)
		var s: float = r[1] + v * delta
		r[1] = s
		r[2] = v
		if s >= l:
			o.gravity_scale = 1.0
			o.linear_velocity = dir * v * 0.12   # let go gently: it drops by the low post
			_cool[id] = now + 1.0
			carried += 1
			_riders.erase(id)
			continue
		# hanging under its hook, a little below the cable
		var target := global_position + Vector2(0, -26) + dir * s + Vector2(0, 12)
		o.linear_velocity = (target - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0
	if not _riders.is_empty():
		_turn = fmod(_turn + delta * 6.0, TAU)
	queue_redraw()


func _draw() -> void:
	_place_art()
	var top := Vector2(0, -26)
	var bot := end_offset + Vector2(0, -26)
	# the cable, sagging a touch
	var pts := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		pts.append(top.lerp(bot, f) + Vector2(0, sin(f * PI) * 6.0))
	draw_polyline(pts, Color(0.1, 0.08, 0.07), 2.0)
	draw_polyline(pts, Color(0.62, 0.64, 0.68), 1.0)
	# hooks on the riders
	for id in _riders:
		var o = _riders[id][0]
		if is_instance_valid(o):
			var q: Vector2 = o.global_position - global_position
			draw_line(q + Vector2(0, -12), q + Vector2(0, -6), Color(0.62, 0.64, 0.68), 1.0)
