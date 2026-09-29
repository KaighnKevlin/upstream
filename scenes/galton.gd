extends Node2D
## Galton board: a hopper that lets marbles go one at a time over a
## triangle of pegs, and a row of tall bins underneath. Every peg is a coin
## toss (a marble touching one is knocked a step left or right at random),
## so the bins fill into a bell curve; a histogram over the bins and
## the ideal binomial curve show it building. The node is the hopper's
## mouth, over the top peg.
## Ore-only layer: walkers pass through.

const ORE_ONLY := 64
const ROWS := 10
const PITCH := 24.0
const PEG_R := 4.0
const BIN_H := 180.0
const EVERY := 0.15              # s between marbles

@export var marbles := 80

var dropped := 0                 # tests
var bins: Array[int] = []
var _t := 0.0
var _count_t := 0.0


func _row_y(i: int) -> float:
	return 24.0 + i * PITCH * 0.87


func _bins_top() -> float:
	return _row_y(ROWS - 1) + 16.0


func _bin_x(j: int) -> float:    # the centre of bin j (0..ROWS)
	return (j - ROWS * 0.5) * PITCH


func _ready() -> void:
	z_index = 1
	bins.resize(ROWS + 1)
	bins.fill(0)
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.bounce = 0.2
	m.friction = 0.3
	body.physics_material_override = m
	add_child(body)
	# the pegs: row i has i + 1 of them
	for i in ROWS:
		for j in i + 1:
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = PEG_R
			cs.shape = c
			cs.position = Vector2((j - i * 0.5) * PITCH, _row_y(i))
			body.add_child(cs)
	# the bins' walls and floor
	var top := _bins_top()
	for j in ROWS + 2:
		_seg(body, Vector2(_bin_x(j) - PITCH * 0.5, top), Vector2(_bin_x(j) - PITCH * 0.5, top + BIN_H))
	_seg(body, Vector2(_bin_x(0) - PITCH * 0.5, top + BIN_H), Vector2(_bin_x(ROWS) + PITCH * 0.5, top + BIN_H))


func _seg(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	body.add_child(cs)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t -= delta
	if dropped < marbles and _t <= 0:
		_t = EVERY
		dropped += 1
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.linear_damp = 2.0            # a slow fall, so each peg knocks it just one step left or right
		o.set_meta("spin_damped", true)  # pegs aren't track: a spin kept from peg to peg carries it sideways
		o.global_position = global_position + Vector2(randf_range(-0.5, 0.5), -6)
		o.add_to_group("showcase")
		get_parent().add_child(o)
	# the coin toss: a marble touching a peg is knocked one step left or right,
	# at random, and never twice by the same peg (without this a marble keeps
	# its sideways speed and rolls down the edge of the triangle like a ramp)
	for o in get_tree().get_nodes_in_group("ore"):
		var p: Vector2 = o.global_position - global_position
		if p.y > _bins_top() - 4.0:
			# in the bins: they stack on each other (loose ore otherwise passes through ore)
			o.collision_mask |= 2
			continue
		var i := int(round((p.y - 24.0) / (PITCH * 0.87)))
		if i < 0 or i >= ROWS:
			continue
		var j := int(round(p.x / PITCH + i * 0.5))
		if j < 0 or j > i:
			continue
		var peg := Vector2((j - i * 0.5) * PITCH, _row_y(i))
		if p.distance_to(peg) < PEG_R + 9.0 and p.y < peg.y and o.get_meta("peg", -1) != i * 100 + j:
			o.set_meta("peg", i * 100 + j)
			o.linear_velocity = Vector2((1.0 if randf() < 0.5 else -1.0) * 55.0, -20.0)
	_count_t -= delta
	if _count_t <= 0:
		_count_t = 0.3
		bins.fill(0)
		for o in get_tree().get_nodes_in_group("ore"):
			var p: Vector2 = o.global_position - global_position
			if p.y > _bins_top() and p.y < _bins_top() + BIN_H:
				var j := int(round(p.x / PITCH + ROWS * 0.5))
				if j >= 0 and j <= ROWS:
					bins[j] += 1
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var top := _bins_top()
	# hopper mouth
	draw_line(Vector2(-20, -30), Vector2(-7, -4), dark, 4.0)
	draw_line(Vector2(20, -30), Vector2(7, -4), dark, 4.0)
	draw_line(Vector2(-20, -30), Vector2(-7, -4), brass, 2.0)
	draw_line(Vector2(20, -30), Vector2(7, -4), brass, 2.0)
	# pegs
	for i in ROWS:
		for j in i + 1:
			var p := Vector2((j - i * 0.5) * PITCH, _row_y(i))
			draw_circle(p, PEG_R + 1, dark)
			draw_circle(p, PEG_R, brass)
	# bins
	for j in ROWS + 2:
		var x := _bin_x(j) - PITCH * 0.5
		draw_line(Vector2(x, top), Vector2(x, top + BIN_H), dark, 3.0)
		draw_line(Vector2(x, top), Vector2(x, top + BIN_H), Color(0.72, 0.74, 0.78), 1.0)
	draw_line(Vector2(_bin_x(0) - PITCH * 0.5, top + BIN_H), Vector2(_bin_x(ROWS) + PITCH * 0.5, top + BIN_H), dark, 3.0)
	# the ideal curve: C(n, j) / 2^n of the marbles so far, as the height they'd stack to
	var landed := 0
	for b in bins:
		landed += b
	var per_marble := 13.0 * 13.0 * 0.9 / (PITCH - 1.0)   # px of stack per marble in a bin
	var pts := PackedVector2Array()
	for j in ROWS + 1:
		var ideal := _choose(ROWS, j) / pow(2.0, ROWS) * landed
		pts.append(Vector2(_bin_x(j), top + BIN_H - ideal * per_marble))
	if landed > 0:
		draw_polyline(pts, Color(0.55, 0.88, 0.92, 0.8), 2.0, true)
	# counts under each bin
	var font := ThemeDB.fallback_font
	for j in ROWS + 1:
		draw_string(font, Vector2(_bin_x(j) - 8, top + BIN_H + 14), str(bins[j]), HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color(1.0, 0.82, 0.4))


func _choose(n: int, k: int) -> float:
	var r := 1.0
	for i in k:
		r = r * (n - i) / (i + 1)
	return r


## Where this looks at ore (world rects), for the track net: a chute
## running through here drops its riders to physics ore over this stretch
## (scripts/track/track_net.gd, zones), so it sees and moves them as before.
func ore_watch() -> Array:
	var w := (ROWS * 0.5 + 1.0) * PITCH
	return [Rect2(global_position.x - w, global_position.y - 24.0, w * 2.0, _bins_top() + BIN_H + 24.0)]
