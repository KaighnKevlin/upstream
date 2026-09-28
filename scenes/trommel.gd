extends Node2D
## Trommel: a long perforated steel drum on a slight slope, turning slowly
## on its rollers. Drawn like a chute: drag from its high end (the mouth)
## to its low end. Feed a mixed stream into the mouth and everything
## tumbles along inside; grit is small enough to fall out through the
## holes along the way, bigger pieces (ore, scrap, shot, ingots) tumble
## on and roll out of the low end. A size sorter for a whole stream,
## with the grit spread along its length. Slow on its own, full speed
## with a gravity wheel or steam engine in reach.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")

const LEN_MIN := 64.0
const LEN_MAX := 240.0
const R := 11.0                  # the drum's radius
const HOLE := 12.0               # spacing of the rings of holes along the drum
const FIRST_HOLE := 18.0         # no holes in the mouth
const V_ALONG := 80.0            # px/s along the drum at full power
const SPIN := 5.0                # rad/s the drum turns at full power
const V_OUT := 100.0             # leaving the low end
const SMALL := ["grit"]          # what falls through the holes
const SIFT_CHANCE := 0.3         # of a small piece at the bottom finding a hole, per ring

## The low end of the drum, relative to its mouth.
@export var end_offset := Vector2(150, 18)

var sifted := 0                  # tests: pieces out through the holes
var tumbled := 0                 # tests: pieces out of the low end
var sift_at := []                # tests: how far along each sifted piece fell
var sifted_kinds := []           # tests
var tumbled_kinds := []          # tests
var transit := []                # tests: seconds mouth to low end
var _riders := {}                # id -> [body, s along, tumble phase, time in]
var _cool := {}
var _turn := 0.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _clack := 0.0
var _front: Node2D
var _live := false


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()
	if _front:
		_front.queue_redraw()


func _ready() -> void:
	z_index = 0                  # under the ore: the tumbling pieces show inside
	# the drum's near side (its mesh of holes), drawn over the riders
	_front = Node2D.new()
	_front.z_index = 2
	_front.draw.connect(_draw_front)
	add_child(_front)
	if has_meta("ghost"):
		return
	_live = true
	add_to_group("power_users")


func _axis() -> Vector2:
	return end_offset / maxf(end_offset.length(), 1.0)


## "Down" across the drum: the side the pieces tumble on and the holes shed from.
func _down() -> Vector2:
	var d := _axis()
	var n := Vector2(-d.y, d.x)
	return n if n.y >= 0.0 else -n


func _physics_process(delta: float) -> void:
	if not _live:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_turn += SPIN * _rate * delta
	var now := Time.get_ticks_msec() / 1000.0
	var l := end_offset.length()
	var d := _axis()
	var dn := _down()
	# take in anything loose that falls into the drum
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion() or o.has_meta("caught_by"):
			continue
		var id: int = o.get_instance_id()
		if _riders.has(id) or _cool.get(id, 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		var s := p.dot(d)
		var across := p.dot(dn)
		if s > -8.0 and s < l - 10.0 and across > -R - 10.0 and across < R + 2.0:
			o.gravity_scale = 0.0
			_riders[id] = [o, maxf(s, 0.0), randf() * TAU, now]
	var v := V_ALONG * _rate
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o) or o.is_queued_for_deletion():
			_riders.erase(id)
			continue
		var s0: float = r[1]
		var s: float = s0 + v * delta
		var ph: float = r[2] + SPIN * _rate * delta * 1.3
		r[1] = s
		r[2] = ph
		var small: bool = o.is_in_group("ore") and o.get("kind") in SMALL
		var rad := 2.6 if small else 6.0
		# lifted up the wall by the turning drum, falling back to the bottom
		var low := absf(cos(ph))
		if small and s > FIRST_HOLE:
			var ring0 := floori((s0 - FIRST_HOLE) / HOLE)
			var ring1 := floori((s - FIRST_HOLE) / HOLE)
			# through a ring of holes while it's down at the bottom (and lands
			# on one: a hole a ring, so some go on), so the grit comes out
			# spread along the drum; the last ring lets out any it has missed
			if (ring1 > ring0 and low > 0.6 and randf() < SIFT_CHANCE) or s > l - 12.0:
				_release(o, id, global_position + d * s + dn * (R + 3.0), dn * 50.0 + d * v * 0.4, now)
				sifted += 1
				sift_at.append(int(s))
				sifted_kinds.append(o.get("kind"))
				SFX.play_small(self, SFX.sfx_ore_knock("metal"), -22.0, 1.8)
				continue
		if s >= l:
			_release(o, id, global_position + end_offset + d * 4.0 + dn * (R - rad - 1.0), d * maxf(V_OUT, v * 1.2), now)
			tumbled += 1
			tumbled_kinds.append(o.get("kind"))
			transit.append(snappedf(now - r[3], 0.1))
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.0)
			continue
		var at: Vector2 = global_position + d * s + dn * (R - rad - 1.0) * (0.15 + 0.85 * low)
		o.linear_velocity = (at - o.global_position) / delta
		o.angular_velocity = SPIN * _rate * 2.0
		if "_timer" in o:
			o._timer = 0.0
	# a steady clatter while there's something tumbling
	_clack -= delta
	if _clack <= 0.0 and not _riders.is_empty():
		_clack = 0.55 / maxf(_rate, 0.35)
		SFX.play_small(self, SFX.sfx_roll(), -20.0, 0.8 + 0.3 * _rate)
	queue_redraw()
	_front.queue_redraw()


