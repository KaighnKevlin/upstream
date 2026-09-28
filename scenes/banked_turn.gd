extends Node2D
## Banked turn: a half-pipe corner, the U-turn of a real marble run. A piece
## rolling into its top mouth (heading toward `side`) is carried round the
## half-circle, keeping nearly all its speed, and comes out of the bottom
## mouth one level down heading back the other way. Switchback runs with
## these instead of stop-lips keep their pace. The node is the top mouth.

const SFX = preload("res://scripts/sfx.gd")
const R := 22.0
const KEEP := 0.94               # speed kept round the bend
const V_MIN := 90.0

@export var side := 1.0          # the way pieces arrive (they leave the other way)

var turned := 0                  # tests
var _riders := {}                # id -> [body, theta, v]
var _cool := {}


func _centre() -> Vector2:
	return Vector2(0, R)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 8 and absf(p.y) < 9 and o.linear_velocity.x * side > 20:
			_riders[o.get_instance_id()] = [o, 0.0, maxf(o.linear_velocity.length(), V_MIN)]
			o.gravity_scale = 0.0
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		var v: float = r[2]
		var th: float = r[1] + v / R * delta
		r[1] = th
		if th >= PI:
			o.gravity_scale = 1.0
			o.global_position = global_position + Vector2(0, 2 * R)
			o.linear_velocity = Vector2(-side * v * KEEP, 0)
			_cool[id] = now + 0.8
			turned += 1
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.3)
			_riders.erase(id)
			continue
		# round the outside of the bend: from the top, out toward `side`, down, back
		var target := global_position + _centre() + Vector2(sin(th) * side, -cos(th)) * R
		o.linear_velocity = (target - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.09, 0.07, 0.1)
	var steel := Color(0.42, 0.44, 0.5)
	var c := _centre()
	var rr := R + 7.5
	var pts := PackedVector2Array()
	for i in 17:
		var th := PI * i / 16.0
		pts.append(c + Vector2(sin(th) * side, -cos(th)) * rr)
	draw_polyline(pts, dark, 6.0)
	draw_polyline(pts, steel, 3.0)
	# a bracket to the wall behind
	draw_line(c + Vector2(side * rr, 0), c + Vector2(side * (rr + 10), 0), Color(0.16, 0.13, 0.1), 3.0)
