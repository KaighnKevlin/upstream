extends Node2D
## Trommel: a long perforated steel drum on a slight slope, turning slowly
## on its rollers. Drawn like a chute: drag from its high end (the mouth)
## to its low end. Feed a mixed stream into the mouth and everything
## tumbles along inside; grit is small enough to fall out through the
## holes along the way, bigger pieces (ore, scrap, shot, ingots) tumble
## on and roll out of the low end. A size sorter for a whole stream,
## with the grit spread along its length. Slow on its own, full speed
## with a gravity wheel or steam engine in reach.

const Hold = preload("res://scripts/hold.gd")
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
const FRAMES := 6                # the drum's turning art: frames per quarter turn
const INNER_TEX := preload("res://assets/sprites/trommel_inner.png")   # the far wall
const BACK_TEX := preload("res://assets/sprites/trommel_back.png")     # its holes, 6 frames
const FRONT_TEX := preload("res://assets/sprites/trommel_front.png")   # near staves and rims, 6 frames
const HOLES_TEX := preload("res://assets/sprites/trommel_holes.png")   # near holes, 6 frames
const HOOP_TEX := preload("res://assets/sprites/trommel_hoop.png")
const STAND_TEX := preload("res://assets/sprites/trommel_stand.png")
const MOUTH_TEX := preload("res://assets/sprites/trommel_mouth.png")
const GEAR_TEX := preload("res://assets/sprites/trommel_gear.png")

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
	# pixel art (drawn tiled along the drum in _draw and _draw_front), made
	# first so ghosts and build-bar icons have it
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# the drum's near side (its staves and holes), drawn over the riders
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
		if not is_instance_valid(o) or o.freeze or not Hold.free_to_take(o, self):
			continue
		var id: int = o.get_instance_id()
		if _riders.has(id) or _cool.get(id, 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		var s := p.dot(d)
		var across := p.dot(dn)
		if s > -8.0 and s < l - 10.0 and across > -R - 10.0 and across < R + 2.0:
			Hold.claim(o, self)
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
		Hold.claim(o, self)
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
	Hold.release(o, self)
	o.global_position = at
	o.linear_velocity = vel
	_cool[id] = now + 1.5
	_riders.erase(id)


func _exit_tree() -> void:
	for id in _riders:
		var o = _riders[id][0]
		if is_instance_valid(o):
			Hold.release(o, self)
	_riders.clear()


func _draw() -> void:
	var l := end_offset.length()
	if l < 0.1:
		return
	var f := _frame()
	# the drum's own frame: x along the axis, +y down across it
	_along(self)
	# stands: a roller at each end on a post to the ground below
	for s in [10.0, l - 10.0]:
		draw_texture(STAND_TEX, Vector2(s - 7, R + 1.5 - 4))
	# the inside of the drum, in shadow behind the riders, and its far holes
	_tile(self, INNER_TEX, 0, 24, 0.0, l, -12.0)
	_tile(self, BACK_TEX, f, 24, FIRST_HOLE - 3.0, l - 4.0, -12.0)
	# the mouth: a brass feed lip flaring up at the high end
	draw_texture(MOUTH_TEX, Vector2(-8, -R - 10))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Which of the drum's turning frames shows (the pattern repeats every
## quarter turn).
func _frame() -> int:
	return int(fposmod(_turn, TAU / 4.0) / (TAU / 4.0) * FRAMES) % FRAMES


## Set `ci` drawing in the drum's frame: x along the axis, +y toward
## _down() (flipped on leftward drums).
func _along(ci: CanvasItem) -> void:
	var d := _axis()
	ci.draw_set_transform(Vector2.ZERO, d.angle(), Vector2(1, 1.0 if d.x >= 0 else -1.0))


## Frame `f` of a strip of `fh`-tall frames, repeated along the drum from x0
## to x1 (the last copy cut short), its top at y.
func _tile(ci: CanvasItem, tex: Texture2D, f: int, fh: int, x0: float, x1: float, y: float) -> void:
	var w := float(tex.get_width())
	var x := x0
	while x < x1 - 0.01:
		var seg := minf(w, x1 - x)
		ci.draw_texture_rect_region(tex, Rect2(x, y, seg, fh), Rect2(0, f * fh, seg, fh))
		x += w


func _draw_front() -> void:
	var l := end_offset.length()
	if l < 0.1:
		return
	var f := _frame()
	_along(_front)
	# the near side: staves and rims, open between so the riders show, and
	# its holes (none in the mouth)
	_tile(_front, FRONT_TEX, f, 26, 0.0, l, -13.0)
	_tile(_front, HOLES_TEX, f, 26, FIRST_HOLE - 3.0, l - 4.0, -13.0)
	# brass hoops: both ends and every so often along
	var hoops := [1.0, l - 1.0]
	var n := int(l / 60.0)
	for i in range(1, n + 1):
		hoops.append(l * i / float(n + 1))
	for s in hoops:
		_front.draw_texture(HOOP_TEX, Vector2(roundf(s) - 2, -13))
	# the drive gear on the mouth hoop, turning with the drum
	var d := _axis()
	var g := d.rotated(-PI * 0.5) * (R + 1.0)
	if g.y > 0.0:
		g = -g
	_front.draw_set_transform(g + d * 2.0, _turn * 2.0, Vector2.ONE)
	_front.draw_texture(GEAR_TEX, Vector2(-5.5, -5.5))
	_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
