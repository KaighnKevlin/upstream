extends "res://scenes/rocker.gd"
## Overflow gate: the priority splitter, as a counterweighted flap. A steel
## tent under the funnel, and on its apex an oak flap leaning over the
## overflow side: every marble rolls down the primary side (`side`). An
## iron arm under the flap carries the counterweight (`full` iron discs)
## that holds it there. When the primary line has backed up to the gate the
## next marble can't go that way: the queue behind shoves it against the
## flap, the flap yields (the counterweight swings up) and it goes over the
## overflow side, and as soon as the primary side has room the weight
## swings the flap back. Feed a machine first and send only the surplus on.
##
## A line that ends in a physics heap (loose ore passes through ore, so it
## never queues back to the gate) is felt instead: a brass feeler pan set
## where it ends (`watch`, an offset: a turret's funnel, a dip at a line's
## end; drag the pan there) sinks as pieces settle in it, and with `full`
## pieces sitting still its string pulls the counterweight up and the flap
## over by its top, until they're used.
##
## Rate: up to 10 a second.
##
## On a track (a chute ending at its funnel: see scenes/rocker.gd) the
## queue does reach it: every rider goes the primary way until that branch
## is backed up (whatever it feeds is full), then the secondary way, and
## back to the primary the moment it has room: priority by backpressure,
## exact, no pan needed (the pan still works, for a line that ends in
## physics). Both backed up, the queue waits behind it.

const FLAP := 0.45               # rad the flap leans over a plate
const FLAP_LEN := 11.0

const STILL := 25.0              # px/s: slower than this is queued, not passing
const HOLD := 0.3                # s a piece must sit before it counts

@export var side := 1.0
@export var watch := Vector2(80, 40)   # where the primary line ends up
@export var full := 4

var overflowed := 0              # tests
var primary := 0
var _still_t := 0.0
var _held := 0
var _dragging := false
var _blocked_t := 0              # net tick until which the primary way counts as backed up (for the lean)
var _rig: Node2D                 # the drawn parts, mirrored so primary is +x
var _flap: Sprite2D
var _pan: Sprite2D
var _pan_dip := 0.0


## Drag the feeler pan onto where the primary line ends.
func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_mouse_position().distance_to(global_position + watch) < 18:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		watch = get_global_mouse_position() - global_position
		_place_pan()


func _ready() -> void:
	tilt = side
	super._ready()
	if has_meta("ghost"):
		return
	# the tent's plates are fixed; what moves is the flap on the apex
	(_shape.shape as SegmentShape2D).a = Vector2.ZERO
	(_shape.shape as SegmentShape2D).b = Vector2(0, -FLAP_LEN)
	for sx in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var sg := SegmentShape2D.new()
		sg.a = Vector2.ZERO
		sg.b = Vector2(sx * ARM * cos(TILT), ARM * sin(TILT))
		cs.shape = sg
		_body.add_child(cs)
	_apply()


func _build_art() -> void:
	_rig = Node2D.new()
	_rig.scale.x = 1.0 if side >= 0 else -1.0
	_rig.show_behind_parent = true
	add_child(_rig)
	var fr := Sprite2D.new()
	fr.texture = preload("res://assets/sprites/overflow_frame.png")
	fr.centered = false
	fr.offset = Vector2(-22, -28)
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rig.add_child(fr)
	_flap = Sprite2D.new()
	_flap.texture = preload("res://assets/sprites/overflow_flap.png")
	_flap.centered = false
	_flap.offset = Vector2(-13, -13)
	_flap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rig.add_child(_flap)
	# the counterweight: one iron disc per piece it waits for, on the arm's end
	var arm := Vector2(-4, 8)
	for k in clampi(full, 1, 8):
		var d := Sprite2D.new()
		d.texture = preload("res://assets/sprites/overflow_disc.png")
		d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		d.position = arm * (1.0 - k * 0.16)
		d.rotation = arm.angle() - PI / 2
		_flap.add_child(d)
	_pan = _sprite(preload("res://assets/sprites/overflow_pan.png"), Vector2(-10, -1), false)
	_place_pan()


