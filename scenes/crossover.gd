extends Node2D
## Crossover: two rails crossing in an X, like a railway diamond, each
## keeping to its own line. A piece rolling in at a top corner is guided
## down its own diagonal, gathering speed, and leaves at the opposite
## bottom corner, so two streams can swap sides without catching on each
## other (plain chutes crossing grab each other's pieces). The node is the
## crossing point.

const Hold = preload("res://scripts/hold.gd")
const W := 34.0                  # half-width
const H := 22.0                  # half-height
const G := 980.0

var crossed := [0, 0]            # tests: entered top-left, entered top-right
var _riders := {}                # id -> [body, from(-1/1), s(0..1), speed]


func _ready() -> void:
	z_index = 2
	# the rails and boss: a sprite, behind our _draw (the entry marks); ghosts too
	var art := Sprite2D.new()
	art.texture = preload("res://assets/sprites/crossover.png")
	art.centered = false
	art.offset = Vector2(-39, -20)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.show_behind_parent = true
	add_child(art)


func _path(from: float) -> Array:
	# from -1: top-left to bottom-right; 1: top-right to bottom-left
	return [Vector2(from * W, -H), Vector2(-from * W, H)]


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or not Hold.free_to_take(o, self):
			continue
		if o.get_meta("cross_until", 0.0) > Time.get_ticks_msec() / 1000.0:
			continue
		var p: Vector2 = o.global_position - global_position
		for from in [-1.0, 1.0]:
			var entry: Vector2 = _path(from)[0]
			if p.distance_to(entry) < 10.0:
				var sp: float = maxf(o.linear_velocity.length(), 60.0)
				_riders[o.get_instance_id()] = [o, from, 0.0, sp]
				Hold.claim(o, self)
				o.gravity_scale = 0.0
				crossed[0 if from < 0 else 1] += 1
				break
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		var path := _path(r[1])
		var seg: Vector2 = path[1] - path[0]
		var dir := seg.normalized()
		var sp: float = r[3] + G * dir.y * delta     # gravity along the diagonal
		var s: float = r[2] + sp * delta / seg.length()
		r[2] = s
		r[3] = sp
		if s >= 1.0:
			Hold.release(o, self)
			o.linear_velocity = dir * sp
			o.set_meta("cross_until", Time.get_ticks_msec() / 1000.0 + 0.6)
			_riders.erase(id)
			continue
		var target: Vector2 = global_position + path[0] + seg * s
		Hold.claim(o, self)
		o.linear_velocity = (target - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0
	queue_redraw()


func _draw() -> void:
	# the rails and boss are a sprite (see _ready); entry marks
	for from in [-1.0, 1.0]:
		var p := _path(from)
		draw_circle(p[0], 2.0, Color(0.9, 0.8, 0.55, 0.7))
