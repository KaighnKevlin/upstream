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
## Where a piece watches the ore going by (anything with an Area2D that
## sees ore over a track, or any piece within WATCH_R of it, or the region a
## piece names with ore_watch()), the track is a zone: riders reaching one
## drop to physics ore there, rolling on the rail's own collision, so the
## piece sees and acts on real bodies exactly as before, and are caught
## again past it. Loose bodies lying on a track (an ingot, a bomb, ore just
## let go) make a zone round themselves for the tick, so riders never pass
## through them. A caught ore's body isn't freed but parked (taken out of
## the tree, its tag on the rider) and put back when the rider leaves the
## track: the same object, metas and all, and its despawn clock runs on
## while it rides, so an ore is the same ore after a stretch on track.
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
const NEVER := 0x7fffffff  # a rider's despawn tick when it doesn't age
const COOL := 12          # ticks before ore that just flew off can be caught again
const WATCH_R := 40.0      # a piece with no areas or ore_watch() watches this far round its node
const ZONE_PAD := 8.0      # zones start this far (along the track) before what's watched
const ZONE_BAND := 16.0    # how far above the rail a watched region has to reach to count
const DZ := 22.0           # riders drop to physics this close (along it) to a loose body on the track
const LIFETIME := 15.0     # loose ore's default lifetime (scenes/ore.gd)
const NOISE := 0.012       # noise per px/s of a knock (scenes/noise_meter.gd IMPACT)
## Metas that mean a piece has hold of the body (or it's burning): never caught.
const HELD_METAS := ["store_material", "caught_by", "lit", "spin_damped", "in_screw", "in_lift", "in_beam",
	"claimed_by", "netted_by", "store_z", "tube_z", "held_by", "hunted_by"]

var tick := 0
var tracks: Array = []     # by id
var released := 0          # tests: riders that flew off as physics ore
var caught := 0            # and physics ore caught as riders
var last_released: RigidBody2D = null
var tick_usec := 0         # how long the last tick took (tests)
var render_usec := 0       # and the last draw update
var snap_every := 0        # tests: record snapshot() every this many ticks
var snapshots: Array = []
var ejected := 0           # riders taken off as physics by a piece or a zone (tests)
var zone_count := 0        # static zones, all tracks (tests)

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
var _tags := {}                        # tag -> the parked body of the ore a rider is
var _next_tag := 1
var _zones_dirty := true
var _watch_sig := []                   # [node, signature] of what the zones were built from
var _root: Node = null


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
	_root = get_parent()
	get_tree().node_added.connect(_on_node_changed)
	get_tree().node_removed.connect(_on_node_changed)
	for i in 6:
		var a := Node2D.new()
		add_child(a)
		_anchors.append(a)


func _exit_tree() -> void:
	for t in _tags.keys():
		_drop_tag(t)
	var root := get_parent()
	if root and root.has_meta("track_net") and root.get_meta("track_net") == self:
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
	_zones_dirty = true
	return tr


## Its riders drop off as physics ore (the piece is going).
func remove_track(tr: Track) -> void:
	while tr.count() > 0 and is_inside_tree():
		_release(tr, tr.count() - 1, true)
	tr.clear_riders()
	tracks.erase(tr)
	if tr.has_meta("area") and is_instance_valid(tr.get_meta("area")):
		tr.get_meta("area").queue_free()
	tr.piece = null
	tr.router = null
	tr.sink = null
	_dirty = true
	_zones_dirty = true
	_retire_if_idle()


func set_track_path(tr: Track, path: PackedVector2Array) -> void:
	while tr.count() > 0 and is_inside_tree():
		_release(tr, tr.count() - 1)
	tr.set_path(path)
	if tr.catches:
		_build_catch_area(tr)
	_dirty = true
	_zones_dirty = true


func add_sink(node: Object, inlet: Vector2) -> void:
	_sinks.append([node, inlet])
	_dirty = true


