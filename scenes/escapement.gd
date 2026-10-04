extends Node2D
## Escapement: the pacer, as a real marble escapement. A brass pallet bar
## rocks on a pin on an oak post above the track, worked by an upright
## metronome rod fixed to it; from each end of the pallet a steel stop pin
## hangs through an iron guide bar into the track: the exit pin B at the
## gate point, the entry pin A one marble upstream. As the metronome swings
## one pin rises while the other drops. At the end of each swing B is up and
## the lead marble rolls out (the pallet's nudge sends it off), while A has
## dropped into the gap behind it and holds the rest; swinging back, A lifts
## and the next marble rolls down against B. Exactly one per swing, however
## many are pushing behind. Fit it at the low end of a chute (or mid-chute).
## Ore-only layer: walkers pass through.
##
## Setting: the brass weight on the metronome rod, slid to one of three
## notches: low 0.6 s, middle 1.2 s, high 2.4 s a swing (a higher weight
## swings slower, as on any metronome). Click the metronome to slide it up.
##
## Rate: exactly 1 per swing with a queue behind it: 1 per 0.6 / 1.2 / 2.4 s
## powered (a wheel or engine in reach), 1 per 0.81 / 1.62 / 3.24 s unpowered
## (the clockwork runs at 0.74). A swing nobody's there for is lost.
##
## On a track (scripts/track/track_net.gd) both pins are marks on the chute
## under them (scripts/track/track_mark.gd): B holds the lead rider and
## lets exactly one by at the end of each swing; A is shut while the pallet
## leans its way (A down) and open while it leans B's way, so the next
## rider comes down to B only once the one before is gone. The queue behind
## is the track's own queue, all the way up the line. No zone: the riders
## stay riders. Physics ore (a chute off the track net, ore dropped onto the
## gate) still meets B's collision, as it always did.

const SFX = preload("res://scripts/sfx.gd")
const Power = preload("res://scripts/power.gd")
const TrackMark = preload("res://scripts/track/track_mark.gd")
const ORE_ONLY := 64
const PERIODS := [0.6, 1.2, 2.4]
const OPEN_FOR := 0.35           # s the pin stays up on a beat
const NUDGE := 45.0              # px/s the pallet gives the one it lets go
const AMP := 0.7                 # rad the pallet rocks each way
const PIVOT := Vector2(-6.5, -28)   # the pallet's pin, drawn for side +1
const PIN_LEN := 19.5            # a stop pin, eye to tip
const BOB_AT := [9.0, 14.0, 19.0]   # the weight's notch up the rod, by mode
const A_BACK := 13.0             # entry pin A: a marble's width upstream of B

@export var mode := 1
@export var side := 1.0            # which way the track runs through it

var released := 0                # tests: beats
var let_by := 0                  # tests: riders it let by on the track
var _gate: CollisionShape2D
var _open := 0.0
var _rate := 1.0
var _rate_t := 0.0
var _swing := TAU                # the metronome's phase: a release as it wraps past TAU (so the first comes at once)
var _rig: Node2D                 # the drawn parts, mirrored by side
var _pallet: Sprite2D
var _bob: Sprite2D
var _pin_a: Sprite2D
var _pin_b: Sprite2D
var _mark = null                 # pin B on the track under it (TrackMark)
var _mark_a = null               # pin A, a marble upstream


func _ready() -> void:
	z_index = 2
	# the post, pallet + metronome, weight and stop pins (ghosts too)
	_rig = Node2D.new()
	_rig.scale.x = 1.0 if side >= 0 else -1.0
	add_child(_rig)
	_pin_a = _sprite(_rig, "escapement_stop", Vector2(-2, -1))
	_pin_a.region_enabled = true
	_pin_a.region_rect = Rect2(0, 0, 5, 19)     # 3 px shorter: the rail is higher there
	_pin_b = _sprite(_rig, "escapement_stop", Vector2(-2, -1))
	_sprite(_rig, "escapement_frame", Vector2(-20, -36))
	_pallet = _sprite(_rig, "escapement_pallet", Vector2(-11, -28))
	_pallet.position = PIVOT
	_bob = _sprite(_pallet, "escapement_bob", Vector2(-3, -3))
	if has_meta("ghost"):
		_swing = PI / 2          # the icon: mid-swing
		_pose()
		return
	_pose()
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
	_mark_a = TrackMark.new(self, Vector2(-side * A_BACK, 0), 10.0, 6.0)


func _sprite(parent: Node, n: String, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/sprites/%s.png" % n)
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	return sp


## The pallet's angle (drawn for side +1, +: B's end down): at the end of
## each swing (phase 0) it leans full over A's way, B up.
func _theta() -> float:
	return -AMP * cos(_swing)


## Pallet, metronome, weight and both pins where the phase puts them. The
## pins slide straight up and down in their guides, riding in the pallet's
## slots.
func _pose() -> void:
	var th := _theta()
	_pallet.rotation = th
	_bob.position = Vector2(0, -BOB_AT[mode])
	var k := tan(th)
	_pin_b.position = Vector2(0, PIVOT.y + (0.0 - PIVOT.x) * k)
	_pin_a.position = Vector2(-A_BACK, PIVOT.y + (-A_BACK - PIVOT.x) * k)


func _close() -> void:
	_gate.set_deferred("disabled", false)
	if _mark:
		_mark.gate(0, false)
	queue_redraw()


func _exit_tree() -> void:
	if _mark:
		_mark.drop()
	if _mark_a:
		_mark_a.drop()


## For the track net's zones: none while its pin is on the track (it gates
## the riders there itself), a watch round it while it isn't.
func ore_watch() -> Array:
	return _mark.watching() if _mark else []


## The net: a rider went by the pin (or was stopped by it).
func mark_event(m, _kind: String, _v: float, ev: int) -> void:
	if m != _mark.m:
		return                   # pin A: nothing to count
	if ev == 1:
		let_by += 1
		if _open > 0:
			_open = 0.0
			_close()


func _physics_process(delta: float) -> void:
	if _gate == null:
		return
	_mark.update()
	_mark_a.update()
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = 0.6 + 0.4 * Power.rate_at(get_tree(), global_position)   # 0.74 unpowered .. 1
	if _open > 0:
		_open -= delta
		if _open <= 0:
			_close()
	# the metronome keeps its swing whatever the pins are doing: one release
	# per swing, a release nobody's there for lost
	_swing += delta * TAU / PERIODS[mode] * _rate
	var beat := _swing >= TAU
	if beat:
		_swing = fmod(_swing, TAU)
	# pin A: down (shut) while the pallet leans its way
	_mark_a.gate(0 if _theta() < 0.0 else -1)
	if beat:
		_open = OPEN_FOR
		_gate.set_deferred("disabled", true)
		# on a track: pin B lets one by; the one resting against it gets
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
	_pose()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or _gate == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := Pointer.world(self)
		if p.distance_to(global_position + Vector2(PIVOT.x * side, -40)) < 14 or p.distance_to(global_position + Vector2(0, -18)) < 12:
			mode = (mode + 1) % PERIODS.size()   # slide the weight up a notch (from the top, back to the bottom)
			_pose()
			SFX.play_small(self, SFX.sfx_latch(), -10.0, 1.4)
			get_viewport().set_input_as_handled()
