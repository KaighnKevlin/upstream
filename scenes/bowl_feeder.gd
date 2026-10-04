extends Node2D
## Vibratory bowl feeder: a shallow iron bowl on a sprung, buzzing base.
## Dump pieces in its mouth any old how: they jumble at the bottom, and the
## buzz walks them one at a time up the spiral ledge round the inside wall
## (three turns), a set gap apart, and out over the rim onto the exit lip
## toward `side` (click the bowl to flip it): a heap in, a single file out,
## evenly spaced. Grit is too fine to keep its footing: it rattles off the
## ledge, back to the bottom and out the reject hole on the far side.
## Climbs slowly unpowered; a gravity wheel or steam engine in reach runs it
## at full rate. Ore-only layer: walkers pass through.

const Hold = preload("res://scripts/hold.gd")
const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
# the ledge, drawn for side = +1 (x flips with side): a zig-zag of six runs
# up the back wall, out over the rim (tools/art/gen_bowl_feeder.py LEDGE)
const LEDGE := [Vector2(16, -20), Vector2(-16, -26.2), Vector2(16, -32.3), Vector2(-16, -38.5), Vector2(16, -44.7), Vector2(-16, -50.8), Vector2(16, -57), Vector2(23, -58)]
const V := 64.0                  # px/s up the ledge at full power
const GAP := 16.0                # px apart along the ledge
const FINES := 3.0               # a piece this small (radius) won't hold the ledge
const HOLE := Vector2(-19, -21)  # the reject hole (side = +1)
const MOUTH := Rect2(-20, -68, 40, 52)

@export var side := 1.0          # the exit lip's way; the reject hole's the other

var fed := 0                     # tests
var rejected := 0
var exit_times: Array = []       # tests: when each one left the lip, s
var _pile: Array = []            # jumbled at the bottom, waiting
var _ledge: Array = []           # [ore, s along the ledge, s it falls at (grit) or -1]
var _drop: Array = []            # [ore, fall speed, 0 falling / 1 to the hole]
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _buzz := 0.0
var _art: Node2D                 # art: both sprites, flipped with side and shaken
var _lip: SegmentShape2D


func _ready() -> void:
	z_index = 0
	# the art first, so ghosts and build-bar icons get it: the bowl's inside
	# behind the pieces (z 0, ore is 1), its near edge and base over them
	_art = Node2D.new()
	add_child(_art)
	_spr(preload("res://assets/sprites/bowl_feeder_back.png"), Vector2(-25, -64), 0)
	_spr(preload("res://assets/sprites/bowl_feeder_front.png"), Vector2(-40, -66), 2)
	_art.scale.x = _s()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	# the exit lip: a short ore-only slope off the rim
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	_lip = SegmentShape2D.new()
	cs.shape = _lip
	body.add_child(cs)
	add_child(body)
	_fit_lip()