func remove_sink(node: Object) -> void:
	_sinks = _sinks.filter(func(e): return e[0] != node)
	_dirty = true
	_retire_if_idle()


## `node.track_tick(net, tick)` runs first thing every tick.
func add_ticker(node: Object) -> void:
	_tickers.append(node)


func remove_ticker(node: Object) -> void:
	_tickers.erase(node)
	_retire_if_idle()


## The last piece gone: the net goes too (the next piece makes a fresh one,
## its clock from 0: a layout built again runs the same).
func _retire_if_idle() -> void:
	if tracks.is_empty() and _sinks.is_empty() and _tickers.is_empty() and not is_queued_for_deletion():
		var root := get_parent()
		if root and root.has_meta("track_net") and root.get_meta("track_net") == self:
			root.remove_meta("track_net")
		queue_free()


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


## Takes rider i off `tr` as a physics ore, flying on along the track as it
## was (a kicker punching it out, a magnet lifting it, a blast): the body,
## with the metas and despawn clock the rider carried.
func eject(tr: Track, i: int) -> RigidBody2D:
	if i < 0 or i >= tr.count():
		return null
	ejected += 1
	_release(tr, i)
	return last_released


## Every rider within `radius` of pos taken off as physics ore (optionally
## only `kinds`): the bodies, for a piece that then acts on them as ore.
func eject_near(pos: Vector2, radius: float, kinds: Array = []) -> Array:
	var out := []
	for tr in tracks:
		if not tr.bounds.grow(radius).has_point(pos):
			continue
		var i: int = tr.count() - 1
		while i >= 0:
			var k: int = tr.rkind[i]
			if (kinds.is_empty() or NAMES[k] in kinds) and tr.center_at(tr.rs[i], KR[k]).distance_to(pos) <= radius + KR[k]:
				var o := eject(tr, i)
				if o != null:
					out.append(o)
			i -= 1
	return out


## The scene's net if it has one (no net is made): for pieces that only
## need to reach riders now and then (a blast), from a static context.
static func find_net(from: Node) -> Node:
	if from == null or not from.is_inside_tree() or from.get_tree().current_scene == null:
		return null
	var cs := from.get_tree().current_scene
	var n = cs.get_meta("track_net") if cs.has_meta("track_net") else null
	return n if is_instance_valid(n) and not n.is_queued_for_deletion() else null


## eject_near on the scene's net, if there is one.
static func eject_at(from: Node, pos: Vector2, radius: float, kinds: Array = []) -> Array:
	var n := find_net(from)
	return n.eject_near(pos, radius, kinds) if n != null else []


## The ore body rider i is (parked, out of the tree), made for it if it
## came onto the track without one (from a source). Its position and
## velocity are brought up to date: a piece can aim at it.
func rider_body(tr: Track, i: int) -> RigidBody2D:
	var t: int = tr.rtag[i]
	var o: RigidBody2D = null
	if t != 0 and _tags.has(t) and is_instance_valid(_tags[t]):
		o = _tags[t]
	else:
		o = ORE_SCENE.instantiate()
		o.kind = NAMES[tr.rkind[i]]
		t = _park(o)
		tr.rtag[i] = t
	var sg := tr.seg_at(tr.rs[i])
	o.global_position = tr.center_at(tr.rs[i], KR[tr.rkind[i]])
	o.linear_velocity = tr.tan[sg] * tr.rv[i]
	return o


## Where a parked body rides: [track, index], or [] (it isn't a rider).
func find_rider(o: Object) -> Array:
	if not is_instance_valid(o) or not o.has_meta("track_tag"):
		return []
	var t: int = o.get_meta("track_tag")
	for tr in tracks:
		var i: int = tr.rtag.find(t)
		if i >= 0:
			return [tr, i]
	return []


func _park(o: RigidBody2D) -> int:
	var t := _next_tag
	_next_tag += 1
	_tags[t] = o
	o.set_meta("track_tag", t)
	return t


