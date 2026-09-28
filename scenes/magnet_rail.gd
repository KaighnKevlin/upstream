extends Node2D
## Magnet rail: an overhead bar wound with coils (drag it, like a chute).
## Iron that comes up under it (thrown, bounced, or rolling on a track just
## beneath) jumps up and clings to its underside, then slides along it,
## faster downhill, and drops off the far end. Copper takes no notice and
## falls or rolls straight on. Sorts and carries at once: iron over a gap,
## round a corner, onto a higher line; copper stays below.
## Ore-only: walkers aren't touched.

const SFX = preload("res://scripts/sfx.gd")
const LEN_MIN := 60.0
const LEN_MAX := 400.0
const PULL := 26.0               # reaches this far below the bar
const MAGNETIC := ["iron", "shot", "gear", "scrap"]
const V_MIN := 90.0
const V_MAX := 420.0

@export var end_offset := Vector2(160, 20)

var carried := 0                 # tests
var _held: Array = []            # [ore, s along the bar, speed]
var _g := 980.0


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	_g = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


## Under the bar: the normal pointing down (screen-down side of it).
func _down(dir: Vector2) -> Vector2:
	var n := Vector2(-dir.y, dir.x)
	return n if n.y >= 0 else -n


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var l := end_offset.length()
	var dir := end_offset / l
	var n := _down(dir)
	var now := Time.get_ticks_msec() / 1000.0
	var held_ids := {}
	for h in _held:
		held_ids[h[0]] = true
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or held_ids.has(o) or not (o.kind in MAGNETIC):
			continue
		if o.get_meta("mag_until", 0.0) > now or o.has_meta("store_material"):
			continue
		var p: Vector2 = o.global_position - global_position
		var s := p.dot(dir)
		var d := p.dot(n)
		if s > 4 and s < l - 12 and d > -2 and d < PULL:
			o.gravity_scale = 0.0
			_held.append([o, s, clampf(o.linear_velocity.dot(dir), V_MIN, V_MAX)])
			SFX.play_small(self, SFX.sfx_clink(), -14.0, 1.6)
	var keep: Array = []
	for h in _held:
		var o = h[0]
		if not is_instance_valid(o):
			continue
		var r: float = o.KINDS[o.kind].radius
		h[2] = clampf(h[2] + _g * dir.y * delta * 0.6, V_MIN, V_MAX)
		h[1] += h[2] * delta
		if h[1] >= l:
			o.gravity_scale = 1.0
			o.linear_velocity = dir * h[2]
			o.set_meta("mag_until", now + 0.8)
			carried += 1
			continue
		var at: Vector2 = global_position + dir * h[1] + n * (r + 3.0)
		o.linear_velocity = (at - o.global_position) / delta
		o.angular_velocity = h[2] / r
		if "_timer" in o:
			o._timer = 0.0
		keep.append(h)
	_held = keep
	queue_redraw()


func _draw() -> void:
	var l := end_offset.length()
	if l < 1.0:
		return
	var dir := end_offset / l
	var n := _down(dir)
	var dark := Color(0.1, 0.08, 0.07)
	var iron := Color(0.42, 0.44, 0.5)
	var coil := Color(0.78, 0.38, 0.2)
	# the field it reaches with, faintly
	var pulse := 0.08 + 0.04 * sin(Time.get_ticks_msec() / 200.0)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, end_offset, end_offset + n * PULL, n * PULL]), Color(0.5, 0.7, 1.0, pulse))
	# the bar, and coils wound round it
	draw_line(Vector2.ZERO - dir * 3, end_offset + dir * 3, dark, 6.0)
	draw_line(Vector2.ZERO - dir * 3, end_offset + dir * 3, iron, 4.0)
	draw_line(Vector2.ZERO - dir * 3 - n, end_offset + dir * 3 - n, iron.lightened(0.3), 1.0)
	var k := 10.0
	while k < l - 6:
		var c := dir * k
		draw_line(c - n * 4 - dir * 3, c + n * 4 - dir * 3, dark, 2.0)
		for i in 3:
			var cc := c + dir * (i * 2 - 2)
			draw_line(cc - n * 4, cc + n * 4, coil, 1.0)
		k += 24.0
	# hangers at each end
	for p in [Vector2.ZERO, end_offset]:
		draw_line(p, p - Vector2(0, 14), dark, 3.0)
		draw_line(p, p - Vector2(0, 14), iron, 1.0)
		draw_circle(p - Vector2(0, 14), 2.0, iron)
