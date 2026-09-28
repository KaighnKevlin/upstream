extends Node2D
## Grapeshot mortar: a squat iron pot on a brass bed, its wide mouth tipped
## up. Pieces dropped into the mouth are packed in (up to CAP) and held
## there. Nothing happens until it's fired: a trigger (a tally wheel, a load
## cell, a pressure plate, a tripwire) or a click lets the whole load go at
## once, lobbed high in a spread that comes down around the nearest walker
## in range. A burst for when a crowd arrives, not a steady trickle. Each
## piece hurts like any falling ore (iron hardest; a tower shield turns
## most copper even from above, iron punches through). With no walker in
## range it holds its load. Walkers pass through it.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const G := 980.0
const CAP := 8
const MOUTH := Vector2(8, -26)     # x flips with side
const RANGE := 520.0
const MIN_RANGE := 50.0
const SPREAD := 34.0               # px either side of the aim point
const RELOAD := 0.6

@export var side := 1.0

var loaded: Array[String] = []     # kinds packed in, in order
var fired := 0                     # tests: bursts
var shots := 0                     # tests: pieces fired
var last_target: Node2D = null
var _aim := -0.9                   # barrel angle from straight up (toward side)
var _cool := {}
var _kick := 0.0
var _t := 0.0


func _p(v: Vector2) -> Vector2:
	return Vector2(v.x * side, v.y)


func _ready() -> void:
	z_index = 2
	_aim = 0.55 * side
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = 64            # ore-only funnel lips around the mouth
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	body.physics_material_override = m
	for seg in [[Vector2(-14, -44), Vector2(-7, -30)], [Vector2(14, -44), Vector2(7, -30)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0] + Vector2(MOUTH.x * side, 0)
		s.b = seg[1] + Vector2(MOUTH.x * side, 0)
		cs.shape = s
		body.add_child(cs)
	add_child(body)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t -= delta
	_kick = maxf(0.0, _kick - delta * 4.0)
	var now := Time.get_ticks_msec() / 1000.0
	if loaded.size() < CAP:
		var mouth := global_position + Vector2(MOUTH.x * side, MOUTH.y)
		for o in get_tree().get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion() or _cool.get(o.get_instance_id(), 0.0) > now:
				continue
			var d: Vector2 = o.global_position - mouth
			if absf(d.x) < 10 and d.y > -14 and d.y < 6 and o.linear_velocity.y >= 0.0:
				var k = o.get("kind")
				if k == null:
					continue
				loaded.append(str(k))
				o.queue_free()
				SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 0.9)
				if loaded.size() >= CAP:
					break
	# the barrel eases round toward whatever it would shoot at
	var tg := _target()
	var want := 0.55 * side
	if tg:
		want = clampf((tg.global_position.x - global_position.x) / RANGE, -1.0, 1.0) * 0.8
		if absf(want) < 0.25:
			want = 0.25 * signf(want if want != 0.0 else side)
	_aim = lerpf(_aim, want, clampf(delta * 5.0, 0.0, 1.0))
	queue_redraw()


func _target() -> Node2D:
	var best: Node2D = null
	var bd := RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("_dying"):
			continue
		var d := absf(e.global_position.x - global_position.x)
		if d > MIN_RANGE and d < bd and absf(e.global_position.y - global_position.y) < 200:
			bd = d
			best = e
	return best


## Lets the whole load go at the nearest walker in range.
func trigger() -> void:
	if loaded.is_empty() or _t > 0.0:
		return
	var tg := _target()
	if tg == null:
		return
	last_target = tg
	var mouth := global_position + Vector2(MOUTH.x * side, MOUTH.y)
	var aim: Vector2 = tg.hit_center() if tg.has_method("hit_center") else tg.global_position
	var dist := absf(aim.x - mouth.x)
	var flight := clampf(0.95 + dist / 600.0, 1.0, 1.8)   # high: it comes down steep
	# lead it a little: where it will be when the shot comes down
	var lead := Vector2(tg.velocity.x, 0.0) * flight * 0.8 if "velocity" in tg else Vector2.ZERO
	var n := loaded.size()
	var now := Time.get_ticks_msec() / 1000.0
	for i in n:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = loaded[i]
		o.global_position = mouth + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		# fan the load out over a patch around the aim point, some short, some long
		var off := 0.0 if n == 1 else lerpf(-SPREAD, SPREAD, float(i) / (n - 1))
		var fl := flight * randf_range(0.93, 1.07)
		var dest := aim + lead + Vector2(off + randf_range(-6, 6), 0.0)
		var v := (dest - o.global_position - Vector2(0, 0.5 * G * fl * fl)) / fl
		get_parent().add_child(o)
		o.linear_velocity = v
		o.angular_velocity = randf_range(-10, 10)
		_cool[o.get_instance_id()] = now + 3.0
		shots += 1
	loaded.clear()
	fired += 1
	_t = RELOAD
	_kick = 1.0
	FX.burst(get_parent(), mouth + Vector2(0, -6), Color(1.0, 0.85, 0.5), 10, 120.0, 0.35, 1.6)
	FX.burst(get_parent(), mouth + Vector2(0, -8), Color(0.6, 0.55, 0.5, 0.8), 8, 50.0, 0.8, 2.2)
	SFX.play_small(self, SFX.sfx_turret_fire(), -2.0, 0.6)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -14)) < 16:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	# the bed: a brass sledge with a trunnion block
	draw_rect(Rect2(-20, -6, 40, 6), dark)
	draw_rect(Rect2(-19, -5, 38, 4), brass.darkened(0.3))
	draw_rect(Rect2(-9, -14, 18, 9), dark)
	# the pot, tipped toward the aim; it sits down on its bed when it fires
	var pivot := Vector2(0, -12 + _kick * 3.0)
	var up := Vector2(sin(_aim), -cos(_aim))
	var mouth := pivot + up * 20.0
	var across := Vector2(-up.y, up.x)
	var body := PackedVector2Array([
		pivot - across * 10.0 - up * 4.0, pivot + across * 10.0 - up * 4.0,
		mouth + across * 9.0, mouth - across * 9.0])
	draw_colored_polygon(body, dark)
	var inner := PackedVector2Array([
		pivot - across * 8.0 - up * 2.0, pivot + across * 8.0 - up * 2.0,
		mouth + across * 7.0 - up * 1.0, mouth - across * 7.0 - up * 1.0])
	draw_colored_polygon(inner, steel)
	# brass hoops and the muzzle rim
	for f in [0.3, 0.7]:
		var c := pivot.lerp(mouth, f)
		draw_line(c - across * 9.5, c + across * 9.5, brass, 2.0)
	draw_line(mouth - across * 10.0, mouth + across * 10.0, dark, 4.0)
	draw_line(mouth - across * 9.0, mouth + across * 9.0, brass, 2.0)
	draw_circle(pivot, 3.0, brass)
	# the loading funnel over the mouth's fixed catch point
	var m := Vector2(MOUTH.x * side, 0)
	for x in [-1.0, 1.0]:
		draw_line(m + Vector2(14 * x, -44), m + Vector2(7 * x, -30), dark, 3.0)
		draw_line(m + Vector2(14 * x, -44), m + Vector2(7 * x, -30), Color(0.6, 0.62, 0.66), 1.0)
	# the load, as pips round the bed: iron dark, copper orange
	for i in loaded.size():
		var col := steel.lightened(0.15) if loaded[i] == "iron" else Color(0.85, 0.55, 0.3)
		draw_circle(Vector2(-17 + (i % 8) * 4.8, -3), 1.8, col)
