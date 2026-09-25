extends Node2D
## The prospector's grappling hook (Shift, aimed with the mouse). A brass
## claw on a chain:
##   - into rock or a machine: it bites, and holding Shift reels you in
##     (up cliff faces, out of pits, across gaps) and hangs you there; let
##     go mid-reel and you fly on with the momentum, jump to spring off
##   - into a light enemy: it yanks it off its feet toward you
##   - into a heavy one (titan, bridge engine, the Foundry): it hooks on and
##     reels *you* in, riding along as it moves
##   - into loose ore/scrap: it drags the piece back to you
## Top-level node drawing in world coordinates; a child of the player.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

enum State { IDLE, FLYING, ANCHORED, RETRACT }

const SPEED := 950.0          # hook flight
const MAX_LEN := 280.0
const REEL := 400.0           # reeling the player in
const ARRIVE := 22.0
const YANK := Vector2(330, -180)
const HAND := Vector2(0, -14)

var state := State.IDLE
var hook := Vector2.ZERO
var anchor_node: Node2D = null
var anchor_off := Vector2.ZERO
var reels := 0                # tests
var yanks := 0
var _dir := Vector2.RIGHT
var _player: CharacterBody2D
var _dragged: RigidBody2D = null


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	top_level = true
	z_index = 5
	global_position = Vector2.ZERO


func _hand() -> Vector2:
	return _player.global_position + HAND


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.keycode != KEY_SHIFT or event.echo:
		return
	if event.pressed and state == State.IDLE and not _player.get("_dead"):
		fire(_player.get_global_mouse_position())
	elif not event.pressed and state in [State.FLYING, State.ANCHORED]:
		release()


func fire(at: Vector2) -> void:
	state = State.FLYING
	hook = _hand()
	_dir = (at - hook).normalized() if at.distance_to(hook) > 1 else Vector2.RIGHT
	anchor_node = null
	_dragged = null
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 1.5)


func release() -> void:
	if state == State.ANCHORED and _dragged == null:
		_player.set("_launch_timer", 0.25)   # let go mid-reel: fly on with the momentum
	state = State.RETRACT
	anchor_node = null
	_dragged = null


func _heavy(n) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.get("enemy_type") == 0:
		return true
	var s = n.get_script()
	return s != null and s.resource_path.get_file() in ["bridger.gd", "foundry.gd", "sapper.gd"]


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_fly(delta)
		State.ANCHORED:
			_hold(delta)
		State.RETRACT:
			var to := _hand() - hook
			if to.length() < SPEED * delta * 1.5:
				state = State.IDLE
			else:
				hook += to.normalized() * SPEED * 1.4 * delta
	queue_redraw()


func _fly(delta: float) -> void:
	var from := hook
	var to := hook + _dir * SPEED * delta
	# enemies first, by their hit areas (their physics boxes are only feet)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("hit_center"):
			continue
		var c: Vector2 = e.hit_center()
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 12.0
		if Geometry2D.get_closest_point_to_segment(c, from, to).distance_to(c) < r:
			hook = c
			_hit_enemy(e)
			return
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2)
	q.exclude = [_player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		hook = to
		if hook.distance_to(_hand()) > MAX_LEN:
			state = State.RETRACT
		return
	hook = hit.position
	var c = hit.collider
	if c is RigidBody2D and c.is_in_group("ore") and not c.freeze:
		_dragged = c
		state = State.ANCHORED
		SFX.play_small(self, SFX.sfx_clink(), -6.0, 1.2)
		return
	# rock or a machine: bite and reel in
	_anchor(c if c is Node2D and not (c is TileMapLayer) else null)


func _hit_enemy(e) -> void:
	if _heavy(e):
		_anchor(e)   # too heavy to budge: it reels you in instead
		return
	# a light one: yank it off its feet toward you
	var away := signf(_player.global_position.x - e.global_position.x)
	if e.has_method("knock"):
		e.knock(Vector2(away * YANK.x, YANK.y))
	if e.has_method("take_damage"):
		e.take_damage(1)   # a magpie drops what it's carrying
	yanks += 1
	FX.burst(get_parent(), hook, Color(0.9, 0.8, 0.5), 5, 70.0, 0.25, 1.2)
	SFX.play(self, SFX.sfx_ore_knock("metal"), -4.0, 0.9)
	state = State.RETRACT


func _anchor(n) -> void:
	anchor_node = n
	anchor_off = hook - anchor_node.global_position if anchor_node else Vector2.ZERO
	state = State.ANCHORED
	reels += 1
	FX.burst(get_parent(), hook, Color(0.7, 0.62, 0.5), 5, 50.0, 0.3, 1.4)
	SFX.play_small(self, SFX.sfx_ore_knock("ground"), -4.0, 1.1)


func _hold(_delta: float) -> void:
	if _dragged:
		if not is_instance_valid(_dragged):
			release()
			return
		hook = _dragged.global_position
		var d := _hand() - hook
		if d.length() < ARRIVE:
			_dragged.linear_velocity *= 0.3
			release()
			return
		_dragged.sleeping = false
		_dragged.linear_velocity = d.normalized() * 360.0
		return
	if anchor_node:
		if not is_instance_valid(anchor_node) or ("_dying" in anchor_node and anchor_node._dying):
			release()
			return
		hook = anchor_node.global_position + anchor_off
	var d := hook - _hand()
	if d.length() > MAX_LEN * 1.2:
		release()
		return
	_player.set("_launch_timer", 0.05)
	if d.length() < ARRIVE:
		# hanging from the hook: hold there until Shift is let go; jump to
		# spring off it
		_player.velocity = (d - d.normalized() * (ARRIVE - 4.0)) * 12.0 - Vector2(0, 980.0 * _delta)
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_W):
			_player.velocity = Vector2(_player.velocity.x, -380.0)
			release()
		return
	_player.velocity = d.normalized() * REEL


func _draw() -> void:
	if state == State.IDLE:
		return
	var a := _hand()
	var b := hook
	var n := maxi(2, int(a.distance_to(b) / 5.0))
	for k in n:
		var p := a.lerp(b, float(k) / n)
		var q := a.lerp(b, float(k + 1) / n)
		draw_line(p, q, Color(0.16, 0.15, 0.12), 3.0)
		draw_line(p, q, Color(0.72, 0.6, 0.4) if k % 2 == 0 else Color(0.5, 0.52, 0.55), 1.5)
	# the claw: three brass prongs around a steel hub
	var dir := (b - a).normalized() if b.distance_to(a) > 1 else _dir
	for ang in [-0.7, 0.0, 0.7]:
		var t := b + dir.rotated(ang) * 5.0
		draw_line(b, t, Color(0.16, 0.15, 0.12), 3.0)
		draw_line(b, t, Color(0.85, 0.72, 0.45), 1.5)
	draw_circle(b, 2.2, Color(0.16, 0.15, 0.12))
	draw_circle(b, 1.4, Color(0.62, 0.68, 0.7))
