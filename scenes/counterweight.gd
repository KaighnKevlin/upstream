extends Node2D
## Counterweight lift: two buckets on a rope over a pulley, one up, one
## down, no power but gravity. Pieces dropped into the top bucket pile up
## until it outweighs whatever's in the bottom one; then it sinks, hauling
## the other up. At the bottom it tips its load out to the left; at the
## top the risen bucket tips its load out to the right. Then they've
## swapped: the new top one is waiting. Drop heavy, lift light: an iron in
## the top bucket brings a copper up. The node is the pulley.

const SFX = preload("res://scripts/sfx.gd")
const DROP := 150.0              # how far a bucket travels
const GAP := 18.0                # half the distance between the ropes
const RIDE := 1.1                # s per trip
const MARGIN := 0.5              # the top has to outweigh the bottom by this

var trips := 0                   # tests
var lifted := 0
var _top := 0                    # which bucket (0 left, 1 right) is up
var _loads: Array = [[], []]
var _t := -1.0                   # travel progress, -1 when resting
var _cool := {}


func _bucket(k: int) -> Vector2:
	var x := -GAP if k == 0 else GAP
	var up := 1.0 if k == _top else 0.0
	if _t >= 0:
		var f := clampf(_t / RIDE, 0.0, 1.0)
		up = (1.0 - f) if k == _top else f
	return Vector2(x, 26 + (1.0 - up) * DROP)


func _mass(k: int) -> float:
	var m := 0.0
	for b in _loads[k]:
		if is_instance_valid(b):
			m += b.mass
	return m


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	# catch pieces landing in either bucket while it's resting
	if _t < 0:
		for o in get_tree().get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or _cool.get(o.get_instance_id(), 0.0) > now:
				continue
			for k in 2:
				if o in _loads[k]:
					continue
				var c := global_position + _bucket(k)
				if absf(o.global_position.x - c.x) < 11 and o.global_position.y > c.y - 16 and o.global_position.y < c.y + 2:
					_loads[k].append(o)
					o.gravity_scale = 0.0
		if not _loads[_top].is_empty() and _mass(_top) > _mass(1 - _top) + MARGIN:
			_t = 0.0
			SFX.play_small(self, SFX.sfx_ore_knock("wood"), -12.0, 0.7)
	else:
		_t += delta
		if _t >= RIDE:
			# arrived: the sunk one tips out left at the bottom, the risen one right at the top
			var sunk := _top
			for b in _loads[sunk]:
				if is_instance_valid(b):
					_release(b, Vector2(-120, -40), now)
			for b in _loads[1 - sunk]:
				if is_instance_valid(b):
					_release(b, Vector2(140, -60), now)
					lifted += 1
			_loads = [[], []]
			_top = 1 - _top
			_t = -1.0
			trips += 1
	# hold what's in the buckets in them
	for k in 2:
		var c := global_position + _bucket(k)
		var i := 0
		for b in _loads[k]:
			if is_instance_valid(b):
				var at := c + Vector2((i % 2) * 6 - 3, -6 - (i / 2) * 7)
				b.linear_velocity = (at - b.global_position) / delta
				if "_timer" in b:
					b._timer = 0.0
				i += 1
	queue_redraw()


func _release(b: RigidBody2D, v: Vector2, now: float) -> void:
	b.gravity_scale = 1.0
	b.linear_velocity = v
	_cool[b.get_instance_id()] = now + 1.5


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the beam and pulley
	draw_line(Vector2(-30, -8), Vector2(30, -8), dark, 4.0)
	draw_circle(Vector2.ZERO, GAP + 2, dark)
	draw_circle(Vector2.ZERO, GAP, Color(0.45, 0.35, 0.22))
	draw_circle(Vector2.ZERO, 4.0, brass)
	for k in 2:
		var c := _bucket(k)
		var x := -GAP if k == 0 else GAP
		draw_line(Vector2(x, 0), c + Vector2(0, -16), Color(0.7, 0.62, 0.45), 1.0)
		draw_line(c + Vector2(-10, -16), c + Vector2(-8, 0), dark, 3.0)
		draw_line(c + Vector2(8, 0), c + Vector2(10, -16), dark, 3.0)
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), dark, 3.0)
		draw_line(c + Vector2(-8, -1), c + Vector2(8, -1), brass, 1.0)
	# the top of the drop and the tip-out marks
	var font := ThemeDB.fallback_font
	draw_string(font, _bucket(_top) + Vector2(-12, -22), "%.1f" % _mass(_top), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
	draw_string(font, _bucket(1 - _top) + Vector2(-12, -22), "%.1f" % _mass(1 - _top), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
