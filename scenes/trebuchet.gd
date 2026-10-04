extends Node2D
## Trebuchet: a throwing arm on an A-frame, powered by weight. Ore dropped
## into the counterweight box (its back end) is the power: the heavier the
## load, the farther it throws. Ore dropped into the sling (its front, on
## the ground) is the shot. A trigger (a tally wheel, a plate, a load cell)
## or a click looses it: the box drops, the arm swings and the sling flings
## its load high and far toward `side`; the counterweight ore spills out
## and the box must be refilled. Iron in the box outthrows copper.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const BOX := Vector2(-26, -40)   # the counterweight box, cocked up (x flips with side)
const SLING := Vector2(34, -6)   # the sling, on the ground in front
const V_PER := 190.0             # launch speed per sqrt(mass) of counterweight
const V_MAX := 900.0

@export var side := 1.0

var thrown := 0                  # tests
var last_speed := 0.0
var _box: Array = []
var _sling: Array = []
var _swing := 0.0                # 0 cocked .. 1 thrown
var _cool := {}
var _art: Node2D                 # frame, arm, box and sling sprites, mirrored by side
var _arm: Sprite2D
var _box_spr: Sprite2D
var _sling_spr: Sprite2D

const PIVOT := Vector2(0, -34)   # the axle (art only)
const COCKED := 0.52             # the arm's tilt when cocked: long end down in front
const THROW := 2.2               # how far it swings over when thrown (rad)


func _p(v: Vector2) -> Vector2:
	return Vector2(v.x * side, v.y)


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; drawn
	# throwing to +x, the whole art mirrored for side -1
	_art = Node2D.new()
	_art.scale = Vector2(side, 1)
	_art.show_behind_parent = true
	add_child(_art)
	_spr(preload("res://assets/sprites/trebuchet_frame.png"), Vector2(-26, -42))
	_box_spr = _spr(preload("res://assets/sprites/trebuchet_box.png"), Vector2(-12, -7))
	_arm = _spr(preload("res://assets/sprites/trebuchet_arm.png"), Vector2(-32, -5))
	_arm.position = PIVOT
	_sling_spr = _spr(preload("res://assets/sprites/trebuchet_sling.png"), Vector2(-13, -3))
	_pose()
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.add_child(sp)
	return sp


## Art: the arm swings about the axle from cocked (box up behind, sling end
## down in front) over the top as _swing goes 0 -> 1; the box hangs from its
## short end, the sling from its long end. In unmirrored (side +1) space.
func _pose() -> void:
	var a := COCKED - THROW * _swing
	_arm.rotation = a
	_box_spr.position = PIVOT + Vector2(-30, 0).rotated(a)
	var tip := PIVOT + Vector2(42, 0).rotated(a)
	# at rest the pouch lies on the ground at SLING; thrown, it whips out past the tip
	_sling_spr.position = (SLING + Vector2(0, -6)).lerp(tip + Vector2(12, 0).rotated(a), clampf(_swing * 1.5, 0.0, 1.0))


func _mass(arr: Array) -> float:
	var m := 0.0
	for b in arr:
		if is_instance_valid(b):
			m += b.mass
	return m


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _swing <= 0.0:
		for o in get_tree().get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or o in _box or o in _sling or _cool.get(o.get_instance_id(), 0.0) > now or not Hold.free_to_take(o, self):
				continue
			for pair in [[_box, BOX], [_sling, SLING]]:
				var c: Vector2 = global_position + _p(pair[1])
				if absf(o.global_position.x - c.x) < 12 and o.global_position.y > c.y - 18 and o.global_position.y < c.y + 4:
					pair[0].append(o)
					Hold.claim(o, self)
					o.gravity_scale = 0.0
					break
	else:
		_swing = maxf(0.0, _swing - delta * 0.8)   # winds back to cocked
	for pair in [[_box, BOX], [_sling, SLING]]:
		var arr: Array = pair[0]
		var i := 0
		for b in arr.duplicate():
			if not is_instance_valid(b):
				arr.erase(b)
				continue
			var at: Vector2 = global_position + _p(pair[1]) + Vector2((i % 3) * 5 - 5, -6 - (i / 3) * 6)
			Hold.claim(b, self)
			b.linear_velocity = (at - b.global_position) / delta
			if "_timer" in b:
				b._timer = 0.0
			i += 1
	queue_redraw()


func trigger() -> void:
	if _swing > 0.0 or _sling.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var m := _mass(_box)
	var v := clampf(V_PER * sqrt(m), 120.0, V_MAX)
	for b in _sling:
		if is_instance_valid(b):
			Hold.release(b, self)
			b.global_position = global_position + _p(Vector2(-10, -70))
			b.linear_velocity = Vector2(side * 0.72, -0.7).normalized() * v * randf_range(0.95, 1.05)
			_cool[b.get_instance_id()] = now + 2.0
	for b in _box:
		if is_instance_valid(b):
			Hold.release(b, self)
			b.linear_velocity = Vector2(-side * 60.0, 40.0)
			_cool[b.get_instance_id()] = now + 2.0
	_box.clear()
	_sling.clear()
	_swing = 1.0
	thrown += 1
	last_speed = v
	SFX.play_small(self, SFX.sfx_whoosh(), -6.0, 0.8)
	FX.burst(get_parent(), global_position + _p(Vector2(-10, -70)), Color(0.9, 0.8, 0.6), 6, 60.0, 0.3, 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Pointer.world(self).distance_to(global_position + Vector2(0, -30)) < 16:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_pose()   # frame, arm, box and sling are sprites (see _ready)
	# the sling's ropes, from the arm tip to the pouch
	var a := COCKED - THROW * _swing
	var tip := PIVOT + Vector2(42, 0).rotated(a)
	var pouch := _sling_spr.position
	for dx in [-10.0, 10.0]:
		var end := pouch + Vector2(dx, -1)
		if tip.distance_to(end) > 3.0:
			draw_line(_p(tip), _p(end), Color(0.7, 0.62, 0.45), 1.0)
	var font := ThemeDB.fallback_font
	var bx := _p(BOX)
	draw_string(font, bx + Vector2(-10, -20), "%.1f" % _mass(_box), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
