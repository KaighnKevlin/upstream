extends Node2D
## Mine cart: a little tipping cart on a straight track between two stops.
## Drag from the loading end (where it's placed) to the tipping end. Ore
## dropped into it at the loading end piles in; when it holds its load
## (click: 3 / 5 / 8) it runs down the track (faster the steeper), tips it
## all out at the far end, and is winched back empty (quicker with power:
## a gravity wheel or steam engine in reach). A hopper at the loading end
## holds what arrives while the cart's away. Batches, over distances a
## chute can't span. Ore-only layer: walkers pass through.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const LEN_MIN := 80.0
const LEN_MAX := 420.0
const LOADS := [3, 5, 8]
const RUN_V := 140.0             # px/s down the track (plus slope)
const BACK_V := 220.0            # px/s winched back at full power (0.35 of it unpowered)

@export var end_offset := Vector2(200, 30)
@export var mode := 1

var trips := 0                   # tests
var delivered := 0
var _load: Array = []
var _hopper: Array = []          # waiting at the loading end while the cart's away
var _s := 0.0                    # position along the track, px
var _state := 0                  # 0 loading, 1 running, 2 tipping, 3 returning
var _t := 0.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("power_users")


func _cart() -> Vector2:
	return end_offset.normalized() * _s


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var l := end_offset.length()
	var dir := end_offset / l
	# anything arriving at the loading end: into the cart if it's home and has
	# room, otherwise into the hopper to wait
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o in _load or o in _hopper or o.get_meta("cart_until", 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 14 and p.y > -40 and p.y < 2:
			o.gravity_scale = 0.0
			if _state == 0 and _load.size() < LOADS[mode]:
				_load.append(o)
			else:
				_hopper.append(o)
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 0.9)
	match _state:
		0:
			# the hopper tips what it's been holding into the cart first
			while not _hopper.is_empty() and _load.size() < LOADS[mode]:
				var h = _hopper.pop_front()
				if is_instance_valid(h):
					_load.append(h)
			if _load.size() >= LOADS[mode]:
				_state = 1
				SFX.play_small(self, SFX.sfx_roll(), -12.0, 0.8)
		1:
			_s = minf(l, _s + (RUN_V + maxf(dir.y, 0.0) * 200.0) * delta)
			if _s >= l:
				_state = 2
				_t = 0.5
		2:
			_t -= delta
			if _t <= 0:
				for o in _load:
					if is_instance_valid(o):
						o.gravity_scale = 1.0
						o.linear_velocity = Vector2(signf(dir.x) * 90.0, -30.0)
						o.set_meta("cart_until", now + 2.0)
						delivered += 1
				_load.clear()
				trips += 1
				_state = 3
				SFX.play_small(self, SFX.sfx_latch(), -10.0, 0.7)
		3:
			_s = maxf(0.0, _s - BACK_V * _rate * delta)
			if _s <= 0.0:
				_state = 0
	# the hopper's queue, stacked over the loading end
	for i in _hopper.size():
		var h = _hopper[i]
		if is_instance_valid(h):
			var at := global_position + Vector2((i % 2) * 6 - 3, -28 - (i / 2) * 6)
			h.linear_velocity = (at - h.global_position) / delta
			if "_timer" in h:
				h._timer = 0.0
	# carry the load in the cart
	var c := global_position + _cart()
	for i in _load.size():
		var o = _load[i]
		if is_instance_valid(o):
			var at := c + Vector2((i % 3) * 6 - 6, -8 - (i / 3) * 6)
			o.linear_velocity = (at - o.global_position) / delta
			if "_timer" in o:
				o._timer = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + _cart() + Vector2(0, -6)) < 12:
		mode = (mode + 1) % LOADS.size()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var steel := Color(0.42, 0.44, 0.5)
	var brass := Color(0.85, 0.65, 0.35)
	var l := end_offset.length()
	var dir := end_offset / maxf(l, 1.0)
	# the track: two rails and sleepers, a stop post at each end
	for off in [Vector2(0, 2), Vector2(0, 5)]:
		draw_line(off, end_offset + off, dark, 2.0)
		draw_line(off, end_offset + off, steel, 1.0)
	var k := 6.0
	while k < l:
		var p := dir * k
		draw_line(p + Vector2(-2, 7), p + Vector2(2, 1), Color(0.35, 0.25, 0.15), 2.0)
		k += 10.0
	for p in [Vector2.ZERO, end_offset]:
		draw_line(p + Vector2(0, 5), p + Vector2(0, -8), dark, 3.0)
	# the loading hopper over the near stop
	draw_line(Vector2(-10, -40), Vector2(-5, -22), dark, 2.0)
	draw_line(Vector2(10, -40), Vector2(5, -22), dark, 2.0)
	# the cart, tipped forward at the far end
	var c := _cart()
	var tip := 0.0
	if _state == 2:
		tip = 0.9 * signf(dir.x)
	draw_set_transform(c, dir.angle() + tip, Vector2.ONE)
	draw_rect(Rect2(-11, -12, 22, 12), dark)
	draw_rect(Rect2(-10, -11, 20, 10), Color(0.55, 0.4, 0.22))
	draw_line(Vector2(-10, -11), Vector2(10, -11), brass, 1.0)
	for x in [-6.0, 6.0]:
		draw_circle(Vector2(x, 1), 3.0, dark)
		draw_circle(Vector2(x, 1), 1.8, steel)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-8, -16), "%d/%d" % [_load.size(), LOADS[mode]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
