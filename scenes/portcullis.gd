extends Node2D
## Portcullis: an iron grille hung in a stone gateway on the floor, raised
## so walkers and pieces pass beneath. A trigger (tripwire, plate, bell,
## tally) or a click on the frame drops it: it slams down, hurting and
## flinging whatever's under it, and stays down, a wall walkers stop and
## hack at. It's hauled back up by weight: a counterweight bucket hangs on a
## chain over the pulleys, and each piece dropped in it lifts the gate a
## quarter; four raise it, and the bucket tips its load out. Every blow the
## walkers land jams the works, though: JAM of them wrench it up anyway.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const W := 20.0
const H := 48.0
const LIFT := 44.0               # raised, its spikes hang this high
const LOADS := 4
const JAM := 6
const DROP_T := 0.15             # s to slam down
const DAMAGE := 6
const BUCKET_X := -24.0
const PULLEY_Y := -105.0

var raised := true
var lift := 1.0                  # 0 down .. 1 raised
var drops := 0                   # tests
var crushed := 0
var blows := 0                   # since it last dropped (JAM force it up)
var hacked := 0                  # tests: blows, all told
var _load: Array = []            # pieces in the bucket
var _falling := false
var _seen := {}
var _tip := 0.0                  # the bucket tipping out, s left
var _rattle := 0.0               # art: the grille shaking in its grooves after a blow
var _shape: RectangleShape2D
var _cs: CollisionShape2D
var _grille: Sprite2D
var _bucket_art: Sprite2D
var _pulleys: Array = []
var _lights: Node2D


func _ready() -> void:
	z_index = 1
	# the sprites first, so ghosts and build-bar icons get them too (see
	# tools/art/gen_portcullis.py); the chain in our own _draw, under them
	_grille = _spr(preload("res://assets/sprites/portcullis_grille.png"), Vector2.ZERO, Vector2(-11, -50))
	_bucket_art = _spr(preload("res://assets/sprites/portcullis_bucket.png"), Vector2.ZERO, Vector2(-8, -6))
	_spr(preload("res://assets/sprites/portcullis_frame.png"), Vector2.ZERO, Vector2(-34, -112))
	for x in [0.0, BUCKET_X]:
		_pulleys.append(_spr(preload("res://assets/sprites/portcullis_pulley.png"), Vector2(x, PULLEY_Y), Vector2(-5.5, -5.5)))
	_lights = Node2D.new()
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	_pose()
	if has_meta("ghost"):
		return
	_snap_to_floor()
	add_to_group("triggerable")
	add_to_group("walls")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_cs = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(W - 2, H)
	_cs.shape = _shape
	body.add_child(_cs)
	add_child(body)
	_fit()


func _spr(tex: Texture2D, at: Vector2, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


## The bucket's rim, local: high while the gate's down, on the floor when up.
func _bucket_local() -> Vector2:
	return Vector2(BUCKET_X, -56.0 + lift * LIFT)


func _bucket() -> Vector2:
	return global_position + _bucket_local()


## How much of the doorway the grille fills, px (walkers hack at it over 12).
func height() -> float:
	return 0.0 if raised else H - lift * LIFT


func trigger() -> void:
	if not raised:
		return
	raised = false
	_falling = true
	_seen.clear()
	drops += 1
	blows = 0
	SFX.play_small(self, SFX.sfx_latch(), -4.0, 0.6)


## A walker's blow: the works jam a little more; JAM wrench it up.
func take_damage(_d: int) -> void:
	if raised or _falling:
		return
	blows += 1
	hacked += 1
	FX.burst(get_parent(), global_position + Vector2(0, -H * 0.5), Color(0.85, 0.95, 1.0), 5, 90.0, 0.2, 1.5, 0.0)
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.7)
	_rattle = 1.0


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var was := lift
	if _falling:
		lift = maxf(0.0, lift - delta / DROP_T)
		_crush()
		if lift <= 0.0:
			_falling = false
			FX.burst(get_parent(), global_position, Color(0.55, 0.45, 0.35), 12, 120.0, 0.35, 2.0)
			FX.shake(self, 4.0, 0.2)
			SFX.play(get_tree().current_scene, SFX.sfx_thud(), 0.0, 0.7)
	elif not raised:
		_catch()
		# hauled up by the bucket a quarter a piece, or wrenched up once jammed
		var want := 1.0 if blows >= JAM else float(_load.size()) / LOADS
		lift = move_toward(lift, want, delta * (1.2 if blows >= JAM else 0.6))
		if lift >= 1.0:
			_up()
	_tip = maxf(0.0, _tip - delta)
	_rattle = maxf(0.0, _rattle - delta * 4.0)
	_hold(delta)
	if lift != was:
		_fit()
	_pose()


