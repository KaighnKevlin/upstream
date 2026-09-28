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
var _back_sp: Sprite2D           # pixel art: the post and the coil's far strands
var _front_sp: Sprite2D          # the near strands, over the riders
const ART := {
	2: [preload("res://assets/sprites/helix_back_2.png"), preload("res://assets/sprites/helix_front_2.png")],
	3: [preload("res://assets/sprites/helix_back_3.png"), preload("res://assets/sprites/helix_front_3.png")],
	4: [preload("res://assets/sprites/helix_back_4.png"), preload("res://assets/sprites/helix_front_4.png")],
}


func _ready() -> void:
	z_index = 0                  # under the ore: riders show inside the coil
	# the coil's near strands, drawn over the riders
	_front = Node2D.new()
	_front.z_index = 2
	_front.draw.connect(_draw_front)
	add_child(_front)
	# sprites (ghosts too): the far half behind the riders, the near half over them
	_back_sp = _sprite(self)
	_front_sp = _sprite(_front)
	_sync_art()


func _sprite(parent: Node2D) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.offset = Vector2(-22, -12)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	return sp


func _sync_art() -> void:
	if not _back_sp:
		return
	var tex: Array = ART.get(turns, ART[3])
	_back_sp.texture = tex[0]
	_front_sp.texture = tex[1]
	_back_sp.flip_h = side < 0
	_front_sp.flip_h = side < 0


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
	_sync_art()                  # the turn count (click) and side pick the sprites
	# the turn count, brass pips under the foot
	var d := depth()
	for k in turns:
		draw_circle(Vector2((k - (turns - 1) * 0.5) * 5.0, d + 12), 1.6, Color(1.0, 0.8, 0.4))


func _draw_front() -> void:
	pass                         # the near strands are _front_sp, a child
