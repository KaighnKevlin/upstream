extends Node2D
## Flow meter: a brass gauge on a bracket over a chute or a line, with a
## feeler hanging down across the run. It counts the pieces that pass
## under it and shows how many a minute are going by (over the last ten
## seconds): a needle on the dial and the number under it. Click the dial
## to count only one kind: all / copper / iron. Nothing but a reading: its
## feeler touches nothing, so pieces pass under it as if it weren't there.
## Put its node just above the run.

const SFX = preload("res://scripts/sfx.gd")
const WINDOW := 10.0             # s the reading is taken over
const MIN_SPAN := 2.0            # a new meter reads over at least this long
const KINDS := ["", "copper", "iron"]
const LABELS := ["ALL", "Cu", "Fe"]
const SCALES := [60, 120, 300, 600]   # dial full-scale, per minute: the smallest that fits
const DIAL := Vector2(0, -16)
const DIAL_R := 11.0
const SWEEP := PI * 1.5          # the needle's travel, 0 to full scale

@export var mode := 0

const TrackNet = preload("res://scripts/track/track_net.gd")

var passed := 0                  # tests: everything counted since it was built
var _hits := []                  # [time, kind], the last WINDOW s
var _clock := 0.0
var _born := 0.0
var _last := {}                  # id -> clock time it may count again
var _needle := 0.0               # shown, eases toward the reading
var _flash := 0.0
var _live := false


func _ready() -> void:
	z_index = 2
	# the sprite first, so ghosts and build-bar icons get it too; behind our
	# own _draw (the needle, the numbers, the feeler's bob)
	var sp := Sprite2D.new()
	sp.texture = preload("res://assets/sprites/flow_meter.png")
	sp.centered = false
	sp.offset = Vector2(-15, -31)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	if has_meta("ghost"):
		return
	_live = true
	# the feeler: a strip down across the run that only watches; it has
	# no body, so nothing it counts is slowed, pushed or caught
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6, 36)
	cs.shape = r
	cs.position = Vector2(0, 14)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_passing)
	# over a track it reads the riders themselves (below): no zone, so the
	# marbles it counts stay riders and nothing about the run changes
	a.set_meta("track_ignore", true)


## For the track net: it watches nothing as physics (it counts riders).
func ore_watch() -> Array:
	return []


## Riders under the feeler (scripts/track/track_net.gd): counted as the
## bodies they are, like one passing through the strip.
func _count_riders() -> void:
	var net: Node = TrackNet.find_net(self)
	if net == null:
		return
	var f := global_position + Vector2(0, 14)
	for r in net.riders_near(f, 24.0):
		var d: Vector2 = r.pos - f
		var rad: float = net.KR[net.KID[r.kind]]
		if absf(d.x) <= 3.0 + rad and absf(d.y) <= 18.0 + rad:
			_passing(net.rider_body(r.track, r.index))


func _passing(b) -> void:
	if not (b is RigidBody2D):
		return
	var id: int = b.get_instance_id()
	if _last.get(id, -1.0) > _clock:
		return                   # the same piece rocking back and forth under it
	_last[id] = _clock + 2.0
	passed += 1
	_hits.append([_clock, String(b.get("kind")) if b.get("kind") != null else ""])
	if KINDS[mode] == "" or _hits[-1][1] == KINDS[mode]:
		_flash = 1.0
		SFX.play_small(self, SFX.sfx_ratchet(), -26.0, 1.6)


## Pieces a minute passing, of the kind it's set to (for layouts and tests).
func per_minute() -> float:
	var want: String = KINDS[mode]
	var n := 0
	for h in _hits:
		if want == "" or h[1] == want:
			n += 1
	var span := clampf(_clock - _born, MIN_SPAN, WINDOW)
	return n * 60.0 / span


func _physics_process(delta: float) -> void:
	if not _live:
		return
	_clock += delta
	_count_riders()
	while not _hits.is_empty() and _hits[0][0] < _clock - WINDOW:
		_hits.pop_front()
	if _last.size() > 64:
		for id in _last.keys():
			if _last[id] < _clock:
				_last.erase(id)
	var rate := per_minute()
	_needle = lerpf(_needle, rate, minf(1.0, delta * 3.0))
	_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()


func _scale_for(rate: float) -> int:
	for s in SCALES:
		if rate <= s:
			return s
	return SCALES[-1]


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + DIAL) < DIAL_R + 2:
		mode = (mode + 1) % KINDS.size()
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	# the feeler's bob (the wire, bracket and gauge are the sprite): flashes
	# as it counts
	draw_circle(Vector2(0, 30), 1.4, brass.lightened(0.1) if _flash > 0.3 else steel)
	# the bezel brightens with each count
	if _flash > 0.0:
		draw_arc(DIAL, DIAL_R + 0.5, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, 0.35 * _flash), 2.0)
	var full := _scale_for(maxf(_needle, per_minute()) if _live else 0.0)
	var a0 := PI * 0.75          # the sweep starts low left, clockwise to low right
	# the needle
	var f := clampf(_needle / full, 0.0, 1.0)
	var an := a0 + SWEEP * f
	draw_line(DIAL, DIAL + Vector2(cos(an), sin(an)) * (DIAL_R - 3.0), Color(0.6, 0.12, 0.1), 1.0)
	draw_circle(DIAL, 1.3, dark)
	# the number, a minute's worth, and what it's counting
	var font := ThemeDB.fallback_font
	var n := int(round(per_minute())) if _live else 0
	draw_string(font, DIAL + Vector2(-9, 7), "%d" % n, HORIZONTAL_ALIGNMENT_CENTER, 18, 7, dark)
	draw_string(font, DIAL + Vector2(-9, -3), LABELS[mode], HORIZONTAL_ALIGNMENT_CENTER, 18, 5, Color(0.45, 0.35, 0.25))
	draw_string(font, DIAL + Vector2(DIAL_R + 3, 4), "/min", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.9, 0.8, 0.55))
	draw_string(font, DIAL + Vector2(DIAL_R + 3, -4), "%d" % full, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.7, 0.6, 0.45))
