extends Node2D
## TrackNet: marbles on track as a 1D simulation, physics only in the air
## (the Factorio-belt trick, for a marble game). One per scene, made on
## demand by the first track piece (get_net); not an autoload.
##
## Every track piece hands it one or more Tracks (scripts/track/track.gd):
## a polyline and the riders on it. A rider is not a body, just (s, v, spin,
## kind, frame) in its track's arrays; the net moves them all each physics
## tick in a fixed order, draws them with one MultiMesh per sprite frame,
## and joins the tracks into a graph: an end within SNAP px of another
## track's start feeds it (several starts there make a junction, whose piece
## picks the way), an end over a sink (can_accept(kind) / accept(kind, v))
## feeds that. An end that feeds nothing is open: the rider flies off it as
## a real ore RigidBody2D, and physics takes over. A physics ore coming down
## onto a track (each track has a catch area) becomes a rider again.
##
## Tick (60 Hz, deterministic: tracks by id, riders by s):
##   1. tickers (sources, escapements) in the order they joined
##   2. every track: gravity or drive, drag, move
##   3. every track: the lead off the end (next track / sink / fly off), the
##      last back off the start (previous track / lip / fly off), then the
##      queue: nobody overlaps the one in front (momentum shared, a clack)
##   4. physics ore landing on tracks caught as riders
## Backpressure falls out of 3: a lead that can't leave (full sink, shut
## gate, no room on the next track) stops at the end and the queue stacks
## up behind it, back up the line to whatever feeds it.

const Track = preload("res://scripts/track/track.gd")
const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_KINDS: Dictionary = preload("res://scenes/ore.gd").KINDS
const ORE_SCENE = preload("res://scenes/ore.tscn")

const DAMP := 0.1          # linear drag (1/s): physics' default linear damp
const ROLL := 6.0          # rolling resistance (px/s^2)
const E := 0.35            # restitution between riders
const E_STOP := 0.3        # off an end stop or the start lip
const SNAP := 10.0         # an end this close to a start feeds it
const SINK_SNAP := 16.0    # an end this close to a sink's inlet feeds it
const CATCH_ABOVE := 5.0   # catch ore whose centre is within r + this of the rail
const JOINT_POW := 0.6     # speed kept over a concave joint: cos(turn) ^ this
const COOL := 12          # ticks before ore that just flew off can be caught again

var tick := 0
var tracks: Array = []     # by id
var released := 0          # tests: riders that flew off as physics ore
var caught := 0            # and physics ore caught as riders
var last_released: RigidBody2D = null
var tick_usec := 0         # how long the last tick took (tests)
var render_usec := 0       # and the last draw update
var snap_every := 0        # tests: record snapshot() every this many ticks
var snapshots: Array = []

var NAMES: Array = []                  # kind id -> ore kind name
var KID := {}                          # kind name -> id
var KR := PackedFloat64Array()         # radius per kind
var KM := PackedFloat64Array()         # mass per kind
var KF := PackedInt32Array()           # sprite frames per kind

var _next_id := 1
var _dirty := true
var _sinks: Array = []                 # [node, inlet (global)]
var _tickers: Array = []
var _clacks: Array = []
var _anchors: Array[Node2D] = []
var _anchor_i := 0
var _mmi := {}                         # bucket (kind * 8 + frame) -> MultiMeshInstance2D
var _buf := PackedFloat32Array()
var _render_dirty := true


## The scene's net, made the first time a track piece asks.
static func get_net(from: Node) -> Node:
	if not from.is_inside_tree():
		return null
	var root := from.get_tree().current_scene
	if root == null:
		return null
	if root.has_meta("track_net"):
		var n = root.get_meta("track_net")
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			return n
	var net: Node = load("res://scripts/track/track_net.gd").new()
	net.name = "TrackNet"
	root.set_meta("track_net", net)
	root.add_child.call_deferred(net)
	return net


