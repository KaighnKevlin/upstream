extends Node2D
## Stamp press: a mine's ore stamp turned on the enemy. A tall iron frame
## straddles the walkers' path with a heavy iron weight hung in it. Each
## piece of ore dropped into the hopper on top is burned to lift the weight
## once (the piece is used up; a few more wait in the hopper). Raised, the
## weight is latched and it lets go when a walker is about to be under it
## (or on a trigger, or a click), coming down on whatever is beneath: a big
## blow and a moment's daze. Then it rests on the floor until the next
## piece lifts it. Lifting is slow unpowered; belted to a power source it
## resets about three times faster. It lets go a moment early, for where a
## walker will be, so even scuttlers get caught. Walkers pass through the
## frame; fliers go over it.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

enum State { DOWN, LIFTING, UP, DROPPING }

const HALF_W := 22.0               # the weight's face
const RAISE := 96.0                # how high it's lifted
const TOP := -150.0                # the frame's crossbeam
const HOPPER := Vector2(0, -160)   # where pieces are taken in
const HOLD := 4                    # pieces the hopper keeps waiting
const LIFT := 1.2                  # s to lift, fully powered (UNPOWERED rate: ~3.4 s)
const FALL_G := 2600.0             # it's pulled down hard (a spring-loaded drop)
const DAMAGE := 10
const DAZE := Vector2(0, 40)       # the knock it gives: stopped in its tracks
const LOOKAHEAD := 0.2             # s: lets go for where a walker will be

var loaded: Array[String] = []     # pieces waiting in the hopper
var stamps := 0                    # tests
var hits := 0
var damage_done := 0
var last_lift := 0.0               # s the last lift took
var rate := Power.UNPOWERED
var _state := State.DOWN
var _h := 0.0                      # the weight's height off the floor
var _v := 0.0
var _lift_t := 0.0
var _rate_t := 0.0
var _cool := {}
var _thud := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	add_to_group("power_users")
	var body := StaticBody2D.new()
	body.collision_layer = 64        # the hopper's lips, ore only
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	body.physics_material_override = m
	for x in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = HOPPER + Vector2(15 * x, -20)
		s.b = HOPPER + Vector2(8 * x, -2)
		cs.shape = s
		body.add_child(cs)
	add_child(body)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_rate_t -= delta
	if _rate_t <= 0.0:
		_rate_t = 0.25
		rate = Power.rate_at(get_tree(), global_position)
	_thud = maxf(0.0, _thud - delta * 3.0)
	var now := Time.get_ticks_msec() / 1000.0
	# the hopper: pieces go in and wait there to be burned
	if loaded.size() < HOLD:
		var at := global_position + HOPPER
		for o in get_tree().get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion() or _cool.get(o.get_instance_id(), 0.0) > now:
				continue
			var d: Vector2 = o.global_position - at
			if absf(d.x) < 10 and d.y > -14 and d.y < 8:
				var k = o.get("kind")
				if k == null:
					continue
				loaded.append(str(k))
				o.queue_free()
				SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 1.0)
				break
	match _state:
		State.DOWN:
			if not loaded.is_empty():
				loaded.pop_front()
				_state = State.LIFTING
				_lift_t = 0.0
		State.LIFTING:
			_lift_t += delta
			_h = minf(RAISE, _h + RAISE / LIFT * rate * delta)
			if _h >= RAISE:
				_state = State.UP
				last_lift = _lift_t
				SFX.play_small(self, SFX.sfx_clink(), -14.0, 0.8)
		State.UP:
			if _walker_below(LOOKAHEAD):
				trigger()
		State.DROPPING:
			_v += FALL_G * delta
			_h -= _v * delta
			if _h <= 0.0:
				_h = 0.0
				_land()
	queue_redraw()


## Is a walker under the weight, or about to be?
func _walker_below(ahead: float) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if _under(e, ahead):
			return true
	return false


func _under(e: Node, ahead: float) -> bool:
	if not is_instance_valid(e) or e.get("_dying") or not e.has_method("hit_radius"):
		return false
	if e.get("enemy_type") == 4:     # ornithopters fly over it
		return false
	var x: float = e.global_position.x
	if ahead > 0.0 and "velocity" in e:
		x += e.velocity.x * ahead
	var reach: float = HALF_W + e.hit_radius() * 0.4
	return absf(x - global_position.x) < reach and absf(e.global_position.y - global_position.y) < 30.0