## A meta on the ore rider i is.
func rider_get_meta(tr: Track, i: int, name: String, default = null):
	var t: int = tr.rtag[i]
	if t == 0 or not _tags.has(t) or not is_instance_valid(_tags[t]) or not _tags[t].has_meta(name):
		return default
	return _tags[t].get_meta(name)


func rider_set_meta(tr: Track, i: int, name: String, value) -> void:
	rider_body(tr, i).set_meta(name, value)


func _drop_tag(t: int) -> void:
	if t != 0 and _tags.has(t):
		var o = _tags[t]
		_tags.erase(t)
		if is_instance_valid(o) and not o.is_inside_tree():
			o.queue_free()


## Drops every rider without a trace (a load, a reset): nothing flies off.
func clear_all_riders() -> void:
	for tr in tracks:
		tr.clear_riders()
	for t in _tags.keys():
		_drop_tag(t)
	_render_dirty = true


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
		if tr.lip_mode >= 0:
			tr.lip = tr.prev == null and tr.lip_mode == 1
		else:
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
	area.set_meta("track_catch", true)
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
	if _zones_dirty:
		_rebuild_zones()
	elif tick % 30 == 0:
		_check_watchers()
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
	if tick % 30 == 0:
		_age()
	if tick % 4 == 0:
		_sync_parked()
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
	if tr.solid and (not tr.zones.is_empty() or not tr.dzones.is_empty()):
		# watched stretches: physics there
		var zi := tr.count() - 1
		while zi >= 0:
			if tr.zone_at(tr.rs[zi]) >= 0:
				_release(tr, zi)
			zi -= 1
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
			_drop_tag(d[5])
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
		dst.insert(minf(over, dst.room_at_start(r, KR)), v, d[2], d[3], d[4], d[5], d[6])
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
			pv.insert(maxf(pv.length + d[0], least), d[1], d[2], d[3], d[4], d[5], d[6])
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
func _release(tr: Track, i: int, deferred := false) -> void:
	var s := clampf(tr.rs[i], 0.0, tr.length)
	var sg := tr.seg_at(s)
	var d := tr.take(i)
	var k: int = d[3]
	var vel: Vector2 = tr.tan[sg] * float(d[1])
	var pos: Vector2 = tr.point_at(s) + tr.nrm[sg] * KR[k] + vel.normalized() * 1.0
	released += 1
	if not is_inside_tree():
		_drop_tag(d[5])
		return
	var tag: int = d[5]
	var o: RigidBody2D = null
	if tag != 0 and _tags.has(tag):
		o = _tags[tag]
		_tags.erase(tag)
		if is_instance_valid(o):
			o.remove_meta("track_tag")
		if not is_instance_valid(o) or o.is_queued_for_deletion() or o.is_inside_tree():
			o = null
	var fresh := o == null
	if fresh:
		o = ORE_SCENE.instantiate()
		o.kind = NAMES[k]
	o.global_position = pos
	o.rotation = d[2]
	o.linear_velocity = vel
	o.angular_velocity = float(d[1]) * tr.spin[sg] / KR[k]
	o.sleeping = false
	o.set_meta("track_left", tick)
	if int(d[6]) != NEVER:
		o._timer = maxf(0.0, o.lifetime - maxf(0.0, (int(d[6]) - tick) / 60.0))
	if "_prev_speed" in o:
		o._prev_speed = absf(float(d[1]))
	if deferred:
		get_parent().add_child.call_deferred(o)   # a piece going: the scene may be mid-change
	else:
		get_parent().add_child(o)
	if fresh:
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
	var spec: Dictionary = ORE_KINDS[kind]
	if spec.has("blast") or spec.has("fragile") or not ("_timer" in o):
		return false   # a shell or a flask stays a body: they go off / break on a knock
	for m in HELD_METAS:
		if o.has_meta(m):
			return false
	if Hold.holder(o) != null:
		return false
	return tick - int(o.get_meta("track_left", -1000)) > COOL