func _init() -> void:
	for k in ORE_KINDS:
		var spec: Dictionary = ORE_KINDS[k]
		KID[k] = NAMES.size()
		NAMES.append(k)
		KR.append(spec.radius)
		KM.append(spec.mass)
		KF.append(spec.frames)


func _ready() -> void:
	z_index = 1
	for i in 6:
		var a := Node2D.new()
		add_child(a)
		_anchors.append(a)


func _exit_tree() -> void:
	var root := get_parent()
	if root and root.get_meta("track_net", null) == self:
		root.remove_meta("track_net")


# ── registry ───────────────────────────────────────────────────────────

## A new track for `piece` along `path` (world space, start -> end).
func add_track(piece: Node2D, path: PackedVector2Array, catches := true) -> Track:
	var tr := Track.new()
	tr.id = _next_id
	_next_id += 1
	tr.piece = piece
	tr.catches = catches
	tr.set_path(path)
	tracks.append(tr)
	if catches:
		_build_catch_area(tr)
	_dirty = true
	return tr


## Its riders drop off as physics ore (the piece is going).
func remove_track(tr: Track) -> void:
	while tr.count() > 0 and is_inside_tree():
		_release(tr, tr.count() - 1)
	tr.clear_riders()
	tracks.erase(tr)
	if tr.has_meta("area") and is_instance_valid(tr.get_meta("area")):
		tr.get_meta("area").queue_free()
	tr.piece = null
	tr.router = null
	tr.sink = null
	_dirty = true


func set_track_path(tr: Track, path: PackedVector2Array) -> void:
	while tr.count() > 0 and is_inside_tree():
		_release(tr, tr.count() - 1)
	tr.set_path(path)
	if tr.catches:
		_build_catch_area(tr)
	_dirty = true


func add_sink(node: Object, inlet: Vector2) -> void:
	_sinks.append([node, inlet])
	_dirty = true


func remove_sink(node: Object) -> void:
	_sinks = _sinks.filter(func(e): return e[0] != node)
	_dirty = true


## `node.track_tick(net, tick)` runs first thing every tick.
func add_ticker(node: Object) -> void:
	_tickers.append(node)


func remove_ticker(node: Object) -> void:
	_tickers.erase(node)


## A world point near a track end (for a start) or start (for an end), to
## snap a new piece onto; `pos` if none is within `r`.
func snap_point(pos: Vector2, want_end: bool, r := 12.0, exclude: Object = null) -> Vector2:
	var best := pos
	var bd := r
	for tr in tracks:
		if tr.piece == exclude:
			continue
		var p: Vector2 = tr.pts[tr.pts.size() - 1] if want_end else tr.pts[0]
		if p.distance_to(pos) < bd:
			bd = p.distance_to(pos)
			best = p
	if not want_end:
		for sk in _sinks:
			if sk[0] != exclude and (sk[1] as Vector2).distance_to(pos) < bd:
				bd = (sk[1] as Vector2).distance_to(pos)
				best = sk[1]
	return best


## Puts a rider on `tr` at s if there's room there. Returns whether it did.
func add_rider(tr: Track, s: float, v: float, kind: String, frame := -1) -> bool:
	var k: int = KID.get(kind, 0)
	var r: float = KR[k]
	for i in tr.count():
		if absf(tr.rs[i] - s) < KR[tr.rkind[i]] + r:
			return false
	if frame < 0:
		frame = (tick + tr.count() + tr.id) % KF[k]
	tr.insert(s, v, 0.0, k, frame)
	_render_dirty = true
	return true


## Riders within `radius` of pos: [{track, index, pos, kind, v}]. Pieces use
## this instead of scanning every marble.
func riders_near(pos: Vector2, radius: float) -> Array:
	var out := []
	for tr in tracks:
		if not tr.bounds.grow(radius).has_point(pos):
			continue
		for i in tr.count():
			var k: int = tr.rkind[i]
			var c: Vector2 = tr.center_at(tr.rs[i], KR[k])
			if c.distance_to(pos) <= radius + KR[k]:
				out.append({"track": tr, "index": i, "pos": c, "kind": NAMES[k], "v": tr.rv[i]})
	return out


