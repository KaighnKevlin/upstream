extends RefCounted
## Track: one stretch of the 1D marble track (scripts/track/track_net.gd runs
## them all). A polyline in world space, travelled start -> end, and the
## riders on it: marbles that are not physics bodies, only a distance along
## the path (s, to where the marble touches it), a speed along it (v,
## negative when rolling back), a spin angle, a kind and a sprite frame.
##
## Riders are kept in order of s (index 0 nearest the start) and never pass
## each other, so a track is a queue: the one in front stops, the rest stack
## up behind it. The hot loops live here, on the track's own packed arrays
## (edited in place; from outside, `tr.rs[i] = x` would copy the array).

## Gravity along the slope for a ball rolling without slipping: 980 * 2/3
## (a solid disc, which is what a 2D physics circle is).
const G_ALONG := 653.0
## How hard a powered track holds its riders to its speed (px/s per s).
const DRIVE_ACC := 900.0
## Contacts slower than this don't bounce (a resting queue would jitter).
const REST_MIN := 40.0

var id := 0
var piece: Node2D                       # the build piece this belongs to
var pts := PackedVector2Array()         # world-space path, start -> end
var cum := PackedFloat64Array()         # distance to each point
var tan := PackedVector2Array()         # per segment: unit direction of travel
var nrm := PackedVector2Array()         # per segment: the riding side (up)
var slope := PackedFloat64Array()       # per segment: tangent . down
var spin := PackedFloat64Array()        # per segment: +1 if rolling forward turns a ball clockwise
var length := 0.0
var bounds := Rect2()
var drive := 0.0                        # powered: riders held to this speed (px/s)
var catches := true                     # physics ore landing on it becomes riders
var solid := false                      # it has a real rail under it (a chute): riders can drop to physics anywhere on it
var lip_mode := -1                      # the start's stop: -1 auto (runs down from it), 0 none, 1 always
var boost_only := false                 # powered, but only speeds riders up (a booster): gravity still acts
var drive_acc := DRIVE_ACC              # how hard the drive holds them (px/s per s)
var vcap := 0.0                         # > 0: no rider faster than this (a brake)
var extra_damp := 0.0                   # more drag (1/s) on top of the net's (felt)
var muffled := false                    # its knocks make no sound and no noise (felt)
var keep_alive := false                 # riders on it don't age toward despawning (a belt)
var zones := PackedFloat64Array()       # [s0, s1, ...]: stretches where a piece watches the ore: physics there
var dzones := PackedFloat64Array()      # the same, this tick, round loose bodies lying on it

# graph, filled in by the net
var outs: Array = []                    # tracks this end feeds (a junction when > 1)
var router: Object = null               # picks among outs: pick(kind, free) -> index or -1
var prev = null                         # the track feeding this start (rolling back goes there)
var sink: Object = null                 # takes riders off the end: can_accept(kind), accept(kind, v)
var lip := true                         # a stop at the start (nothing feeds it and it runs down from there)
var gate := -1                          # -1 open; 0 shut; n: let n more off the end
var notify := false                     # tell the piece when a rider leaves the end: rider_passed(track, kind)
var cands := {}                         # physics ore inside the catch area (instance id -> body)

# riders, in order of s
var rs := PackedFloat64Array()
var rv := PackedFloat64Array()
var rrot := PackedFloat64Array()
var rkind := PackedInt32Array()
var rframe := PackedInt32Array()
var rtag := PackedInt32Array()          # 0, or the net's key for the metas it carries (scripts/track/track_net.gd)
var rdie := PackedInt32Array()          # the net tick it would have despawned at, as loose ore
var rlast := PackedFloat64Array()       # where it was at the end of the last tick (its spin follows travel)