## Physics ore settling onto a track (close above it, not leaving) becomes a
## rider there, with its speed along the track, unless it's in a watched
## zone or beside a body that stays loose. Every body on it that isn't
## caught makes a zone round itself (dzones) for the next tick.
func _catch_ore() -> void:
	for tr in tracks:
		if tr.cands.is_empty():
			if not tr.dzones.is_empty():
				tr.dzones = PackedFloat64Array()
			continue
		var dz := PackedFloat64Array()
		var catch := []                     # [id, body, s, seg]
		for id in tr.cands.keys():
			var o = tr.cands[id]
			if not is_instance_valid(o) or o.is_queued_for_deletion():
				tr.cands.erase(id)
				continue
			if not (o is Node2D):
				continue
			var p: Vector2 = o.global_position
			var hit := _on_band(tr, p)
			if hit.is_empty():
				continue
			var s: float = hit[0]
			var sg: int = hit[1]
			if tr.solid and o is RigidBody2D and not o.freeze and o.is_in_group("ore"):
				# let go just under the running surface, not coming up from below
				# (a wheel's bucket tipping onto the rail): it sits on the rail. A
				# line of loose ore used to shove such pieces up; riders don't.
				var r0: float = ORE_KINDS[o.kind].radius if ORE_KINDS.has(o.kind) else 6.5
				var above0: float = (p - tr.pts[sg]).dot(tr.nrm[sg])
				var vn: float = o.linear_velocity.dot(tr.nrm[sg])
				if above0 < r0 - 2.0 and above0 > -8.0 and vn <= 40.0:
					o.global_position = p + tr.nrm[sg] * (r0 - above0)
					if vn < 0.0:
						o.linear_velocity -= tr.nrm[sg] * vn
					p = o.global_position
			var ok := _catchable(o)
			if ok:
				var r: float = KR[KID[o.kind]]
				var above: float = (p - tr.pts[sg]).dot(tr.nrm[sg])
				var lv: Vector2 = o.linear_velocity
				ok = s > 1.0 and s < tr.length - 1.0 and above >= -3.0 and above <= r + CATCH_ABOVE \
						and lv.dot(tr.nrm[sg]) <= 40.0 and (not tr.solid or _in(tr.zones, s) < 0)
			if ok:
				catch.append([id, o, s, sg])
			elif tr.solid:
				dz.append(s - DZ)
				dz.append(s + DZ)
		tr.dzones = dz
		for c in catch:
			var o: RigidBody2D = c[1]
			var s: float = c[2]
			if _in(dz, s) >= 0:
				continue
			var sg: int = c[3]
			var k: int = KID[o.kind]
			var lv: Vector2 = o.linear_velocity
			var frame := 0
			for ch in o.get_children():
				if ch is Sprite2D and ch.texture is AtlasTexture:
					frame = clampi(int(ch.texture.region.position.x / float(ORE_KINDS[o.kind].size)), 0, KF[k] - 1)
			var tag := _park(o)
			var left: float = (o.lifetime - o._timer) * 60.0
			var die: int = NEVER if left > 1.0e9 else tick + int(left)
			# a skidding landing spins up to rolling: angular momentum about the
			# contact point is kept, so a disc keeps (2v + r w) / 3 of its speed
			# (all of it when it was already rolling)
			var along: float = (2.0 * lv.dot(tr.tan[sg]) + KR[k] * o.angular_velocity * tr.spin[sg]) / 3.0
			tr.insert(s, along, o.rotation, k, frame, tag, die)
			tr.cands.erase(c[0])
			# the landing: the knock (and the noise) it would have made on the rail
			var into: float = -lv.dot(tr.nrm[sg])
			if into > 90.0:
				_clack(tr, s, into)
			o.get_parent().remove_child(o)   # parked, not freed: back in the tree when it leaves
			caught += 1