func rider_count() -> int:
	var n := 0
	for tr in tracks:
		n += tr.count()
	return n


## Every rider's state, in tick order: for determinism checks.
func snapshot() -> String:
	var parts := PackedStringArray()
	for tr in tracks:
		var line := "%d:" % tr.id
		for i in tr.count():
			line += "%s@%.3f/%.3f " % [NAMES[tr.rkind[i]], tr.rs[i], tr.rv[i]]
		parts.append(line)
	return "%d|%s" % [tick, "|".join(parts)]


# ── the graph ──────────────────────────────────────────────────────────

func _rebuild_graph() -> void:
	_dirty = false
	for tr in tracks:
		tr.outs = []
		tr.prev = null
		tr.router = null
		tr.sink = null
	for tr in tracks:
		var e: Vector2 = tr.pts[tr.pts.size() - 1]
		var outs := []
		for o in tracks:
			if o != tr and o.pts[0].distance_to(e) <= SNAP:
				outs.append(o)
		if outs.size() > 1:
			# a junction: the piece whose tracks start there picks the way
			var p: Object = outs[0].piece
			if p != null and p.has_method("pick") and outs.all(func(o): return o.piece == p):
				tr.router = p
			else:
				outs = [outs[0]]
		tr.outs = outs
		for o in outs:
			if o.prev == null:
				o.prev = tr
		if outs.is_empty():
			for sk in _sinks:
				if is_instance_valid(sk[0]) and (sk[1] as Vector2).distance_to(e) <= SINK_SNAP:
					tr.sink = sk[0]
					break
	for tr in tracks:
		# a stop at the start unless it runs uphill from there (then it's open)
		tr.lip = tr.prev == null and tr.tan[0].y >= -0.02


func _build_catch_area(tr: Track) -> void:
	if tr.has_meta("area") and is_instance_valid(tr.get_meta("area")):
		tr.get_meta("area").queue_free()
	if tr.piece == null:
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	for k in tr.tan.size():
		var a: Vector2 = tr.piece.to_local(tr.pts[k])
		var b: Vector2 = tr.piece.to_local(tr.pts[k + 1])
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(a.distance_to(b), 20.0)
		cs.shape = rect
		cs.position = (a + b) * 0.5 + tr.nrm[k] * 9.0
		cs.rotation = (b - a).angle()
		area.add_child(cs)
	area.body_entered.connect(func(b): tr.cands[b.get_instance_id()] = b)
	area.body_exited.connect(func(b): tr.cands.erase(b.get_instance_id()))
	tr.piece.add_child(area)
	tr.set_meta("area", area)


# ── the tick ───────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var t0 := Time.get_ticks_usec()
	if _dirty:
		_rebuild_graph()
	tick += 1
	for p in _tickers.duplicate():
		if is_instance_valid(p):
			p.track_tick(self, tick)
		else:
			_tickers.erase(p)
	for tr in tracks:
		tr.integrate(delta, KR, DAMP, ROLL)
	_clacks.clear()
	for tr in tracks:
		_resolve(tr)
	_catch_ore()
	_render_dirty = true
	tick_usec = Time.get_ticks_usec() - t0
	if snap_every > 0 and tick % snap_every == 0:
		snapshots.append(snapshot())


