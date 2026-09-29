extends Node2D
## Wrecking ball: a heavy iron ball on a long chain from a ceiling bracket,
## held cocked out to one side by a latch. A trigger (tripwire, plate, bell,
## tally) or a click on the latch lets it go: it swings down through the
## walkers' path, smashing and flinging whatever it meets, and swings on
## until it settles. It's wound back up by weight: each piece dropped into
## the winch bucket on the bracket cranks it a quarter of the way, and four
## re-arm it. A trap your marble line reloads.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const L := 70.0                  # chain length
const R := 9.0                   # ball radius
const COCK := 1.35               # rad out from hanging straight down
const G := 900.0
const WINDS := 4

@export var side := 1.0          # it's cocked out this way, swings the other

var releases := 0                # tests
var hits := 0
var armed := true
var pose := 1.0                  # how far cocked it starts (build-bar icon: less, to fit)
var _th := 0.0                   # angle from straight down (+ toward +x)
var _om := 0.0
var _wind := 0
var _seen := {}
var _free_t := 0.0
var _chain_art: Sprite2D         # art: the chain and ball, turned about the pivot
var _latch: Sprite2D


func _ready() -> void:
	z_index = 2
	_th = COCK * side * pose
	# the sprites first, so ghosts and build-bar icons get them too: the
	# bracket and bucket behind our own _draw (the gauge lights)
	var br := _spr(preload("res://assets/sprites/wrecking_bracket.png"), Vector2(-29, -10))
	br.show_behind_parent = true
	br.scale = Vector2(1.0 if side >= 0.0 else -1.0, 1)
	_latch = _spr(preload("res://assets/sprites/wrecking_latch.png"), Vector2(-3, -3))
	_latch.hframes = 2
	_latch.position = Vector2(side * 10.0, -2)
	_latch.scale = br.scale
	_chain_art = _spr(preload("res://assets/sprites/wrecking_chain.png"), Vector2(-11, -2))
	_spr(preload("res://assets/sprites/wrecking_cap.png"), Vector2(-3.5, -3.5))
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
	add_child(sp)
	return sp


func _pose() -> void:
	_chain_art.rotation = -_th
	_latch.frame = 0 if armed else 1


func ball() -> Vector2:
	return global_position + Vector2(sin(_th), cos(_th)) * L


func _bucket() -> Vector2:
	return global_position + Vector2(-side * 18.0, 2.0)


func trigger() -> void:
	if not armed:
		return
	armed = false
	releases += 1
	_wind = 0
	_om = 0.0
	_free_t = 0.0
	SFX.play_small(self, SFX.sfx_latch(), -4.0, 0.6)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	# the winch: pieces dropped in the bucket crank it back
	if not armed:
		for o in get_tree().get_nodes_in_group("ore"):
			if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(_bucket()) < 9.0:
				o.queue_free()
				_wind += 1
				SFX.play_small(self, SFX.sfx_ratchet(), -10.0, 0.9)
				if _wind >= WINDS:
					break
	if armed:
		_th = move_toward(_th, COCK * side, 2.0 * delta)
		_om = 0.0
	elif _wind > 0:
		# being wound: hauled toward the cocked angle, a quarter per piece
		var want := COCK * side * float(_wind) / WINDS
		_th = move_toward(_th, want, 1.5 * delta)
		_om = 0.0
		if _wind >= WINDS and absf(_th - COCK * side) < 0.01:
			armed = true
			SFX.play_small(self, SFX.sfx_latch(), -8.0, 1.2)
	else:
		_free_t += delta
		var damp := 0.15 if _free_t < 4.0 else 1.5
		_om += (-G / L * sin(_th) - damp * _om) * delta
		_th += _om * delta
		var v := Vector2(cos(_th), -sin(_th)) * _om * L
		var sp := v.length()
		if sp > 120.0:
			var b := ball()
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
					continue
				if _seen.get(e.get_instance_id(), 0.0) > now:
					continue
				var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
				var r: float = e.hit_radius() if e.has_method("hit_radius") else 10.0
				if c.distance_to(b) < r + R:
					_seen[e.get_instance_id()] = now + 0.6
					e.take_damage(int(4 + 14.0 * clampf(sp / 450.0, 0.0, 1.0)))
					if is_instance_valid(e) and e.has_method("knock"):
						e.knock(v.normalized() * minf(sp, 500.0) + Vector2(0, -160))
					hits += 1
					FX.burst(get_parent(), b, Color(0.85, 0.95, 1.0), 10, 140.0, 0.2, 2.0, 0.0)
					FX.shake(self, 5.0, 0.25)
					SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), -2.0, 0.7)
			load("res://scripts/track/track_net.gd").eject_at(self, b, R + 6.0)   # riders there are knocked off the track too
			for o in get_tree().get_nodes_in_group("ore"):
				if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(b) < R + 6.0:
					o.sleeping = false
					o.linear_velocity = v.limit_length(500.0)
	_pose()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(side * 10.0, -2)) < 9:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# (the bracket, bucket, latch, chain, ball and pivot cap are sprites) the
	# winch gauge: a quarter lit per piece in the bucket
	var brass := Color(0.85, 0.65, 0.35)
	var bk := _bucket() - global_position
	for i in WINDS:
		var lit := armed or i < _wind
		draw_rect(Rect2(bk.x - 6 + i * 3.5, bk.y - 9, 2.5, 2), brass if lit else Color(0.25, 0.22, 0.2))
