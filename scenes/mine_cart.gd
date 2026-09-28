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
const TRACK_TEX := preload("res://assets/sprites/mine_track.png")    # rails on sleepers, tiled
const STOP_TEX := preload("res://assets/sprites/mine_stop.png")
const HOPPER_TEX := preload("res://assets/sprites/mine_hopper.png")
const CART_TEX := preload("res://assets/sprites/mine_cart.png")
const WHEEL_TEX := preload("res://assets/sprites/mine_wheel.png")

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
var _art: Node2D                 # art: the track, stops and hopper (tiled along the track)
var _cart_art: Node2D            # the cart, rolled along and tipped
var _wheels: Array = []


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()
	_pose()


func _ready() -> void:
	z_index = 2
	# the art first, so ghosts and build-bar icons have it; behind our own
	# _draw (the load count)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	_cart_art = Node2D.new()
	_cart_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cart_art.show_behind_parent = true
	add_child(_cart_art)
	var tub := Sprite2D.new()
	tub.texture = CART_TEX
	tub.centered = false
	tub.offset = Vector2(-13, -13)
	_cart_art.add_child(tub)
	for x in [-6.0, 6.0]:
		var w := Sprite2D.new()
		w.texture = WHEEL_TEX
		w.position = Vector2(x, 1)
		_cart_art.add_child(w)
		_wheels.append(w)
	_pose()
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
	_pose()
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


## The cart's sprite where the cart is: along the track, tipped forward at
## the far end, its wheels turned by how far it's rolled (flipped on
## leftward tracks so it stays upright).
func _pose() -> void:
	if _cart_art == null:
		return
	var l := end_offset.length()
	var dir := end_offset / maxf(l, 1.0)
	var flip := 1.0 if dir.x >= 0 else -1.0
	var tip := 0.0
	if _state == 2:
		tip = 0.9 * signf(dir.x)
	_cart_art.position = _cart()
	_cart_art.rotation = dir.angle() + tip
	_cart_art.scale = Vector2(1, flip)
	for w in _wheels:
		w.rotation = _s / 3.0
	if _art:
		_art.queue_redraw()


## The track tiled along its length (flipped on leftward runs so the rails
## stay under the line), a stop at each end, the hopper over the near one.
func _draw_art() -> void:
	var l := end_offset.length()
	if l < 0.1:
		return
	var dir := end_offset / l
	_art.draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(1, 1.0 if dir.x >= 0 else -1.0))
	_art.draw_texture_rect(TRACK_TEX, Rect2(0, -1, l, 10), true)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in [Vector2.ZERO, end_offset]:
		_art.draw_texture(STOP_TEX, p + Vector2(-4, -12))
	_art.draw_texture(HOPPER_TEX, Vector2(-14, -43))


func _draw() -> void:
	# the load count over the cart (the art is in the children)
	var c := _cart()
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-8, -16), "%d/%d" % [_load.size(), LOADS[mode]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