## Anything dropped into the bucket's mouth is kept there.
func _catch() -> void:
	if _load.size() >= LOADS:
		return
	var b := _bucket()
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o in _load or o.has_meta("store_material") or not Hold.free_to_take(o, self):
			continue
		var p: Vector2 = o.global_position - b
		if absf(p.x) < 7.0 and p.y > -12.0 and p.y < 4.0 and o.linear_velocity.y >= -20:
			Hold.claim(o, self)
			o.gravity_scale = 0.0
			_load.append(o)
			SFX.play_small(self, SFX.sfx_ratchet(), -10.0, 0.9)
			if _load.size() >= LOADS:
				break


## The load rides in the bucket, two abreast.
func _hold(delta: float) -> void:
	var b := _bucket()
	for i in _load.size():
		var o = _load[i]
		if is_instance_valid(o):
			var at := b + Vector2((i % 2) * 6 - 3, 5 - (i / 2) * 5)
			Hold.claim(o, self)
			o.linear_velocity = (at - o.global_position) / delta
			if "_timer" in o:
				o._timer = 0.0


## Fully up: it latches, the jam's cleared and the bucket tips out.
func _up() -> void:
	raised = true
	blows = 0
	_tip = 0.7
	for o in _load:
		if is_instance_valid(o):
			Hold.release(o, self)
			o.linear_velocity = Vector2(randf_range(-110, -60), randf_range(-80, -30))
	_load.clear()
	SFX.play_small(self, SFX.sfx_latch(), -8.0, 1.2)


## As it falls: every walker under the spikes is hurt and flung clear.
func _crush() -> void:
	if lift * LIFT > 34.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or _seen.has(e.get_instance_id()):
			continue
		var p: Vector2 = e.global_position - global_position
		if absf(p.x) < W * 0.5 + 6.0 and p.y > -40.0 and p.y < 8.0:
			_seen[e.get_instance_id()] = true
			var away := signf(p.x) if absf(p.x) > 2.0 else (-signf(e.direction) if "direction" in e and e.direction != 0 else 1.0)
			if e.has_method("take_damage"):
				e.take_damage(DAMAGE)
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock(Vector2(away * 280.0, -200.0))
			crushed += 1
			FX.burst(get_parent(), global_position + Vector2(p.x, -12), Color(1, 0.9, 0.5), 8, 120.0, 0.25, 2.0)


## The solid part is the grille where it hangs; none at all when it's up.
func _fit() -> void:
	if _cs == null:
		return
	_cs.set_deferred("disabled", raised and not _falling)
	_cs.position = Vector2(0, -lift * LIFT - H * 0.5)


func _pose() -> void:
	_grille.position = Vector2(roundf(sin(Time.get_ticks_msec() * 0.06) * _rattle * 1.4), -lift * LIFT)
	_bucket_art.position = _bucket_local()
	_bucket_art.rotation = -sin(clampf(_tip / 0.7, 0.0, 1.0) * PI) * 1.2
	for p in _pulleys:
		p.rotation = lift * LIFT / 5.0
	queue_redraw()
	_lights.queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Rect2(-17, -110, 34, 110).has_point(get_global_mouse_position() - global_position):
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# the chain, under the sprites: up from the grille's eye, over both
	# pulleys and down to the bucket's bail; its links creep as it runs
	var iron := Color(0.36, 0.42, 0.45)
	var dark := Color(0.16, 0.15, 0.13)
	var run := lift * LIFT
	var eye := -lift * LIFT - 49.0
	var bail := _bucket_local().y - 5.0
	for seg in [[Vector2(0, eye), Vector2(0, PULLEY_Y - 5)], [Vector2(0, PULLEY_Y - 5), Vector2(BUCKET_X, PULLEY_Y - 5)], [Vector2(BUCKET_X, PULLEY_Y - 5), Vector2(BUCKET_X, bail)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var l := a.distance_to(b)
		var d := (b - a) / maxf(l, 0.01)
		var s := fposmod(run, 4.0)
		while s < l:
			var c := a + d * s
			var along := absf(d.x) > 0.5
			var r := Rect2(c - Vector2(1.5, 1) if along else c - Vector2(1, 1.5), Vector2(3, 2) if along else Vector2(2, 3))
			draw_rect(r.grow(0.5), dark)
			draw_rect(r, iron)
			s += 4.0


func _draw_lights() -> void:
	# the lintel's gauge: a light per piece in the bucket, all lit when up
	var brass := Color(0.85, 0.65, 0.35)
	for i in LOADS:
		var lit := raised or i < _load.size()
		_lights.draw_rect(Rect2(-7 + i * 4, -97.5, 2, 1.5), brass if lit else Color(0.25, 0.22, 0.2))
