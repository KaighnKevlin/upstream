extends Node2D
## Balloon lift: a gas bottle with a filler nozzle over a little basket.
## A piece that rolls or drops into the basket is tied to a balloon and
## floats straight up, bobbing, until it reaches the pin (click the bottle:
## 80 / 160 / 240 / 320 px up) or bumps the rock above; the balloon pops
## and the piece is tossed off toward `side` (the pin's flag) onto a
## ledge or chute beside the rise. No track: it lifts through open air, so a
## balloon line crosses a chasm's height where nothing can be built.
## A few ride at once; while the air's full, arrivals wait in the basket.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const HEIGHTS := [80.0, 160.0, 240.0, 320.0]
const RISE := 70.0               # px/s
const MAX_UP := 5
const FILL := 0.5                # s to fill a balloon
const BALLOON_TEX := preload("res://assets/sprites/balloon_lift_balloon.png")   # 4 frames of 16x20, COLORS order
const PIN_TEX := preload("res://assets/sprites/balloon_lift_pin.png")
const COLORS := [Color(0.85, 0.3, 0.25), Color(0.95, 0.75, 0.3), Color(0.35, 0.6, 0.85), Color(0.5, 0.8, 0.45)]

@export var mode := 1
@export var side := 1.0             # the popped piece is tossed this way (onto a ledge)

var lifted := 0                  # tests
var _up: Array = []              # [ore, colour index, age]
var _wait: Array = []            # in the basket
var _fill := 0.0
var _n := 0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# the sprite first, so ghosts and build-bar icons get it too; behind our
	# own _draw (pin, balloons, the height label)
	var sp := Sprite2D.new()
	sp.texture = preload("res://assets/sprites/balloon_lift.png")
	sp.centered = false
	sp.offset = Vector2(-20, -30)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	if has_meta("ghost"):
		return


func _solid_at(p: Vector2) -> bool:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return false
	return tm.get_cell_source_id(tm.local_to_map(tm.to_local(p))) != -1


func _hold(o, at: Vector2, delta: float) -> void:
	o.linear_velocity = (at - o.global_position) / delta
	o.angular_velocity = 0.0
	if "_timer" in o:
		o._timer = 0.0


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o in _wait or o.has_meta("store_material"):
			continue
		if o.get_meta("balloon_until", 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 10 and p.y > -18 and p.y < 2:
			var held := false
			for u in _up:
				if u[0] == o:
					held = true
			if not held:
				o.gravity_scale = 0.0
				_wait.append(o)
	_wait = _wait.filter(func(o): return is_instance_valid(o))
	for i in _wait.size():
		_hold(_wait[i], global_position + Vector2((i % 3) * 5 - 5, -6 - (i / 3) * 5), delta)
	# fill the next balloon
	if not _wait.is_empty() and _up.size() < MAX_UP:
		_fill += delta
		if _fill >= FILL:
			_fill = 0.0
			var o = _wait.pop_front()
			_up.append([o, _n % COLORS.size(), 0.0])
			_n += 1
			SFX.play_small(self, SFX.sfx_roll(), -16.0, 1.6)
	else:
		_fill = 0.0
	var top: float = global_position.y - HEIGHTS[mode]
	var keep: Array = []
	for u in _up:
		var o = u[0]
		if not is_instance_valid(o):
			continue
		u[2] += delta
		var y: float = o.global_position.y - RISE * delta
		var x: float = global_position.x + sin(u[2] * 2.2 + u[1]) * 4.0 * minf(1.0, u[2])
		if y <= top or _solid_at(Vector2(x, y - 20)):
			_pop(o, u[1])
			continue
		_hold(o, Vector2(x, y), delta)
		keep.append(u)
	_up = keep
	queue_redraw()


func _pop(o, ci: int) -> void:
	o.gravity_scale = 1.0
	o.linear_velocity = Vector2(side * 130.0, -60)
	o.set_meta("balloon_until", Time.get_ticks_msec() / 1000.0 + 2.0)
	lifted += 1
	FX.burst(get_parent(), o.global_position + Vector2(0, -16), COLORS[ci], 8, 80.0, 0.25, 1.5)
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 2.4)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(-14, -10)) < 10:
		mode = (mode + 1) % HEIGHTS.size()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _balloon(ci: int, at: Vector2, alpha := 1.0) -> void:
	draw_texture_rect_region(BALLOON_TEX, Rect2(at - Vector2(8, 8), Vector2(16, 20)), Rect2(ci * 16, 0, 16, 20), Color(1, 1, 1, alpha))


func _draw() -> void:
	var h: float = HEIGHTS[mode]
	# the pin it pops at: a faint line up and a little brass pin, its flag toward `side`
	for y in range(-20, -int(h), -8):
		draw_line(Vector2(0, y), Vector2(0, y - 3), Color(0.85, 0.65, 0.35, 0.15), 1.0)
	draw_set_transform(Vector2(0, -h), 0.0, Vector2(signf(side) if side != 0.0 else 1.0, 1))
	draw_texture(PIN_TEX, Vector2(-3, -11))
	draw_set_transform(Vector2.ZERO)
	# (the gas bottle, its nozzle and the basket are the sprite)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-22, -32), "%d" % int(h), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
	# a balloon filling, then each one up with its string
	if _fill > 0.0:
		var r := 7.0 * _fill / FILL
		draw_set_transform(Vector2(0, -20 - r), 0.0, Vector2(r / 7.0, r / 7.0))
		_balloon(_n % COLORS.size(), Vector2.ZERO, 0.9)
		draw_set_transform(Vector2.ZERO)
	for u in _up:
		var o = u[0]
		if not is_instance_valid(o):
			continue
		var at: Vector2 = to_local(o.global_position)
		var b := at + Vector2(sin(u[2] * 3.0) * 1.5, -18)
		draw_line(at, b + Vector2(0, 9), Color(0.85, 0.85, 0.8, 0.8), 1.0)
		_balloon(u[1], b.round())