func _resolve(tr: Track) -> void:
	var guard := 0
	while tr.count() > 0 and tr.rs[tr.count() - 1] >= tr.length and guard < 6:
		guard += 1
		if not _exit_end(tr):
			break
	guard = 0
	if tr.prev != null or not tr.lip:
		while tr.count() > 0 and tr.rs[0] < 0.0 and guard < 6:
			guard += 1
			if not _exit_start(tr):
				break
	var n := tr.count()
	if n == 0:
		return
	var ub := INF
	if tr.gate == 0 or tr.sink != null or tr.outs.size() > 1:
		ub = tr.length
	elif tr.outs.size() == 1:
		# the lead against the last in the queue on the next track
		var nx: Track = tr.outs[0]
		if nx.count() > 0:
			var li := n - 1
			var ka: int = tr.rkind[li]
			var kb: int = nx.rkind[0]
			var lim: float = tr.length + nx.rs[0] - KR[ka] - KR[kb]
			if tr.rs[li] > lim:
				var va: float = tr.rv[li]
				var vb: float = nx.rv[0]
				if va > vb:
					var p := KM[ka] * va + KM[kb] * vb
					va = (p - KM[kb] * E * (tr.rv[li] - vb)) / (KM[ka] + KM[kb])
					nx.set_speed(0, (p + KM[ka] * E * (tr.rv[li] - vb)) / (KM[ka] + KM[kb]))
					if tr.rv[li] - vb > 60.0:
						_clack(tr, lim, tr.rv[li] - vb)
				tr.set_sv(li, lim, va)
	var lb := -INF
	if tr.prev == null and tr.lip:
		lb = KR[tr.rkind[0]]
	var before := _clacks.size()
	tr.contacts(ub, lb, KR, KM, E, _clacks)
	var i := before
	while i < _clacks.size():
		_clack(tr, _clacks[i], _clacks[i + 1])
		i += 2


## The lead is past the end. Returns whether it left.
func _exit_end(tr: Track) -> bool:
	var li := tr.count() - 1
	var k: int = tr.rkind[li]
	if tr.gate == 0:
		_hold_end(tr)
		return false
	if tr.sink != null:
		if is_instance_valid(tr.sink) and tr.sink.can_accept(NAMES[k]):
			var d := tr.take(li)
			tr.sink.accept(NAMES[k], d[1])
			_passed(tr, k)
			return true
		_hold_end(tr)
		return false
	if not tr.outs.is_empty():
		var r: float = KR[k]
		var free := []
		for o in tr.outs:
			free.append(o.room_at_start(r, KR) >= 0.0)
		var pick := -1
		if tr.router != null and is_instance_valid(tr.router):
			pick = tr.router.pick(NAMES[k], free)
		elif free[0]:
			pick = 0
		if pick < 0:
			_hold_end(tr)
			return false
		var dst: Track = tr.outs[pick]
		var over: float = tr.rs[li] - tr.length
		var d := tr.take(li)
		var last := tr.tan.size() - 1
		var v: float = d[1] * _joint(tr.tan[last], tr.nrm[last], dst.tan[0])
		dst.insert(minf(over, dst.room_at_start(r, KR)), v, d[2], d[3], d[4])
		if tr.router != null and tr.router.has_method("passed"):
			tr.router.passed(pick, NAMES[k])
		_passed(tr, k)
		return true
	_passed(tr, k)
	_release(tr, li)
	return true


## The first one rolled back past the start. Returns whether it left.
func _exit_start(tr: Track) -> bool:
	var k: int = tr.rkind[0]
	if tr.prev != null:
		var pv: Track = tr.prev
		var least := pv.room_at_end(KR[k], KR)
		if least <= pv.length:
			var d := tr.take(0)
			pv.insert(maxf(pv.length + d[0], least), d[1], d[2], d[3], d[4])
			return true
		var hit := tr.hold_first(0.0, E_STOP)
		if hit > 60.0:
			_clack(tr, 0.0, hit)
		return false
	_release(tr, 0)
	return true


func _hold_end(tr: Track) -> void:
	var v := tr.hold_lead(tr.length, E_STOP)
	if v > 60.0:
		_clack(tr, tr.length, v)


func _passed(tr: Track, k: int) -> void:
	if tr.gate > 0:
		tr.gate -= 1
	if tr.notify and is_instance_valid(tr.piece):
		tr.piece.rider_passed(tr, NAMES[k])


