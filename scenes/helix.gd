extends Node2D
## Helix: a corkscrew descent in a narrow column. A piece rolling into its
## top mouth (heading toward `side`) is carried round and round the coil,
## swinging back and forth across the column as it goes down a level each
## turn, and leaves the bottom mouth heading on toward `side` at a steady
## speed however fast (or slow) it came in. Drops a run several levels in
## one tile's width. Click it to set the number of turns (2 / 3 / 4); each
## turn is PITCH px of drop. The node is the top mouth, in the middle of
## the column; end the feeding chute there, the way out is straight below.

const SFX = preload("res://scripts/sfx.gd")
const R := 14.0                  # the column's half-width
const PITCH := 26.0              # drop per turn
const V_RIDE := 150.0            # px/s along the coil
const V_OUT := 140.0             # leaving the bottom
const TURNS := [2, 3, 4]

@export var side := 1.0          # the way pieces arrive (and leave)
@export var turns := 3

var spun := 0                    # tests: pieces out of the bottom
var last_out := Vector2.ZERO     # tests: velocity of the last one out
var _riders := {}                # id -> [body, theta, v]
var _cool := {}
var _front: Node2D


func _ready() -> void:
	z_index = 0                  # under the ore: riders show inside the coil
	# the coil's near strands, drawn over the riders
	_front = Node2D.new()
	_front.z_index = 2
	_front.draw.connect(_draw_front)
	add_child(_front)


func depth() -> float:
	return PITCH * turns


## Where pieces leave (for layouts and tests).
func out_point() -> Vector2:
	return Vector2(0, depth())


func _coil(th: float) -> Vector2:
	# side view of the helix: x swings across the column, y goes down a pitch a turn
	return Vector2(sin(th) * R * side, PITCH * th / TAU)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 9 and p.y > -12 and p.y < 6 and o.linear_velocity.x * side > 10:
			_riders[o.get_instance_id()] = [o, 0.0, clampf(o.linear_velocity.length(), 60.0, 400.0)]
			o.gravity_scale = 0.0
	var turn_len := Vector2(TAU * R, PITCH).length()
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		# whatever it came in at, the coil's rub brings it to the ride speed
		var v: float = move_toward(r[2], V_RIDE, 260.0 * delta)
		r[2] = v
		var th: float = r[1] + v / turn_len * TAU * delta
		r[1] = th
		if th >= TAU * turns:
			o.gravity_scale = 1.0
			o.global_position = global_position + out_point() + Vector2(side * 2, -6)
			o.linear_velocity = Vector2(side * V_OUT, 10.0)
			last_out = o.linear_velocity
			_cool[id] = now + 1.0
			spun += 1
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.4)
			_riders.erase(id)
			continue
		# riding on the coil's rail (the piece's centre a radius above it)
		o.linear_velocity = (global_position + _coil(th) + Vector2(0, -6) - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_global_mouse_position() - global_position
	if absf(m.x) < R + 6 and m.y > -8 and m.y < depth() + 8:
		var k := TURNS.find(turns)
		turns = TURNS[(k + 1) % TURNS.size()]
		get_viewport().set_input_as_handled()
		queue_redraw()
		_front.queue_redraw()


func _strands(front: bool) -> Array:
	# the coil split into runs on the near (front) or far half of each turn
	var out := []
	var run := PackedVector2Array()
	var n := turns * 24
	for i in n + 1:
		var th := TAU * turns * i / float(n)
		var near := cos(th) >= 0.0
		if near == front:
			run.append(_coil(th))
		elif run.size() > 0:
			run.append(_coil(th))
			if run.size() > 1:
				out.append(run)
			run = PackedVector2Array()
	if run.size() > 1:
		out.append(run)
	return out


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var d := depth()
	# the central post, capped top and bottom, a bracket back to the wall
	draw_line(Vector2(0, -8), Vector2(0, d + 6), dark, 5.0)
	draw_line(Vector2(0, -7), Vector2(0, d + 5), steel.darkened(0.2), 3.0)
	draw_line(Vector2(-R - 5, d + 7), Vector2(R + 5, d + 7), dark, 4.0)
	draw_line(Vector2(-R - 4, d + 6.5), Vector2(R + 4, d + 6.5), brass.darkened(0.2), 2.0)
	draw_line(Vector2(-7, -9), Vector2(7, -9), dark, 4.0)
	draw_line(Vector2(-6, -9.5), Vector2(6, -9.5), brass, 2.0)
	# the coil's far strands, in shadow behind the riders
	for run in _strands(false):
		draw_polyline(run, dark, 5.0)
		draw_polyline(run, steel.darkened(0.45), 3.0)
	# the mouths: a lip in at the top, a spout out at the bottom
	draw_line(Vector2(-side * 6, 0), Vector2(side * 2, 0), dark, 4.0)
	draw_line(Vector2(0, d), Vector2(side * (R + 4), d), dark, 4.0)
	draw_line(Vector2(0, d - 0.5), Vector2(side * (R + 3), d - 0.5), steel, 2.0)
	# the turn count, brass pips on the cap
	for k in turns:
		draw_circle(Vector2((k - (turns - 1) * 0.5) * 5.0, d + 12), 1.6, Color(1.0, 0.8, 0.4))


func _draw_front() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var steel := Color(0.42, 0.44, 0.5)
	for run in _strands(true):
		_front.draw_polyline(run, dark, 5.0)
		_front.draw_polyline(run, steel, 3.0)
		_front.draw_polyline(run, Color(0.78, 0.82, 0.86), 1.0)