func _spr(tex: Texture2D, off: Vector2, z: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.z_index = z
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.add_child(sp)
	return sp


func _s() -> float:
	return -1.0 if side < 0 else 1.0


func _fit_lip() -> void:
	if _lip:
		_lip.a = Vector2(20 * _s(), -60)
		_lip.b = Vector2(37 * _s(), -55)


## A point on the ledge `s` px up it (local, flipped to side).
func _at(s: float) -> Vector2:
	for i in LEDGE.size() - 1:
		var a: Vector2 = LEDGE[i]
		var b: Vector2 = LEDGE[i + 1]
		var l := a.distance_to(b)
		if s <= l:
			var p := a.lerp(b, s / l)
			return Vector2(p.x * _s(), p.y)
		s -= l
	var e: Vector2 = LEDGE[-1]
	return Vector2(e.x * _s(), e.y)


func _length() -> float:
	var l := 0.0
	for i in LEDGE.size() - 1:
		l += (LEDGE[i] as Vector2).distance_to(LEDGE[i + 1])
	return l


func _r(o) -> float:
	if not ("kind" in o):
		return 6.5
	var r: float = o.KINDS.get(o.kind, o.KINDS.copper).radius
	return r


func _hold(o, at: Vector2, delta: float) -> void:
	Hold.claim(o, self)
	o.linear_velocity = ((at - o.global_position) / delta).limit_length(260.0)
	o.angular_velocity = 0.0
	if "_timer" in o:
		o._timer = 0.0


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var now := Time.get_ticks_msec() / 1000.0
	# anything falling into the mouth joins the jumble
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.has_meta("store_material") or o.get_meta("bowl_until", 0.0) > now or not Hold.free_to_take(o, self):
			continue
		if o in _pile or _held(o):
			continue
		if MOUTH.has_point(o.global_position - global_position) and o.linear_velocity.y >= -20:
			Hold.claim(o, self)
			o.gravity_scale = 0.0
			_pile.append(o)
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.1)
	_pile = _pile.filter(func(o): return is_instance_valid(o))
	var running := not (_pile.is_empty() and _ledge.is_empty() and _drop.is_empty())
	var j := Vector2.ZERO
	if running:
		# the buzz: the bowl shakes a pixel, the jumble with it
		_buzz += delta
		if _buzz > 0.04:
			_buzz = 0.0
			_art.position = Vector2(randi_range(-1, 1), randi_range(-1, 0))
		j = _art.position
	elif _art.position != Vector2.ZERO:
		_art.position = Vector2.ZERO
	# the jumble at the bottom, four abreast
	for i in _pile.size():
		var o = _pile[i]
		var at := Vector2(-10.5 + (i % 4) * 7.0 + (3.5 if (i / 4) % 2 else 0.0), -16.0 - _r(o) - (i / 4) * 6.0)
		_hold(o, global_position + at + j, delta)
	# the ledge: all climb together, so the gaps hold; the next one steps on
	# once the last is a gap up
	var v := V * _rate
	var top := _length()
	var keep: Array = []
	for e in _ledge:
		var o = e[0]
		if not is_instance_valid(o):
			continue
		e[1] += v * delta
		if e[2] >= 0.0 and e[1] >= e[2]:
			_drop.append([o, 0.0, 0])
			continue
		if e[1] >= top:
			_release(o, now)
			continue
		_hold(o, global_position + _at(e[1]) + Vector2(0, -_r(o) - 1.0) + j, delta)
		keep.append(e)
	_ledge = keep
	if not _pile.is_empty() and (_ledge.is_empty() or _ledge[-1][1] >= GAP):
		var o = _pile.pop_front()
		# fines lose their footing a little way up
		var falls := randf_range(18.0, 60.0) if _r(o) < FINES else -1.0
		_ledge.append([o, 0.0, falls])
	# grit falling back to the bottom, then rattled out the reject hole
	var still: Array = []
	for d in _drop:
		var o = d[0]
		if not is_instance_valid(o):
			continue
		var p: Vector2 = o.global_position - global_position
		var hole := Vector2(HOLE.x * _s(), HOLE.y)
		if d[2] == 0:
			d[1] += 400.0 * delta
			var y := minf(p.y + d[1] * delta, hole.y)
			if y >= hole.y:
				d[2] = 1
			_hold(o, global_position + Vector2(p.x, y), delta)
		else:
			var at: Vector2 = p.move_toward(hole, 70.0 * delta)
			if at.distance_to(hole) < 1.0:
				Hold.release(o, self)
				o.linear_velocity = Vector2(-_s() * 90.0, -10.0)
				o.set_meta("bowl_until", now + 1.5)
				rejected += 1
				SFX.play_small(self, SFX.sfx_clink(), -18.0, 2.2)
				continue
			_hold(o, global_position + at, delta)
		still.append(d)
	_drop = still


func _held(o) -> bool:
	for e in _ledge:
		if e[0] == o:
			return true
	for d in _drop:
		if d[0] == o:
			return true
	return false


## Off the top of the ledge onto the lip, rolling out.
func _release(o, now: float) -> void:
	Hold.release(o, self)
	o.linear_velocity = Vector2(_s() * 50.0, 0.0)
	o.set_meta("bowl_until", now + 1.5)
	fed += 1
	exit_times.append(now)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 1.4)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if MOUTH.has_point(Pointer.world(self) - global_position):
		side = -_s()
		_art.scale.x = _s()
		_fit_lip()
		get_viewport().set_input_as_handled()