## Speed kept going from one track onto the next: where the path turns up
## into the ball it loses the part of its speed into the new surface (a
## physics marble thumps into the joint the same way).
func _joint(t_old: Vector2, n_old: Vector2, t_new: Vector2) -> float:
	var d := t_old.dot(t_new)
	if t_new.dot(n_old) > 0.02:
		# a round ball meets the new slope over its radius, not at a point:
		# it keeps a bit more than cos(turn) (fitted to the physics chute)
		return clampf(pow(maxf(d, 0.0), JOINT_POW), 0.15, 1.0)
	return 1.0 if d > 0.0 else 0.15


# ── handoffs ───────────────────────────────────────────────────────────

## Rider i leaves the track as a physics ore, flying on along the path.
func _release(tr: Track, i: int) -> void:
	var s := clampf(tr.rs[i], 0.0, tr.length)
	var sg := tr.seg_at(s)
	var d := tr.take(i)
	var k: int = d[3]
	var vel: Vector2 = tr.tan[sg] * float(d[1])
	var pos: Vector2 = tr.point_at(s) + tr.nrm[sg] * KR[k] + vel.normalized() * 1.0
	released += 1
	if not is_inside_tree():
		return
	var o: RigidBody2D = ORE_SCENE.instantiate()
	o.kind = NAMES[k]
	o.global_position = pos
	o.rotation = d[2]
	o.linear_velocity = vel
	o.angular_velocity = float(d[1]) * tr.spin[sg] / KR[k]
	o.set_meta("track_left", tick)
	get_parent().add_child(o)
	for c in o.get_children():
		if c is Sprite2D and c.texture is AtlasTexture:
			var sz: float = ORE_KINDS[NAMES[k]].size
			c.texture.region.position.x = d[4] * sz   # the same chunk of rock it was
	last_released = o


func _catchable(o: Object) -> bool:
	if not (o is RigidBody2D) or o.freeze or not o.is_in_group("ore"):
		return false
	var kind = o.get("kind")
	if not (kind is String) or not KID.has(kind) or ORE_KINDS[kind].has("fuse"):
		return false
	if o.has_meta("store_material") or o.has_meta("caught_by") or Hold.holder(o) != null:
		return false
	return tick - int(o.get_meta("track_left", -1000)) > COOL


## Physics ore settling onto a track (close above it, not leaving) becomes a
## rider there, with its speed along the track.
func _catch_ore() -> void:
	for tr in tracks:
		if tr.cands.is_empty():
			continue
		for id in tr.cands.keys():
			var o = tr.cands[id]
			if not is_instance_valid(o) or o.is_queued_for_deletion():
				tr.cands.erase(id)
				continue
			if not _catchable(o):
				continue
			var k: int = KID[o.kind]
			var r: float = KR[k]
			var p: Vector2 = o.global_position
			var lv: Vector2 = o.linear_velocity
			for sg in tr.tan.size():
				var a: Vector2 = tr.pts[sg]
				var along: float = (p - a).dot(tr.tan[sg])
				var s: float = tr.cum[sg] + along
				if along < 0.0 or s <= 1.0 or s >= tr.length - 1.0 or along > tr.cum[sg + 1] - tr.cum[sg]:
					continue
				var above: float = (p - a).dot(tr.nrm[sg])
				if above < -3.0 or above > r + CATCH_ABOVE or lv.dot(tr.nrm[sg]) > 40.0:
					continue
				var frame := 0
				for c in o.get_children():
					if c is Sprite2D and c.texture is AtlasTexture:
						frame = clampi(int(c.texture.region.position.x / float(ORE_KINDS[o.kind].size)), 0, KF[k] - 1)
				tr.insert(s, lv.dot(tr.tan[sg]), o.rotation, k, frame)
				tr.cands.erase(id)
				o.remove_from_group("ore")
				o.queue_free()
				caught += 1
				break


# ── sound ──────────────────────────────────────────────────────────────