## Where a point lies along the track's riding band: [s, segment], or []
## (off the ends, or not over it).
func _on_band(tr: Track, p: Vector2) -> Array:
	for sg in tr.tan.size():
		var a: Vector2 = tr.pts[sg]
		var along: float = (p - a).dot(tr.tan[sg])
		if along < 0.0 or along > tr.cum[sg + 1] - tr.cum[sg]:
			continue
		var above: float = (p - a).dot(tr.nrm[sg])
		if above < -8.0 or above > 26.0:
			continue
		return [tr.cum[sg] + along, sg]
	return []


static func _in(z: PackedFloat64Array, s: float) -> int:
	var i := 0
	while i < z.size():
		if s >= z[i] and s <= z[i + 1]:
			return i
		i += 2
	return -1


## Riders keep the despawn clock of the ore they were: every half second
## the ones past it go, as loose ore would have. A belt keeps them fresh.
func _age() -> void:
	var fresh := tick + int(LIFETIME * 60.0)
	for tr in tracks:
		var n: int = tr.count()
		if n == 0:
			continue
		if tr.keep_alive:
			for i in n:
				if tr.rdie[i] != NEVER and tr.rdie[i] < fresh:
					tr.rdie[i] = fresh
			continue
		var i := n - 1
		while i >= 0:
			if tr.rdie[i] <= tick:
				var d: Array = tr.take(i)
				_drop_tag(d[5])
			i -= 1


## Parked bodies follow their riders (a few times a second): anything that
## kept hold of one (a magpie's target, a test) sees about where it is.
func _sync_parked() -> void:
	for tr in tracks:
		var rt: PackedInt32Array = tr.rtag
		for i in rt.size():
			var t: int = rt[i]
			if t == 0:
				continue
			var o = _tags.get(t)
			if o != null and is_instance_valid(o):
				var sg: int = tr.seg_at(tr.rs[i])
				o.position = tr.center_at(tr.rs[i], KR[tr.rkind[i]])
				o.linear_velocity = tr.tan[sg] * tr.rv[i]


func _noise(amount: float) -> void:
	if is_inside_tree():
		for m in get_tree().get_nodes_in_group("noise_meters"):
			m.level += amount * NOISE


# ── zones: where pieces watch the ore ──────────────────────────────────

func _on_node_changed(n: Node) -> void:
	if _zones_dirty or tracks.is_empty():
		return
	if n is Area2D:
		var p := n.get_parent()
		while p != null and p != _root:
			if p is CharacterBody2D or p is RigidBody2D:
				return        # a walker's or a loose body's: not a watcher
			p = p.get_parent()
		_zones_dirty = true
	elif n.get_parent() == _root and n is Node2D and not (n is RigidBody2D) and not (n is CharacterBody2D) \
			and n.scene_file_path.begins_with("res://scenes/"):
		_zones_dirty = true


## Whether node n (a child of the scene) is a piece that watches ore.
func _is_watcher(n: Node, own: Dictionary) -> bool:
	if not (n is Node2D) or n is RigidBody2D or n is CharacterBody2D or own.has(n):
		return false
	if not n.scene_file_path.begins_with("res://scenes/") or n.has_meta("ghost") or n.is_queued_for_deletion():
		return false
	if n.is_in_group("enemies") or n.is_in_group("ore") or n.is_in_group("ingots") or n.name == "Player":
		return false
	return true


## The world rects each watcher looks at: its ore-seeing areas' boxes and
## its ore_watch() (or WATCH_R round it when it names none).
func _watch_rects(n: Node2D) -> Array:
	var out := []
	if n.has_method("ore_watch"):
		out.append_array(n.ore_watch())
	else:
		out.append(Rect2(n.global_position - Vector2(WATCH_R, WATCH_R), Vector2(WATCH_R, WATCH_R) * 2.0))
	for a in n.find_children("*", "Area2D", true, false):
		if not (a.collision_mask & 2) or a.has_meta("track_catch"):
			continue
		var skip := false
		var p: Node = a.get_parent()
		while p != null and p != n:
			if p is CharacterBody2D or (p is RigidBody2D and (p.is_in_group("ore") or p.is_in_group("ingots"))):
				skip = true
				break
			p = p.get_parent()
		if skip:
			continue
		for cs in a.get_children():
			if cs is CollisionShape2D and cs.shape != null and not cs.disabled:
				out.append(cs.global_transform * cs.shape.get_rect())
			elif cs is CollisionPolygon2D and cs.polygon.size() > 2 and not cs.disabled:
				var r := Rect2(cs.polygon[0], Vector2.ZERO)
				for q in cs.polygon:
					r = r.expand(q)
				out.append(cs.global_transform * r)
	return out


