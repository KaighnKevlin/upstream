extends Node2D
## Magnet drum: the magnetic head pulley of a real ore line. A turning drum
## that sits where a chute's stream leaves its end: iron things (iron, shot,
## springs, gears, scrap) passing over it cling to its face, ride round its
## underside and drop off behind it; copper and stone don't feel it and fly
## on. Two piles from one stream, by kind. Put the node where the stream
## leaves the chute; `side` is the way the stream is going.
##
## Rate: sorts every one exactly, any rate; it carries any number round at
## once (about half a second each, round to where it lets go).
##
## On a track (scripts/track/track_net.gd): when a track's open end is at
## its face (MOUTH: the chute's low end it's set at), that end is a junction
## on the net (scripts/track/track_fork.gd) and the drum picks by kind:
## iron things take a short branch onto its face, where it takes them as it
## always did and carries them round and under; everything else takes a
## short branch straight on, flying off its end as off the chute (or onto
## track laid from it). A way that's backed up holds the rider (a sorter
## doesn't send it the wrong way) and the queue behind it. No zone. Ore
## flying past it from the air is sorted by the field as before.

const Hold = preload("res://scripts/hold.gd")
const Magnet = preload("res://scenes/magnet.gd")
const SFX = preload("res://scripts/sfx.gd")
const TrackFork = preload("res://scripts/track/track_fork.gd")
const R := 11.0                  # drum radius
const GRAB := 10.0               # reach beyond its face
const SPIN := 5.0                # rad/s: how fast it carries what clings
const MOUTH := Rect2(-32, -32, 64, 44)   # the feeding chute's end in here makes it a junction
const ON := 12.0                 # the straight-on branch's length (a chute laid from its end is clear of the feeding end)

@export var side := 1.0

var pulled := 0                  # tests
var sorted := [0, 0]             # tests: riders sent on, onto the drum (on the track)
var _riders := {}                # id -> [body, angle]
var _phase := 0.0
var _time := 0.0
var _drum: Sprite2D
var _fork = null                 # its junction on the track net (TrackFork)


func _ready() -> void:
	z_index = 2
	# bracket and drum sprites (ghosts too); the field ring draws over them
	var stand := Sprite2D.new()
	stand.texture = preload("res://assets/sprites/magnet_drum_stand.png")
	stand.centered = false
	stand.offset = Vector2(-12, -5)
	stand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stand.show_behind_parent = true
	add_child(stand)
	_drum = Sprite2D.new()
	_drum.texture = preload("res://assets/sprites/magnet_drum.png")
	_drum.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drum.show_behind_parent = true
	add_child(_drum)
	if not has_meta("ghost"):
		_fork = TrackFork.new(self, MOUTH)


func _exit_tree() -> void:
	if _fork:
		_fork.teardown()


## TrackFork: two branches from the chute's end: 0 straight on, 1 onto its face.
func fork_paths(src: Vector2, tangent: Vector2) -> Dictionary:
	var c := global_position
	var face := c + (src - c).normalized().rotated(side * 0.5) * (R + 2.0)
	return {"branches": [PackedVector2Array([src, src + tangent * ON]), PackedVector2Array([src, face])], "open": [false, true]}


## Junction router: iron things onto the drum, the rest straight on; a
## backed-up way holds the rider (-1).
func pick(kind: String, free: Array) -> int:
	var w := 1 if kind in Magnet.METAL else 0
	return w if free[w] else -1


func passed(i: int, _kind: String) -> void:
	sorted[i] += 1


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_fork.update()
	_phase += delta * SPIN * side
	_drum.rotation = _phase
	_time += delta
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or not Hold.free_to_take(o, self):
			continue
		if not str(o.get("kind")) in Magnet.METAL or o.get_meta("drum_until", 0.0) > _time:
			continue
		var p: Vector2 = o.global_position - global_position
		if p.length() < R + GRAB + 6.5:
			_riders[o.get_instance_id()] = [o, p.angle()]
			Hold.claim(o, self)
			o.gravity_scale = 0.0
			SFX.play_small(self, SFX.sfx_magnet(), -16.0, 1.1)
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		# carried round the face, over the front and under, the way it turns
		var a: float = r[1] + SPIN * side * delta
		r[1] = a
		var target := global_position + Vector2(cos(a), sin(a)) * (R + 6.5)
		Hold.claim(o, self)
		o.linear_velocity = (target - o.global_position) / delta
		# let go once it's round underneath and heading back
		var under := Vector2(cos(a), sin(a))
		if under.y > 0.5 and under.x * side < -0.2:
			Hold.release(o, self)
			o.linear_velocity = Vector2(-side * 40.0, 60.0)
			o.set_meta("drum_until", _time + 1.0)
			pulled += 1
			_riders.erase(id)
	queue_redraw()


func _draw() -> void:
	# the bracket and the turning drum are sprites (see _ready); the field, faintly
	draw_arc(Vector2.ZERO, R + GRAB, 0, TAU, 24, Color(0.6, 0.75, 1.0, 0.15), 1.0)