## Riders knocking together (or into a stop): the ore-on-ore knock.
func _clack(tr: Track, s: float, speed: float) -> void:
	if _anchors.is_empty():
		return
	var a := _anchors[_anchor_i]
	_anchor_i = (_anchor_i + 1) % _anchors.size()
	a.global_position = tr.point_at(s)
	var k := clampf(inverse_lerp(60.0, 600.0, speed), 0.0, 1.0)
	SFX.play_small(a, SFX.sfx_ore_knock("ore"), lerpf(-28.0, -12.0, k), lerpf(1.15, 0.95, k))


# ── drawing: one MultiMesh per kind and sprite frame ───────────────────

func _process(_delta: float) -> void:
	if _render_dirty:
		_render_dirty = false
		var t0 := Time.get_ticks_usec()
		_render()
		render_usec = Time.get_ticks_usec() - t0


func _render() -> void:
	var nb := NAMES.size() * 8
	var cnt := PackedInt32Array()
	cnt.resize(nb)
	var total := 0
	for tr in tracks:
		var rk: PackedInt32Array = tr.rkind
		var rf: PackedInt32Array = tr.rframe
		for i in rk.size():
			cnt[rk[i] * 8 + rf[i]] += 1
		total += rk.size()
	var start := PackedInt32Array()
	start.resize(nb)
	var acc := 0
	for b in nb:
		start[b] = acc
		acc += cnt[b]
	var at := start.duplicate()
	if _buf.size() != total * 8:
		_buf.resize(total * 8)
	for tr in tracks:
		var rs: PackedFloat64Array = tr.rs
		if rs.is_empty():
			continue
		var rrot: PackedFloat64Array = tr.rrot
		var rk: PackedInt32Array = tr.rkind
		var rf: PackedInt32Array = tr.rframe
		var cum: PackedFloat64Array = tr.cum
		var pts: PackedVector2Array = tr.pts
		var tn: PackedVector2Array = tr.tan
		var nr: PackedVector2Array = tr.nrm
		var last: int = tn.size() - 1
		var sg := 0
		for i in rs.size():
			var s: float = rs[i]
			while sg < last and s > cum[sg + 1]:
				sg += 1
			var kind: int = rk[i]
			var p: Vector2 = pts[sg] + tn[sg] * clampf(s - cum[sg], 0.0, cum[sg + 1] - cum[sg]) + nr[sg] * KR[kind]
			var b: int = kind * 8 + rf[i]
			var o: int = at[b] * 8
			at[b] += 1
			var c := cos(rrot[i])
			var sn := sin(rrot[i])
			_buf[o] = c
			_buf[o + 1] = -sn
			_buf[o + 2] = 0.0
			_buf[o + 3] = p.x
			_buf[o + 4] = sn
			_buf[o + 5] = c
			_buf[o + 6] = 0.0
			_buf[o + 7] = p.y
	for b in nb:
		if cnt[b] == 0 and not _mmi.has(b):
			continue
		var mm: MultiMesh = _bucket(b).multimesh
		if mm.instance_count != cnt[b]:
			mm.instance_count = cnt[b]
		if cnt[b] > 0:
			mm.buffer = _buf.slice(start[b] * 8, (start[b] + cnt[b]) * 8)


func _bucket(b: int) -> MultiMeshInstance2D:
	if _mmi.has(b):
		return _mmi[b]
	var spec: Dictionary = ORE_KINDS[NAMES[b / 8]]
	var tex: Texture2D = load(spec.tex)
	var w: float = spec.size
	var h: float = spec.get("h", spec.size)
	var fx: float = (b % 8) * w
	var ts := tex.get_size()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-w, -h) * 0.5, Vector2(w, -h) * 0.5, Vector2(w, h) * 0.5, Vector2(-w, h) * 0.5])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(fx, 0) / ts, Vector2(fx + w, 0) / ts, Vector2(fx + w, h) / ts, Vector2(fx, h) / ts])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = mesh
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.texture = tex
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mmi)
	_mmi[b] = mmi
	return mmi