func _signature(n: Node2D) -> Array:
	var sig: Array = [n.global_transform]
	if n.has_method("ore_watch"):
		sig.append(n.ore_watch())
	return sig


func _rebuild_zones() -> void:
	_zones_dirty = false
	_watch_sig.clear()
	var own := {}
	for tr in tracks:
		if is_instance_valid(tr.piece):
			own[tr.piece] = true
	for sk in _sinks:
		own[sk[0]] = true
	for tk in _tickers:
		own[tk] = true
	var rects := []
	if _root != null:
		for n in _root.get_children():
			if _is_watcher(n, own):
				rects.append_array(_watch_rects(n))
				_watch_sig.append([n, _signature(n)])
	zone_count = 0
	for tr in tracks:
		var z := PackedFloat64Array()
		if tr.solid:
			for r in rects:
				if tr.bounds.intersects(r):
					_zone_of(tr, r, z)
		tr.zones = _merge(z, tr.length)
		zone_count += tr.zones.size() / 2


## Adds to z the stretch of tr whose riding band crosses rect r.
func _zone_of(tr: Track, r: Rect2, z: PackedFloat64Array) -> void:
	var rp := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for sg in tr.tan.size():
		var a: Vector2 = tr.pts[sg]
		var b: Vector2 = tr.pts[sg + 1]
		var up: Vector2 = tr.nrm[sg] * ZONE_BAND
		var dn: Vector2 = tr.nrm[sg] * 2.0
		var band := PackedVector2Array([a - dn, b - dn, b + up, a + up])
		var lo := INF
		var hi := -INF
		for poly in Geometry2D.intersect_polygons(band, rp):
			for q in poly:
				var along: float = (q - a).dot(tr.tan[sg])
				lo = minf(lo, along)
				hi = maxf(hi, along)
		if lo <= hi:
			z.append(tr.cum[sg] + lo - ZONE_PAD)
			z.append(tr.cum[sg] + hi + ZONE_PAD)


static func _merge(z: PackedFloat64Array, length: float) -> PackedFloat64Array:
	if z.is_empty():
		return z
	var pairs := []
	for i in range(0, z.size(), 2):
		pairs.append([z[i], z[i + 1]])
	pairs.sort_custom(func(x, y): return x[0] < y[0])
	var out := PackedFloat64Array()
	for pr in pairs:
		if not out.is_empty() and pr[0] <= out[out.size() - 1]:
			out[out.size() - 1] = maxf(out[out.size() - 1], pr[1])
		else:
			out.append(pr[0])
			out.append(pr[1])
	# a zone reaching an end reaches past it (a rider at the very end is in it)
	for i in range(0, out.size(), 2):
		if out[i] <= 0.0:
			out[i] = -INF
		if out[i + 1] >= length:
			out[i + 1] = INF
	return out


## Every half second: did anything the zones were built from move (a
## swinging arm, a lift, a rail re-dragged)? Then rebuild them.
func _check_watchers() -> void:
	for w in _watch_sig:
		var n = w[0]
		if not is_instance_valid(n) or n.is_queued_for_deletion() or _signature(n) != w[1]:
			_zones_dirty = true
			return


# ── sound ──────────────────────────────────────────────────────────────

## Riders knocking together (or into a stop): the ore-on-ore knock.
func _clack(tr: Track, s: float, speed: float) -> void:
	if _anchors.is_empty() or tr.muffled:
		return
	_noise(speed)
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