## Lets the latched weight go.
func trigger() -> void:
	if _state != State.UP:
		return
	_state = State.DROPPING
	_v = 0.0


func _land() -> void:
	_state = State.DOWN
	stamps += 1
	_thud = 1.0
	var struck := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if _under(e, 0.0):
			e.take_damage(DAMAGE)
			if e.has_method("knock"):
				e.knock(DAZE)
			struck += 1
			hits += 1
			damage_done += DAMAGE
	# loose pieces under it jump
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and not o.freeze and absf(o.global_position.x - global_position.x) < HALF_W + 4 and absf(o.global_position.y - global_position.y) < 16:
			o.linear_velocity += Vector2(signf(o.global_position.x - global_position.x) * 160.0, -220.0)
	FX.burst(get_parent(), global_position + Vector2(0, -2), Color(0.55, 0.45, 0.35, 0.9), 10, 90.0, 0.4, 2.0)
	if struck > 0:
		FX.burst(get_parent(), global_position + Vector2(0, -12), Color(1.0, 0.85, 0.5), 10, 140.0, 0.3, 1.6)
	SFX.play(self, SFX.sfx_ore_knock("metal"), 0.0, 0.5)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_global_mouse_position() - global_position
	if absf(m.x) < HALF_W and m.y > -_h - 20 and m.y < -_h + 2:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var jolt := _thud * 1.5
	# the frame: two posts and a crossbeam, braced
	for x in [-34.0, 34.0]:
		draw_line(Vector2(x, 0), Vector2(x, TOP), dark, 6.0)
		draw_line(Vector2(x, 0), Vector2(x, TOP), steel, 3.0)
		draw_line(Vector2(x, TOP + 26), Vector2(x * 0.45, TOP), dark, 2.0)
		draw_rect(Rect2(x - 6, -4, 12, 4), dark)
	draw_line(Vector2(-40, TOP + jolt), Vector2(40, TOP + jolt), dark, 7.0)
	draw_line(Vector2(-40, TOP + jolt), Vector2(40, TOP + jolt), steel.lightened(0.1), 4.0)
	# the cam on the crossbeam that lifts it, turning while it lifts
	var cam_a := _h / RAISE * PI
	draw_circle(Vector2(0, TOP - 1), 6.0, dark)
	draw_circle(Vector2(0, TOP - 1), 4.5, brass)
	draw_line(Vector2(0, TOP - 1), Vector2(0, TOP - 1) + Vector2(cos(cam_a), sin(cam_a)) * 5.0, dark, 2.0)
	# the stem and the weight
	var head_y := -_h
	draw_line(Vector2(0, TOP + 3), Vector2(0, head_y - 18), dark, 5.0)
	draw_line(Vector2(0, TOP + 3), Vector2(0, head_y - 18), steel.lightened(0.25), 2.0)
	draw_rect(Rect2(-HALF_W - 1, head_y - 19, HALF_W * 2 + 2, 19), dark)
	draw_rect(Rect2(-HALF_W + 1, head_y - 17, HALF_W * 2 - 2, 13), steel)
	draw_rect(Rect2(-HALF_W + 1, head_y - 5, HALF_W * 2 - 2, 4), steel.darkened(0.35))
	for x in [-HALF_W + 5, HALF_W - 5]:
		draw_circle(Vector2(x, head_y - 11), 1.5, brass)
	# the latch: brass pawl out when it's held up
	if _state == State.UP:
		draw_line(Vector2(-34, head_y - 12), Vector2(-HALF_W - 1, head_y - 12), brass, 3.0)
	# the hopper, and what's waiting in it
	for x in [-1.0, 1.0]:
		draw_line(HOPPER + Vector2(15 * x, -20), HOPPER + Vector2(8 * x, -2), dark, 3.0)
		draw_line(HOPPER + Vector2(15 * x, -20), HOPPER + Vector2(8 * x, -2), brass, 1.5)
	for i in loaded.size():
		draw_circle(HOPPER + Vector2(-6 + i * 4, -3), 1.8, steel.lightened(0.2) if loaded[i] == "iron" else Color(0.85, 0.55, 0.3))
	# powered: a drive pulley on the post that spins while it lifts
	if rate > Power.UNPOWERED + 0.05:
		draw_circle(Vector2(34, TOP + 14), 5.0, dark)
		draw_arc(Vector2(34, TOP + 14), 4.0, _lift_t * 8.0, _lift_t * 8.0 + 4.0, 8, brass, 1.5)