func set_path(p: PackedVector2Array) -> void:
	pts = p
	cum = PackedFloat64Array([0.0])
	tan = PackedVector2Array()
	nrm = PackedVector2Array()
	slope = PackedFloat64Array()
	spin = PackedFloat64Array()
	length = 0.0
	bounds = Rect2(p[0], Vector2.ZERO)
	for i in range(1, p.size()):
		var d := p[i] - p[i - 1]
		var l := maxf(d.length(), 0.001)
		var t := d / l
		var n := Vector2(t.y, -t.x)
		if n.y > 0.0 or (n.y == 0.0 and n.x > 0.0):
			n = -n                              # the top side (for a lift: its left)
		length += l
		cum.append(length)
		tan.append(t)
		nrm.append(n)
		slope.append(t.y)
		spin.append(signf(t.dot(Vector2(-n.y, n.x))))
		bounds = bounds.expand(p[i])
	bounds = bounds.grow(16.0)


## Segment holding distance s.
func seg_at(s: float) -> int:
	var k := 0
	while k < slope.size() - 1 and s > cum[k + 1]:
		k += 1
	return k


## World point on the path at s (clamped to the path).
func point_at(s: float) -> Vector2:
	var k := seg_at(s)
	return pts[k] + tan[k] * clampf(s - cum[k], 0.0, cum[k + 1] - cum[k])


## Where a rider of radius r at s is drawn (its centre, above the path).
func center_at(s: float, r: float) -> Vector2:
	return point_at(s) + nrm[seg_at(s)] * r


func count() -> int:
	return rs.size()


# ── the tick ───────────────────────────────────────────────────────────

## Gravity (or the drive), rolling drag, move. kr: radius per kind.
func integrate(dt: float, kr: PackedFloat64Array, damp: float, roll: float) -> void:
	var n := rs.size()
	if n == 0:
		return
	var k := 0
	var last := slope.size() - 1
	var rdt := roll * dt
	var dmp := damp + extra_damp
	var dacc := drive_acc * dt
	for i in n:
		var s := rs[i]
		while k < last and s > cum[k + 1]:
			k += 1
		var v := rv[i]
		if drive != 0.0 and not boost_only:
			v = move_toward(v, drive, dacc)
		else:
			v += (G_ALONG * slope[k] - dmp * v) * dt
			if v > rdt:
				v -= rdt
			elif v < -rdt:
				v += rdt
			else:
				v = 0.0
			if boost_only and v < drive:
				v = minf(v + dacc, drive)
		if vcap > 0.0:
			v = clampf(v, -vcap, vcap)
		rs[i] = s + v * dt
		rv[i] = v


## Spin from the distance each rider actually travelled this tick (after
## the queue and the stops had their say): one held behind the rider in
## front, or against a stop, a full sink or a shut gate, doesn't turn.
func spin_from_travel(kr: PackedFloat64Array) -> void:
	var n := rs.size()
	var k := 0
	var last := slope.size() - 1
	for i in n:
		var s := rs[i]
		while k < last and s > cum[k + 1]:
			k += 1
		var ds := s - rlast[i]
		if ds != 0.0:
			rrot[i] += ds * spin[k] / kr[rkind[i]]
			rlast[i] = s


