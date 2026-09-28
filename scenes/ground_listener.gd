extends Node2D
## Ground listener: a brass ear trumpet bolted to the rock, its bell pressed
## flat against the stone. When anything digs within its range (a burrower
## grinding out a tile; click it: 5 / 8 / 12 tiles) it fires everything
## triggerable in reach of it and of its pull-wire's end (drag it), like a
## tally wheel or a load cell: a keg in the wall goes up, a stamp press lets
## go, a sluice opens, a grapeshot mortar lobs its load. Then it needs
## REARM seconds to settle before it can fire again. For a few seconds after
## hearing it, a red arrow on its dial points toward the digging, so you
## know which wall the mole is coming through.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const TILE := 16.0
const RANGES := [5, 8, 12]        # tiles
const REARM := 3.0                # s between firings
const SHOW := 4.0                 # s the arrow points after the last dig heard

@export var mode := 1
@export var wire_to := Vector2(40, -30)   # drag its end to what it should fire

var fired := 0                    # tests: firings
var heard := 0                    # tests: digs heard
var heard_at := Vector2.ZERO      # tests: where the last dig it heard was
var heard_dist := 0.0             # tests: how far off (px)
var _dug := {}                    # digger id -> its dig count last frame
var _cool := 0.0
var _show := 0.0
var _dir := Vector2.RIGHT
var _flash := 0.0
var _anim := 0.0
var _dragging := false


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("ground_listeners")


func range_px() -> float:
	return RANGES[mode] * TILE


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_anim += delta
	_cool = maxf(0.0, _cool - delta)
	_show = maxf(0.0, _show - delta)
	_flash = maxf(0.0, _flash - delta * 3.0)
	var seen := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not ("dug" in e):
			continue
		var id: int = e.get_instance_id()
		seen[id] = true
		var n: int = e.dug
		var was: int = _dug.get(id, n)
		_dug[id] = n
		if n > was:
			_hear(e.global_position)
	for id in _dug.keys():
		if not seen.has(id):
			_dug.erase(id)
	if _show > 0 or _flash > 0 or _dragging:
		queue_redraw()


## A tile broken at `at` (anything that digs can call this on the group).
func _hear(at: Vector2) -> void:
	var d := at.distance_to(global_position)
	if d > range_px():
		return
	heard += 1
	heard_at = at
	heard_dist = d
	_show = SHOW
	if d > 1.0:
		_dir = (at - global_position) / d
	queue_redraw()
	if _cool <= 0.0:
		fire()


func fire() -> void:
	fired += 1
	_cool = REARM
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_clink(), -6.0, 0.7)
	var points := [global_position]
	if wire_to != Vector2.ZERO:
		points.append(global_position + wire_to)
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed and wire_to != Vector2.ZERO and m.distance_to(global_position + wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and m.distance_to(global_position + Vector2(0, -12)) < 12:
			mode = (mode + 1) % RANGES.size()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	var steel := Color(0.42, 0.44, 0.5)
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(8, -18), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	# the mounting plate, bolted to the rock
	draw_rect(Rect2(-12, -3, 24, 3), dark)
	draw_rect(Rect2(-11, -2.5, 22, 2), steel)
	for x in [-9.0, 9.0]:
		draw_circle(Vector2(x, -1.5), 1.2, brass.darkened(0.3))
	# the bell, flared down onto the stone
	var bell := PackedVector2Array([Vector2(-9, -2), Vector2(9, -2), Vector2(4, -9), Vector2(-4, -9)])
	draw_colored_polygon(bell, dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(7, -3), Vector2(3, -8), Vector2(-3, -8)]), brass)
	# the horn, curling up and over to the earpiece
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * (1.0 - i / 8.0)
		pts.append(Vector2(6 + cos(a) * 6.0, -14 - sin(a) * 6.0) if i > 0 else Vector2(0, -9))
	draw_polyline(pts, dark, 4.0)
	draw_polyline(pts, brass, 2.0)
	draw_circle(pts[pts.size() - 1] + Vector2(1, 2), 2.5, dark)
	draw_circle(pts[pts.size() - 1] + Vector2(1, 2), 1.5, brass.darkened(0.2))
	# the dial: a round face where the horn leaves the bell
	var c := Vector2(0, -14)
	draw_circle(c, 6.5, dark)
	draw_circle(c, 5.2, Color(0.9, 0.86, 0.75))
	for k in RANGES.size():
		draw_circle(c + Vector2(-3 + k * 3, 3.2), 0.9, Color(0.8, 0.2, 0.15) if k == mode else steel)
	if _show > 0.0:
		# heard: a red needle toward the digging, and an arrow out beyond the dial
		var a := clampf(_show / 1.0, 0.0, 1.0)
		var red := Color(0.95, 0.25, 0.15, a)
		draw_line(c, c + _dir * 4.5, red, 1.5)
		var pulse := 1.0 + 0.15 * sin(_anim * 12.0)
		var tip := c + _dir * 28.0 * pulse
		var base := c + _dir * 14.0
		var side := _dir.orthogonal() * 4.0
		draw_line(base, tip, Color(0.1, 0.08, 0.07, a), 4.0)
		draw_line(base, tip, red, 2.0)
		draw_colored_polygon(PackedVector2Array([tip + _dir * 5.0, tip + side, tip - side]), red)
	else:
		draw_line(c, c + Vector2(0, -4), Color(0.2, 0.18, 0.16), 1.0)
	if _flash > 0.0:
		# rings off the bell: it heard something
		for r in [10.0, 16.0]:
			draw_arc(Vector2(0, -4), r * (1.5 - _flash * 0.5), PI * 1.1, PI * 1.9, 10, Color(1, 0.85, 0.5, _flash * 0.6), 1.0)
