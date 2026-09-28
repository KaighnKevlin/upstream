extends Node2D
## Pachinko board, for the Pachinko example world: a launch lane up the
## right, an angled plate at the top that turns a marble fired up the lane
## out over a field of pegs, and five scoring pockets along the floor. A
## marble in a pocket scores, then goes back to the plunger's magazine.
## Built in world coordinates (place it at the origin).

const ORE_ONLY := 64
const LANE_X := 1570.0
const LANE_TOP := 300.0      # low enough for a marble off the plate to clear it
const PLATE := [Vector2(1644, 212), Vector2(1510, 160)]
const FIELD := Rect2(1000, 250, 540, 230)
const PEG_R := 4.0
const POCKETS_X := [940.0, 1064.0, 1188.0, 1312.0, 1436.0, 1560.0]
const POCKET_TOP := 528.0
const FLOOR := 576.0
const VALUES := [10, 50, 200, 50, 10]

var score := 0
var hits: Array[int] = [0, 0, 0, 0, 0]
var plunger: Node2D
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]


func _pegs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var row := 0
	var y := FIELD.position.y
	while y <= FIELD.end.y:
		var x := FIELD.position.x + (22.0 if row % 2 == 1 else 0.0)
		while x <= FIELD.end.x:
			out.append(Vector2(x, y))
			x += 44.0
		y += 34.0
		row += 1
	return out


func _ready() -> void:
	z_index = 1
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.bounce = 0.45
	m.friction = 0.2
	body.physics_material_override = m
	add_child(body)
	for p in _pegs():
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = PEG_R
		cs.shape = c
		cs.position = p
		body.add_child(cs)
	_seg(body, Vector2(LANE_X, LANE_TOP), Vector2(LANE_X, FLOOR))     # the lane's wall
	_seg(body, PLATE[0], PLATE[1])                                # the top plate
	for x in POCKETS_X:
		_seg(body, Vector2(x, POCKET_TOP), Vector2(x, FLOOR))
	for i in VALUES.size():
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(POCKETS_X[i + 1] - POCKETS_X[i] - 6, 20)
		cs.shape = r
		cs.position = Vector2((POCKETS_X[i] + POCKETS_X[i + 1]) * 0.5, FLOOR - 12)
		a.add_child(cs)
		add_child(a)
		a.body_entered.connect(_pocket.bind(i))


func _seg(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	body.add_child(cs)


func _pocket(b, i: int) -> void:
	if not (b is RigidBody2D) or b.has_meta("scored"):
		return
	b.set_meta("scored", true)
	score += VALUES[i]
	hits[i] += 1
	_flash[i] = 1.0
	preload("res://scripts/sfx.gd").play_small(self, preload("res://scripts/sfx.gd").sfx_chime(523.25 * (1.0 + i * 0.25)), -8.0, 1.0)
	# back to the magazine
	if plunger:
		plunger.ammo += 1
	b.get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(b): b.queue_free())
	queue_redraw()


func _process(delta: float) -> void:
	for i in _flash.size():
		if _flash[i] > 0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 2.0)
			queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	for p in _pegs():
		draw_circle(p, PEG_R + 1, dark)
		draw_circle(p, PEG_R, Color(0.75, 0.77, 0.82))
	draw_line(Vector2(LANE_X, LANE_TOP), Vector2(LANE_X, FLOOR), dark, 4.0)
	draw_line(Vector2(LANE_X, LANE_TOP), Vector2(LANE_X, FLOOR), brass, 2.0)
	draw_line(PLATE[0], PLATE[1], dark, 5.0)
	draw_line(PLATE[0], PLATE[1], brass, 3.0)
	var font := ThemeDB.fallback_font
	for i in VALUES.size():
		var x0: float = POCKETS_X[i]
		var x1: float = POCKETS_X[i + 1]
		var glow := Color(1.0, 0.85, 0.4, 0.12 + _flash[i] * 0.5)
		draw_rect(Rect2(x0, POCKET_TOP, x1 - x0, FLOOR - POCKET_TOP), glow)
		draw_string(font, Vector2(x0, POCKET_TOP - 6), str(VALUES[i]), HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 12,
			Color(1.0, 0.82, 0.4) if VALUES[i] >= 200 else Color(0.85, 0.75, 0.55))
	for x in POCKETS_X:
		draw_line(Vector2(x, POCKET_TOP), Vector2(x, FLOOR), dark, 3.0)
		draw_line(Vector2(x, POCKET_TOP), Vector2(x, FLOOR), Color(0.6, 0.62, 0.66), 1.0)
	# the score, big, top left of the field
	draw_rect(Rect2(952, 172, 150, 44), Color(0.08, 0.06, 0.05, 0.85))
	draw_rect(Rect2(952, 172, 150, 44), brass, false, 1.5)
	draw_string(font, Vector2(962, 202), "%06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.82, 0.4))
