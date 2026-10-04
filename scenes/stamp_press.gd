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
var _frame: Sprite2D               # art: the posts, the beam (jolts), the weight on its stem, cam, latch
var _beam: Sprite2D
var _weight: Sprite2D
var _rod: Sprite2D
var _cam: Sprite2D
var _pawl: Sprite2D


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw, which keeps the hopper's pips and the drive pulley on top
	_frame = _spr(preload("res://assets/sprites/stamp_frame.png"), Vector2(-42, -153))
	_rod = _spr(preload("res://assets/sprites/stamp_rod.png"), Vector2(-2, 0))
	_rod.region_enabled = true
	_rod.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rod.position = Vector2(0, TOP + 4)
	_weight = _spr(preload("res://assets/sprites/stamp_weight.png"), Vector2(-25, -23))
	_pawl = _spr(preload("res://assets/sprites/stamp_pawl.png"), Vector2(-1, -3))
	_beam = _spr(preload("res://assets/sprites/stamp_beam.png"), Vector2(-42, -184))
	_cam = _spr(preload("res://assets/sprites/stamp_cam.png"), Vector2(-7, -7))
	_cam.position = Vector2(0, TOP - 1)
	_pose()
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


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


## Art: the weight at its height, the stem down to it, the cam turning
## while it lifts, the latch out while it's held, the beam jolted by a blow.
func _pose() -> void:
	var head_y := -roundf(_h)
	_weight.position = Vector2(0, head_y)
	_rod.region_rect = Rect2(0, 0, 4, maxf(1.0, head_y - 20.0 - _rod.position.y))
	_cam.rotation = _h / RAISE * PI
	_pawl.visible = _state == State.UP
	_pawl.position = Vector2(-34, head_y - 12)
	var jolt := roundf(_thud * 1.5)
	_beam.position = Vector2(0, jolt)
	_cam.position = Vector2(0, TOP - 1 + jolt)


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
	SFX.play(self, SFX.sfx_thud(), -4.0, 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := Pointer.world(self) - global_position
	if absf(m.x) < HALF_W and m.y > -_h - 20 and m.y < -_h + 2:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_pose()
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	# frame, beam, cam, stem, weight, latch and hopper are sprites (see
	# _ready, _pose); what's waiting in the hopper is drawn over them
	for i in loaded.size():
		draw_circle(HOPPER + Vector2(-6 + i * 4, -3), 2.3, dark)
		draw_circle(HOPPER + Vector2(-6 + i * 4, -3), 1.8, steel.lightened(0.2) if loaded[i] == "iron" else Color(0.85, 0.55, 0.3))
	# powered: a drive pulley on the post that spins while it lifts
	if rate > Power.UNPOWERED + 0.05:
		draw_circle(Vector2(34, TOP + 14), 5.0, dark)
		draw_circle(Vector2(34, TOP + 14), 1.5, steel)
		draw_arc(Vector2(34, TOP + 14), 4.0, _lift_t * 8.0, _lift_t * 8.0 + 4.0, 8, brass, 1.5)


## Where this looks at ore (world rects), for the track net: a chute
## running through here drops its riders to physics ore over this stretch
## (scripts/track/track_net.gd, zones), so it sees and moves them as before.
func ore_watch() -> Array:
	return [Rect2(global_position - Vector2(HALF_W + 16.0, 40.0), Vector2(HALF_W + 16.0, 40.0) * 2.0)]
