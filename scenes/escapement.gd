extends Node2D
## Escapement: the pacer. A rocking pallet fork on a little clockwork, set
## across a track (fit it at the low end of a chute): a gate pin holds the
## queue back and lets exactly one marble through each beat, however many
## are pushing behind it. PERIOD seconds a beat at full power (faster when
## a wheel or engine drives it). Click it to cycle 0.6 / 1.2 / 2.4 s.
## Ore-only layer: walkers pass through.
##
## Rate: exactly 1 per beat with a queue behind it: 1 per 0.6 / 1.2 / 2.4 s
## powered (a wheel or engine in reach), 1 per 0.81 / 1.62 / 3.24 s unpowered
## (the clockwork runs at 0.74). A beat nobody's there for is lost.
##
## On a track (scripts/track/track_net.gd) its pin is a mark on the chute
## under it (scripts/track/track_mark.gd): shut, the lead rider stops
## against it and the queue backs up behind, the track's own queue, all the
## way up the line; on the beat it lets exactly one by (and gives it the
## pallet's nudge). No zone: the riders stay riders. Set mid-chute or at a
## chute's low end (a point just past the end is the end), it's the same.
## Physics ore (a chute off the track net, ore dropped onto the gate)
## still meets the pin's collision, as it always did.

const SFX = preload("res://scripts/sfx.gd")
const Power = preload("res://scripts/power.gd")
const TrackMark = preload("res://scripts/track/track_mark.gd")
const ORE_ONLY := 64
const PERIODS := [0.6, 1.2, 2.4]
const OPEN_FOR := 0.35           # s the pin stays up on a beat
const NUDGE := 45.0              # px/s the pallet gives the one it lets go

@export var mode := 1
@export var side := 1.0            # which way the track runs through it

var released := 0                # tests: beats
var let_by := 0                  # tests: riders it let by on the track
var _gate: CollisionShape2D
var _open := 0.0
var _beat := 0.0
var _passing := false
var _rate := 1.0
var _rate_t := 0.0
var _swing := 0.0
var _pin: Sprite2D
var _fork: Sprite2D
var _wheel: Sprite2D
var _mark = null                 # its pin on the track under it (TrackMark)


func _ready() -> void:
	z_index = 2
	# pin, fork and escape wheel sprites (ghosts too), moved in _draw
	_pin = _sprite("escapement_pin", Vector2(-3, -16), Vector2.ZERO)
	_fork = _sprite("escapement_fork", Vector2(-7, -3), Vector2(0, -24))
	_wheel = _sprite("escapement_wheel", Vector2(-7, -7), Vector2(0, -24))
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	_gate = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(0, -14)
	seg.b = Vector2(0, 4)
	_gate.shape = seg
	body.add_child(_gate)
	add_child(body)
	# past the gate: a marble through closes it again
	var past := Area2D.new()
	past.collision_layer = 0
	past.collision_mask = 2
	var pc := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(6, 18)
	pc.shape = pr
	pc.position = Vector2(side * 9, -5)
	past.add_child(pc)
	add_child(past)
	past.body_entered.connect(func(_b):
		if _open > 0:
			_open = 0.0
			_close())
	past.set_meta("track_ignore", true)   # on a track it reads the riders (the mark), no zone
	_mark = TrackMark.new(self, Vector2.ZERO, 6.0, 10.0)
	_mark.gate(0, false)


func _sprite(n: String, off: Vector2, at: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/sprites/%s.png" % n)
	sp.centered = false
	sp.offset = off
	sp.position = at
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _close() -> void:
	_gate.set_deferred("disabled", false)
	if _mark:
		_mark.gate(0, false)
	queue_redraw()


func _exit_tree() -> void:
	if _mark:
		_mark.drop()


## For the track net's zones: none while its pin is on the track (it gates
## the riders there itself), a watch round it while it isn't.
func ore_watch() -> Array:
	return _mark.watching() if _mark else []


## The net: a rider went by the pin (or was stopped by it).
func mark_event(_m, _kind: String, _v: float, ev: int) -> void:
	if ev == 1:
		let_by += 1
		if _open > 0:
			_open = 0.0
			_close()


func _physics_process(delta: float) -> void:
	if _gate == null:
		return
	_mark.update()
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = 0.6 + 0.4 * Power.rate_at(get_tree(), global_position)   # 0.74 unpowered .. 1
	_swing += delta * TAU / PERIODS[mode] * _rate
	if _open > 0:
		_open -= delta
		if _open <= 0:
			_close()
	# the clockwork keeps its beat whatever the pin is doing: exactly one
	# beat per period, a beat nobody's there for lost
	_beat -= delta * _rate
	if _beat <= 0:
		_beat = maxf(_beat + PERIODS[mode], 0.0)
		_open = OPEN_FOR
		_gate.set_deferred("disabled", true)
		# on a track: the pin lets one by; the one resting against it gets
		# the pallet's nudge
		_mark.gate(1, false)
		var fi: int = _mark.front()
		if fi >= 0 and _mark.m.track.rv[fi] < NUDGE:
			_mark.m.track.set_speed(fi, NUDGE)
		# the one at the front has been resting against the pin: wake it and
		# give it the nudge the pallet would
		var front: RigidBody2D = null
		var best := 20.0
		for g in ["ore", "ingots"]:
			for o in get_tree().get_nodes_in_group(g):
				if is_instance_valid(o) and not o.freeze:
					var d: float = o.global_position.distance_to(global_position + Vector2(-side * 7.0, -6.0))
					if d < best:
						best = d
						front = o
		if front:
			front.sleeping = false
			front.linear_velocity += Vector2(side * 45.0, -10.0)
		released += 1
		SFX.play_small(self, SFX.sfx_ratchet(), -12.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# the gate pin (lifted when open), the rocking fork and the escape wheel
	# are sprites (see _ready)
	if _pin:
		_pin.position.y = -14.0 if _open > 0 else 0.0
		_fork.rotation = -sin(_swing) * 0.35
		_wheel.rotation = _swing * 0.5


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or _gate == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position + Vector2(0, -18)) < 12:
			mode = (mode + 1) % PERIODS.size()
			SFX.play(self, SFX.sfx_clink())
			get_viewport().set_input_as_handled()
