extends Node2D
## Hourglass: a brass-framed sand-glass swung on a steel stand, a timer
## that runs on grit. Grit dropped on its top is taken in through the cap's
## funnel slot and heaps in the upper bulb (up to CAP grains in the glass;
## any more roll off); it trickles through the neck, one grain every DRIP
## seconds, into the lower bulb. When the upper bulb runs dry it fires
## what's at its pull-wire's end (drag it; unwired, around itself), so the
## timer's length is the grit you gave it: 5 grains, 2 s. Any other ore
## is turned aside off the rounded cap. Walkers pass.
##
## A signal (trigger: a tally wheel, relay, latch...) or a click turns it
## over: a half-turn in FLIP s, the full lower bulb becomes the top and it
## runs again with the same grit. Drop the wire's end on the glass itself
## and it turns itself over every time it runs out: a clock that ticks on
## as long as it's fed nothing and loses nothing. (Only the wire's end on
## the glass fires it back; an unwired one never turns itself.) A signal
## that comes while it's already turning is dropped.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const ORE_ONLY := 64
const CAP := 20                  # grains the glass holds, both bulbs together
const DRIP := 0.4                # s per grain through the neck
const FLIP := 0.4                # s for the half-turn
const GRAIN_AREA := 7.4          # px² of bulb a grain fills (20 fill ~80%)
const PROFILE := [Vector2(0, 1), Vector2(1, 1), Vector2(9, 6), Vector2(18, 6), Vector2(20, 4)]   # (d from the neck, half-width) of a bulb's inside, as the art
const SELF_R := 14.0             # a wire end this close to the neck is wired to itself

@export var wire_to := Vector2(50, 30)   # drag its end to what it should fire
@export var upper := 0           # grains in the top bulb (it runs while > 0)
@export var lower := 0           # grains in the bottom bulb

var fired := 0                   # tests: runs finished
var taken := 0                   # tests: grit caught
var refused := 0                 # tests: pieces turned aside (not grit, or full)
var flips := 0                   # tests
var dropped := 0                 # tests: signals ignored mid-turn
var age := 0.0                   # tests: game time since placed
var took_at := 0.0               # tests: age at the last grit taken
var fired_at := 0.0              # tests: age at the last firing
var _drip := 0.0
var _ran := false                # a grain has gone through since the last firing
var _flip_t := 0.0               # > 0: turning over
var _flash := 0.0
var _dragging := false
var _frame: Sprite2D             # art: caps, posts and the glass (turns)
var _front: Sprite2D             # art: glints, over the grit (turns)
var _grit_l := Color(0.58, 0.64, 0.56)
var _grit := Color(0.45, 0.53, 0.47)
var _grit_d := Color(0.3, 0.34, 0.3)


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too: the
	# stand behind, the glass over it and behind our _draw (the grit), the
	# glints over the grit
	var st := Sprite2D.new()
	st.texture = preload("res://assets/sprites/hourglass_stand.png")
	st.centered = false
	st.offset = Vector2(-18, -5)
	st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	st.show_behind_parent = true
	add_child(st)
	_frame = Sprite2D.new()
	_frame.texture = preload("res://assets/sprites/hourglass_frame.png")
	_frame.centered = false
	_frame.offset = Vector2(-13, -26)
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.show_behind_parent = true
	add_child(_frame)
	_front = Sprite2D.new()
	_front.texture = preload("res://assets/sprites/hourglass_front.png")
	_front.centered = false
	_front.offset = Vector2(-13, -26)
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_front)
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	upper = clampi(upper, 0, CAP)
	lower = clampi(lower, 0, CAP - upper)
	# the glass, rounded at both ends so what isn't taken rolls off
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 11.0
	cap.height = 50.0
	cs.shape = cap
	body.add_child(cs)
	add_child(body)
	# the funnel: over the top cap, reaching up so grit is caught before it
	# lands on the glass
	var mouth := Area2D.new()
	mouth.collision_layer = 0
	mouth.collision_mask = 2
	var ms := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 14)
	ms.shape = r
	ms.position = Vector2(0, -31)
	mouth.add_child(ms)
	add_child(mouth)
	mouth.body_entered.connect(_take, CONNECT_DEFERRED)


func _take(b) -> void:
	if not is_instance_valid(b) or not (b is RigidBody2D) or b.is_queued_for_deletion():
		return
	if b.get("kind") == "grit" and not b.is_in_group("ingots") and _flip_t <= 0 and upper + lower < CAP:
		upper += 1
		taken += 1
		took_at = age
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("ore"), -20.0, 1.6)
		queue_redraw()
		return
	# not ours (or no room, or turning): off the cap, to whichever side it's on
	refused += 1
	var dx: float = b.global_position.x - global_position.x
	var s := signf(dx) if absf(dx) > 0.5 else (1.0 if randf() < 0.5 else -1.0)
	b.linear_velocity.x = s * maxf(absf(b.linear_velocity.x), 60.0)


func trigger() -> void:
	if has_meta("ghost"):
		return
	if _flip_t > 0:
		dropped += 1
		return
	_flip_t = FLIP
	flips += 1
	SFX.play_small(self, SFX.sfx_ratchet(), -14.0, 0.9)
	queue_redraw()