func _release(o: RigidBody2D, id: int, at: Vector2, vel: Vector2, now: float) -> void:
	o.gravity_scale = 1.0
	o.global_position = at
	o.linear_velocity = vel
	_cool[id] = now + 1.5
	_riders.erase(id)


func _exit_tree() -> void:
	for id in _riders:
		var o = _riders[id][0]
		if is_instance_valid(o):
			o.gravity_scale = 1.0
	_riders.clear()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var d := _axis()
	var dn := _down()
	var e := end_offset
	# stands: a roller at each end on a short post to the ground below
	for p in [d * 10.0, e - d * 10.0]:
		draw_line(p + dn * R, p + dn * (R + 14.0), dark, 4.0)
		draw_line(p + dn * R, p + dn * (R + 14.0), steel.darkened(0.3), 2.0)
		draw_line(p + dn * (R + 14.0) - d * 6.0, p + dn * (R + 14.0) + d * 6.0, dark, 3.0)
		draw_circle(p + dn * (R + 1.5), 3.0, dark)
		draw_circle(p + dn * (R + 1.5), 2.0, brass.darkened(0.2))
	# the inside of the drum, in shadow behind the riders
	var shell := PackedVector2Array([-dn * R, e - dn * R, e + dn * R, dn * R])
	draw_colored_polygon(shell, Color(0.14, 0.12, 0.11))
	# the far wall's holes, scrolling round as it turns
	_holes(self, false)
	# the mouth: a brass feed lip flaring up at the high end
	draw_line(-dn * R, -dn * (R + 8.0) - d * 6.0, dark, 4.0)
	draw_line(-dn * R, -dn * (R + 8.0) - d * 6.0, brass, 2.0)


## The holes on the far (back) or near (front) side of the turning drum: rows
## round the drum at 8 angles, a hole every HOLE along each.
func _holes(ci: CanvasItem, front: bool) -> void:
	var l := end_offset.length()
	var d := _axis()
	var dn := _down()
	for k in 8:
		var th := _turn + k * TAU / 8.0
		var near := sin(th) > 0.0
		if near != front:
			continue
		var across := cos(th) * (R - 1.5)
		var shade := 0.5 + 0.5 * absf(sin(th))
		var x := FIRST_HOLE
		while x < l - 4.0:
			# rows stagger, so the pattern reads as a mesh
			var off := (HOLE * 0.5) if k % 2 == 1 else 0.0
			if x + off < l - 4.0:
				var p := d * (x + off) + dn * across
				ci.draw_circle(p, 1.1 if front else 1.0, Color(0.05, 0.04, 0.04, 0.6 if front else 0.6 * shade))
			x += HOLE


func _draw_front() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var l := end_offset.length()
	var d := _axis()
	var dn := _down()
	var e := end_offset
	# the near skin: see-through steel mesh, the riders show between the holes
	var shell := PackedVector2Array([-dn * R, e - dn * R, e + dn * R, dn * R])
	_front.draw_colored_polygon(shell, Color(steel.r, steel.g, steel.b, 0.12))
	_holes(_front, true)
	# long ribs (the drum's staves) slide round as it turns
	for k in 4:
		var th := _turn + k * TAU / 4.0 + TAU / 16.0
		if sin(th) <= 0.0:
			continue
		var across := cos(th) * R
		_front.draw_line(dn * across, e + dn * across, Color(0.7, 0.72, 0.78, 0.35 + 0.4 * sin(th)), 1.0)
	# top and bottom edges
	_front.draw_line(-dn * R, e - dn * R, dark, 2.0)
	_front.draw_line(dn * R, e + dn * R, dark, 2.0)
	_front.draw_line(-dn * (R - 1.0), e - dn * (R - 1.0), steel.lightened(0.2), 1.0)
	# brass hoops: both ends and every so often along
	var hoops := [0.0, l]
	var n := int(l / 60.0)
	for i in range(1, n + 1):
		hoops.append(l * i / float(n + 1))
	for s in hoops:
		var p: Vector2 = d * s
		_front.draw_line(p - dn * (R + 1.0), p + dn * (R + 1.0), dark, 4.0)
		_front.draw_line(p - dn * R, p + dn * R, brass, 2.0)
	# a gear ring on the mouth hoop, its teeth turning: shows the drive
	var g := -dn * (R + 1.0)
	for k in 6:
		var a := _turn * 2.0 + k * TAU / 6.0
		_front.draw_circle(d * (cos(a) * 3.0) + g + dn * (sin(a) * 1.0), 0.9, brass.lightened(0.2))