func _place_pan() -> void:
	if _pan:
		_pan.position = watch + Vector2(0, _pan_dip)
	queue_redraw()


## The flap's lean (world, +: clockwise): over the overflow side while
## `tilt` is primary, over the primary side once yielded.
func _pose_angle() -> float:
	return -FLAP * tilt


func _pose(a: float) -> void:
	if _flap:
		_flap.rotation = a * _rig.scale.x
	queue_redraw()


func _swing_time() -> float:
	return 0.15


func _count_held() -> int:
	var at := global_position + watch
	var n := 0
	for b in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(b) and b.global_position.distance_to(at) < 18.0 and b.linear_velocity.length() < STILL:
			n += 1
	# riders queued there too (a line on the track net)
	if _fork and _fork.net != null and is_instance_valid(_fork.net):
		for r in _fork.net.riders_near(at, 18.0):
			if absf(r.v) < STILL:
				n += 1
	return n


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if has_meta("ghost") or _shape == null:
		return
	var h := _count_held()
	if h != _held:
		_held = h
	var dip := 3.0 * clampf(float(_held) / maxf(full, 1), 0.0, 1.0)
	if not is_equal_approx(dip, _pan_dip):
		_pan_dip = move_toward(_pan_dip, dip, delta * 20.0)
		_place_pan()
	_still_t = _still_t + delta if _held >= full else 0.0
	var backed: bool = _fork != null and _fork.linked() and _fork.net.tick < _blocked_t
	var want := -side if _still_t > HOLD or backed else side
	if want != tilt:
		tilt = want
		_apply()
		if want == side:
			SFX.play_small(self, SFX.sfx_ore_knock("wood"), -16.0, 1.2)   # the weight drops it back on its stop
		else:
			SFX.play_small(self, SFX.sfx_creak(), -18.0, 1.4)          # yielding


## The primary way (0 left, 1 right) unless the ring says it's full.
func _want(_kind: String) -> int:
	var primary_i := 1 if side > 0 else 0
	return primary_i if _still_t <= HOLD else 1 - primary_i


func pick(kind: String, free: Array) -> int:
	var primary_i := 1 if side > 0 else 0
	if not free[primary_i]:
		_blocked_t = _fork.net.tick + 20
	return super.pick(kind, free)


func _went(i: int, _kind: String) -> void:
	_next = _fork.net.tick + 6   # it doesn't rock per marble: at most 10/s
	if (i == 1) == (side > 0):
		primary += 1
	else:
		overflowed += 1


func _on_leave(b) -> void:
	# counted, but no flip-flopping: the queue sets which way it leans
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	var went := 1 if b.global_position.x > global_position.x else 0
	sent[went] += 1
	if (went == 1) == (side > 0):
		primary += 1
	else:
		overflowed += 1


func _draw() -> void:
	# the feeler pan's string, tied to the flap's top: a full pan pulls it over
	if _flap == null:
		return
	var tip := Vector2(0, -FLAP_LEN + 1.0).rotated(_flap.rotation) * Vector2(_rig.scale.x, 1.0)
	draw_line(tip, watch + Vector2(0, _pan_dip), Color(0.78, 0.7, 0.52, 0.8), 1.0)


## On the track net (fed by a track, so its own tracks aren't zones): only
## the spot it watches is physics, so a line settling there is real bodies
## it can count (scripts/track/track_net.gd: ore_watch_owned).
func ore_watch_owned() -> Array:
	return [Rect2(global_position + watch - Vector2(30, 30), Vector2(60, 60))]


## Where this looks at ore (world rects), for the track net: its own place
## and the spot it watches, so a line queueing there is real bodies it can
## count (scripts/track/track_net.gd, zones).
func ore_watch() -> Array:
	return [Rect2(global_position - Vector2(40, 40), Vector2(80, 80)),
		Rect2(global_position + watch - Vector2(30, 30), Vector2(60, 60))]
