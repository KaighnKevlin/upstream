extends Node2D
## The Beam: the magic Upstream, the one true power source. A column of
## rising blue light from `depth` px below its crown. Anything loose that
## enters it (ore, ingots, scrap) is drawn to the middle and carried up at
## RISE px/s, weightless; at the crown it's flung out over the lip, to the
## left or right (`spill`: -1 / 1 / 0 = alternate), to fall through
## whatever marble machine is built below. Every metre of drop it gives is
## energy the machine can spend on wheels. Beam taps (scenes/beam_tap.gd)
## fitted along it pull out matching pieces on the way up.
## The node sits at the crown; the column runs down `depth` px.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const RISE := 150.0
const WIDTH := 26.0
const PULL := 6.0                # how hard it centres things (1/s)
const COOL := 0.9                # s a flung piece ignores the beam

@export var depth := 400.0
@export var spill := 0
## The beam's budget: pieces it takes in per second (0: no limit, the demo
## worlds). Lift is free, so without a cap a loop up the beam and down
## through a gravity wheel is free power; with one, every slot spent
## circulating power is a slot not lifting ore. Faster current (tech
## "lifts") raises it. Pieces that reach a full beam wait at its foot.
@export var per_second := 0.0

var carried := 0                 # tests: pieces flung from the crown
var _area: Area2D
var _next_side := 1.0
var _t := 0.0
var _intake := 0.0               # s until the next piece may come in
var _rate := 0.0
var usage := 0.0                 # recent intake / budget, 0..1 (the gauge)
var waiting := 0                 # pieces at the foot waiting their turn


func _ready() -> void:
	z_index = 0
	add_to_group("beams")
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(WIDTH, depth)
	cs.shape = r
	cs.position = Vector2(0, depth * 0.5)
	_area.add_child(cs)
	add_child(_area)
	_area.body_exited.connect(_on_exit)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var k := 0.0
	while k < depth:
		var l := PointLight2D.new()
		l.texture = LightTextures.create_radial_light(128)
		l.color = Color(0.35, 0.6, 1.0)
		l.energy = 0.55
		l.texture_scale = 1.3
		l.position = Vector2(0, k + 40)
		add_child(l)
		k += 140.0


func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return global_position.y + depth


func _usable(b) -> bool:
	return b is RigidBody2D and not b.freeze and Hold.free_to_take(b, self) and not b.has_meta("store_material") \
		and b.get_meta("beam_cool", 0.0) < Time.get_ticks_msec() * 0.001


func _on_exit(b) -> void:
	if is_instance_valid(b) and b is RigidBody2D and b.has_meta("in_beam"):
		b.remove_meta("in_beam")
		Hold.release(b, self)


## Let a piece go from the beam at `at` with velocity `v` (the crown, taps).
func release(b: RigidBody2D, at: Vector2, v: Vector2) -> void:
	b.remove_meta("in_beam")
	Hold.release(b, self)
	b.set_meta("beam_cool", Time.get_ticks_msec() * 0.001 + COOL)
	b.global_position = at
	b.linear_velocity = v
	b.sleeping = false


func budget() -> float:
	return per_second * preload("res://scripts/tech.gd").mult("lifts")


func _physics_process(delta: float) -> void:
	_t += delta
	_intake -= delta
	var cap := budget()
	var admitted := 0
	waiting = 0
	for b in _area.get_overlapping_bodies():
		if not _usable(b):
			continue
		var o := b as RigidBody2D
		if not o.has_meta("in_beam"):
			if cap > 0.0 and _intake > 0.0:
				# full: it waits its turn at the foot, still in play
				waiting += 1
				if "_timer" in o:
					o._timer = 0.0
				if "_rest" in o:
					o._rest = 0.0
				continue
			if cap > 0.0:
				_intake = maxf(_intake, 0.0) + 1.0 / cap
				admitted += 1
			o.set_meta("in_beam", true)
			Hold.claim(o, self)
			o.gravity_scale = 0.0
		var dx := global_position.x - o.global_position.x
		Hold.claim(o, self)
		o.linear_velocity = o.linear_velocity.lerp(Vector2(dx * PULL, -RISE), minf(1.0, 5.0 * delta))
		o.angular_velocity *= 0.9
		if "_timer" in o:
			o._timer = 0.0            # nothing expires in the beam
		# the crown: over the lip
		if o.global_position.y < top_y() + 8.0:
			var side := float(spill)
			if spill == 0:
				side = _next_side
				_next_side = -_next_side
			release(o, Vector2(global_position.x + side * 16.0, top_y() - 4.0), Vector2(side * randf_range(110, 150), -170))
			carried += 1
			SFX.play_small(self, SFX.sfx_bounce(), -14.0, 1.6)
	if cap > 0.0:
		_rate = lerpf(_rate, float(admitted) / delta, minf(1.0, delta * 0.8))   # pieces/s, smoothed
		usage = clampf(_rate / cap, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# the column: a soft glowing core with rising motes and bands
	var h := depth
	draw_rect(Rect2(-WIDTH * 0.5, 0, WIDTH, h), Color(0.15, 0.3, 0.8, 0.10))
	draw_rect(Rect2(-WIDTH * 0.3, 0, WIDTH * 0.6, h), Color(0.3, 0.55, 1.0, 0.12))
	draw_rect(Rect2(-2, 0, 4, h), Color(0.6, 0.85, 1.0, 0.22))
	var y := fmod(_t * RISE, 24.0)
	while y < h:
		var yy := h - y
		draw_line(Vector2(-WIDTH * 0.35, yy), Vector2(0, yy - 5), Color(0.6, 0.85, 1.0, 0.18), 1.0)
		draw_line(Vector2(WIDTH * 0.35, yy), Vector2(0, yy - 5), Color(0.6, 0.85, 1.0, 0.18), 1.0)
		y += 24.0
	for k in 10:
		var my := h - fmod(_t * RISE * (0.8 + 0.05 * k) + k * 53.0, h)
		var mx := sin(_t * 2.0 + k) * WIDTH * 0.3
		draw_rect(Rect2(Vector2(mx, my), Vector2(1, 2)), Color(0.8, 0.95, 1.0, 0.6))
	if per_second > 0.0:
		_draw_gauge()
	# the crown: a bright flare where it spills
	draw_circle(Vector2(0, 0), 10.0 + 2.0 * sin(_t * 4.0), Color(0.5, 0.8, 1.0, 0.18))
	draw_circle(Vector2(0, 0), 4.0, Color(0.85, 0.95, 1.0, 0.5))


## The budget gauge at the foot: a brass bar filling with the beam's recent
## intake, its pieces/s, and how many wait their turn.
func _draw_gauge() -> void:
	var at := Vector2(-20, depth - 10)
	draw_rect(Rect2(at, Vector2(40, 6)), Color(0.12, 0.1, 0.08, 0.9))
	var full := usage > 0.92 or waiting > 0
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(38 * usage, 4)), Color(1.0, 0.6, 0.3) if full else Color(0.85, 0.72, 0.45))
	var font := ThemeDB.fallback_font
	var txt := "%.1f/s" % budget()
	if waiting > 0:
		txt += "  +%d" % waiting
	draw_string(font, at + Vector2(0, -3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.8, 0.65))