func fire() -> void:
	fired += 1
	fired_at = age
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 1.7)
	# wired, only at the wire's end, and back into itself only if the end is
	# on the glass; unwired, around itself (never itself)
	var points := [global_position + wire_to] if wire_to != Vector2.ZERO else [global_position]
	var own := wire_to != Vector2.ZERO and wire_to.length() < SELF_R
	for n in Tripwire.linked_to(get_tree(), points):
		if (n != self or own) and n.has_method("trigger"):
			n.trigger()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	age += delta
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()
	if _flip_t > 0:
		_flip_t -= delta
		if _flip_t <= 0:
			# turned: what was below is on top now, and the timing starts over
			_flip_t = 0.0
			var u := upper
			upper = lower
			lower = u
			_drip = 0.0
			_ran = false
		queue_redraw()
		return
	if upper <= 0:
		_drip = 0.0
		return
	_drip += delta
	if _drip >= DRIP:
		_drip -= DRIP
		upper -= 1
		lower += 1
		_ran = true
		if upper == 0:
			_ran = false
			fire()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position() - global_position
		if event.pressed and wire_to != Vector2.ZERO and m.distance_to(wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and absf(m.x) < 12 and absf(m.y) < 25:
			trigger()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position
		queue_redraw()


## The inside half-width of a bulb at d px from the neck.
static func _half_w(d: float) -> float:
	for i in range(1, PROFILE.size()):
		var a: Vector2 = PROFILE[i - 1]
		var b: Vector2 = PROFILE[i]
		if d <= b.x:
			return lerpf(a.y, b.y, (d - a.x) / maxf(b.x - a.x, 0.001))
	return PROFILE[PROFILE.size() - 1].y


## How far from the neck a fill of `area` px² reaches, filling from d0 toward d1.
static func _reach(d0: float, d1: float, area: float) -> float:
	var step := 0.25 * signf(d1 - d0)
	var d := d0
	var acc := 0.0
	while acc < area and absf(d - d0) < absf(d1 - d0):
		acc += 2.0 * _half_w(d + step * 0.5) * absf(step)
		d += step
	return d


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(11, -20), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, brass.lerp(Color(1, 0.95, 0.7), _flash))
	# the glass turns as a whole (the grit in it too)
	var turn := 0.0
	if _flip_t > 0:
		turn = PI * smoothstep(0.0, 1.0, 1.0 - _flip_t / FLIP)
	_frame.rotation = turn
	_front.rotation = turn
	_frame.self_modulate = Color.WHITE.lerp(Color(1.35, 1.28, 1.1), _flash)
	draw_set_transform(Vector2.ZERO, turn)
	# the top bulb: heaped down against the neck, a dimple where it drains
	if upper > 0:
		var h := _reach(0.5, 20.0, upper * GRAIN_AREA)
		var pts := PackedVector2Array()
		var d := 0.5
		while d < h:
			pts.append(Vector2(-_half_w(d), -d))
			d += 1.0
		var wt := _half_w(h)
		pts.append(Vector2(-wt, -h))
		pts.append(Vector2(-minf(1.5, wt * 0.4), -h + (1.5 if _ran or _drip > 0 else 0.5)))
		pts.append(Vector2(minf(1.5, wt * 0.4), -h + (1.5 if _ran or _drip > 0 else 0.5)))
		pts.append(Vector2(wt, -h))
		d = h - 1.0
		while d > 0.5:
			pts.append(Vector2(_half_w(d), -d))
			d -= 1.0
		pts.append(Vector2(_half_w(0.5), -0.5))
		if pts.size() >= 3:
			draw_colored_polygon(pts, _grit)
		draw_line(Vector2(-wt, -h), Vector2(wt, -h), _grit_l, 1.0)
	# the bottom bulb: a heap growing up off the floor
	var top_y := 20.0
	if lower > 0:
		var hb := _reach(20.0, 0.5, lower * GRAIN_AREA)
		var peak := minf(3.0, 20.0 - hb + 1.0)
		var pts2 := PackedVector2Array()
		pts2.append(Vector2(-_half_w(19.9), 19.9))
		var d2 := 19.0
		while d2 > hb:
			pts2.append(Vector2(-_half_w(d2), d2))
			d2 -= 1.0
		var wb := _half_w(hb)
		pts2.append(Vector2(-wb, hb))
		pts2.append(Vector2(0, hb - peak))
		pts2.append(Vector2(wb, hb))
		d2 = ceilf(hb)
		while d2 < 19.9:
			pts2.append(Vector2(_half_w(d2), d2))
			d2 += 1.0
		pts2.append(Vector2(_half_w(19.9), 19.9))
		draw_colored_polygon(pts2, _grit)
		draw_line(Vector2(-wb, hb), Vector2(0, hb - peak), _grit_l, 1.0)
		draw_line(Vector2(0, hb - peak), Vector2(wb, hb), _grit_d, 1.0)
		top_y = hb - peak
	# the stream through the neck, and the grain on its way down
	if upper > 0 and _flip_t <= 0:
		draw_line(Vector2(0, 0), Vector2(0, top_y), Color(_grit_l, 0.55), 1.0)
		var f := _drip / DRIP
		draw_rect(Rect2(-0.5, lerpf(0.0, top_y - 1.0, f), 1.0, 1.5), _grit_l)
	draw_set_transform(Vector2.ZERO, 0.0)
	# how many grains it's holding up top (its time left)
	var font := ThemeDB.fallback_font
	var label := "%.1fs" % maxf(0.0, upper * DRIP - _drip) if upper > 0 else "%d" % (upper + lower)
	draw_string(font, Vector2(-9, -30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