## Riders can't overlap: the one behind is stopped by the one in front
## (a 1D collision: momentum shared, restitution e), the lead by `ub` (an
## end stop: bounces back at e), the last by `lb` (the start lip), which
## pushes the queue forward. Hard contacts go into `clacks` as (s, speed).
func contacts(ub: float, lb: float, kr: PackedFloat64Array, km: PackedFloat64Array, e: float, clacks: Array) -> void:
	var n := rs.size()
	if n == 0:
		return
	var li := n - 1
	if rs[li] > ub:
		rs[li] = ub
		if rv[li] > 0.0:
			if rv[li] > 60.0:
				clacks.append(ub)
				clacks.append(rv[li])
			rv[li] = -rv[li] * (e if rv[li] > REST_MIN else 0.0)
	var i := li - 1
	while i >= 0:
		var ka := rkind[i]
		var kb := rkind[i + 1]
		var gap := kr[ka] + kr[kb]
		var most := rs[i + 1] - gap
		if rs[i] > most:
			rs[i] = most
			var va := rv[i]
			var vb := rv[i + 1]
			if va - vb > REST_MIN:
				# a knock: momentum shared, some bounce
				var ma := km[ka]
				var mb := km[kb]
				var p := ma * va + mb * vb
				rv[i] = (p - mb * e * (va - vb)) / (ma + mb)
				rv[i + 1] = (p + ma * e * (va - vb)) / (ma + mb)
				if va - vb > 60.0:
					clacks.append(most)
					clacks.append(va - vb)
			elif va > vb:
				# resting against the one in front: moves as one with it (sharing
				# momentum here would bank each tick's gravity as speed in a
				# stopped queue)
				rv[i] = vb
		i -= 1
	if rs[0] < lb:
		rs[0] = lb
		if rv[0] < 0.0:
			rv[0] = -rv[0] * (e if -rv[0] > REST_MIN else 0.0)
		for j in range(1, n):
			var least := rs[j - 1] + kr[rkind[j - 1]] + kr[rkind[j]]
			if rs[j] < least:
				rs[j] = least
				if rv[j] < rv[j - 1]:
					rv[j] = rv[j - 1]


## Room for a rider of radius r entering at the start: the furthest s it
## can take (INF when empty; negative when there's no room).
func room_at_start(r: float, kr: PackedFloat64Array) -> float:
	if rs.is_empty():
		return INF
	return rs[0] - kr[rkind[0]] - r


## Room for one rolling back in at the end: the least s it can take.
func room_at_end(r: float, kr: PackedFloat64Array) -> float:
	if rs.is_empty():
		return -INF
	var li := rs.size() - 1
	return rs[li] + kr[rkind[li]] + r


## The lead stops at s (an end stop or a full sink); returns its speed into it.
func hold_lead(s: float, e: float) -> float:
	var li := rs.size() - 1
	rs[li] = s
	var v := rv[li]
	if v > 0.0:
		rv[li] = -v * (e if v > REST_MIN else 0.0)
	return v


func hold_first(s: float, e: float) -> float:
	rs[0] = s
	var v := rv[0]
	if v < 0.0:
		rv[0] = -v * (e if -v > REST_MIN else 0.0)
	return -v


func set_speed(i: int, v: float) -> void:
	rv[i] = v


## Takes rider i off: [s, v, rot, kind, frame, tag, die].
func take(i: int) -> Array:
	var out := [rs[i], rv[i], rrot[i], rkind[i], rframe[i], rtag[i], rdie[i]]
	rs.remove_at(i)
	rv.remove_at(i)
	rrot.remove_at(i)
	rkind.remove_at(i)
	rframe.remove_at(i)
	rtag.remove_at(i)
	rdie.remove_at(i)
	rlast.remove_at(i)
	return out


## Puts a rider on at s, in order. Returns its index.
func insert(s: float, v: float, rot: float, kind: int, frame: int, tag := 0, die := 0x7fffffff) -> int:
	var i := rs.size()
	while i > 0 and rs[i - 1] > s:
		i -= 1
	rs.insert(i, s)
	rv.insert(i, v)
	rrot.insert(i, rot)
	rkind.insert(i, kind)
	rframe.insert(i, frame)
	rtag.insert(i, tag)
	rdie.insert(i, die)
	rlast.insert(i, s)
	return i


## The zone (static or this tick's) holding s: its index into zones (even)
## or into dzones (odd, as 2k+1), or -1.
func zone_at(s: float) -> int:
	var i := 0
	while i < zones.size():
		if s >= zones[i] and s <= zones[i + 1]:
			return i
		i += 2
	i = 0
	while i < dzones.size():
		if s >= dzones[i] and s <= dzones[i + 1]:
			return i + 1
		i += 2
	return -1


func clear_riders() -> void:
	rs.clear()
	rv.clear()
	rrot.clear()
	rkind.clear()
	rframe.clear()
	rtag.clear()
	rdie.clear()
	rlast.clear()



func set_sv(i: int, s: float, v: float) -> void:
	rs[i] = s
	rv[i] = v
