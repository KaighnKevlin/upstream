extends Node2D
## Grindstone: a millstone turning over a stone bed, set in line with the
## track. Ore that rolls into the bed goes under the stone and comes out
## of the `side` end as grit, three light chips a piece (like the crusher,
## but it sits on a run instead of the floor, and chews no walkers).
## It holds a few pieces waiting; when those are full, the rest runs
## through raw. Anything it can't grind (grit, ingots, shells) is pushed
## on out of the same end. Slow on its own, full speed with a gravity
## wheel or steam engine in reach. Iron takes longer than copper.
## Put its node where the run's low end drops in; click the stone to
## turn it round.

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ORE := preload("res://scenes/ore.tscn")

const ORE_ONLY := 64
const GRIND := {"copper": 0.5, "iron": 0.9, "gear": 0.7, "shot": 0.6, "spring": 0.6, "scrap": 0.7}
const GRIT_PER := 3
const HOLD := 4
const BED := 20.0            # half-width of the bed
const STONE := Vector2(0, -13)
const STONE_R := 10.0
const EJECT := Vector2(90, -15)    # a low toss: small grit dropped far can slip through a rail

## Which end the grit leaves by: 1 right, -1 left.
@export var side := 1.0

var ground := 0              # pieces ground (tests)
var grit_out := 0            # grit made (tests)
var passed := 0              # things pushed on through unground (tests)
var _queue := []             # kinds waiting under the stone
var _work := 0.0
var _turn := 0.0
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _pushed := {}
var _stone: Sprite2D         # pre-turned frames (its dressing repeats every quarter turn)


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw, which keeps the out-end chevron, pips and progress on top
	var bed := Sprite2D.new()
	bed.texture = preload("res://assets/sprites/grindstone_bed.png")
	bed.centered = false
	bed.offset = Vector2(-24, -27)
	bed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bed.show_behind_parent = true
	add_child(bed)
	_stone = Sprite2D.new()
	_stone.texture = preload("res://assets/sprites/grindstone_stone.png")
	_stone.hframes = 6
	_stone.position = STONE
	_stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stone.show_behind_parent = true
	add_child(_stone)
	queue_redraw()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	# the bed: an ore-only floor, what waits sits on it
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-BED, 0)
	seg.b = Vector2(BED, 0)
	cs.shape = seg
	body.add_child(cs)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(BED * 2 - 4, 16)
	ic.shape = r
	ic.position = Vector2(0, -8)
	_intake.add_child(ic)
	add_child(_intake)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var speed := _rate * Tech.mult("assembly")
	_turn += delta * speed * 6.0
	# take in what's in the bed, push on what it can't use
	for b in _intake.get_overlapping_bodies():
		if not (b is RigidBody2D) or b.is_queued_for_deletion() or b.freeze or b.has_meta("caught_by"):
			continue
		var k = b.get("kind")
		if b.is_in_group("ore") and GRIND.has(k) and _queue.size() < HOLD:
			_queue.append(k)
			b.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 0.6)
		else:
			# no room or not grindable: out the far end
			var rb := b as RigidBody2D
			if rb.linear_velocity.x * side < 80.0:
				rb.linear_velocity.x = side * 90.0
			var id: int = b.get_instance_id()
			if not _pushed.has(id):
				_pushed[id] = true
				passed += 1
	if not _queue.is_empty():
		_work += delta * speed
		if _work >= GRIND.get(_queue[0], 0.6):
			_work = 0.0
			_spit(_queue.pop_front())
	queue_redraw()


func _spit(k: String) -> void:
	ground += 1
	var at := global_position + Vector2(side * (BED + 4), -4)
	for n in GRIT_PER:
		var g: RigidBody2D = ORE.instantiate()
		g.kind = "grit"
		g.global_position = at + Vector2(side * n * 3.0, randf_range(-1.5, 1.5))
		get_tree().current_scene.add_child(g)
		g.linear_velocity = Vector2(EJECT.x * side, EJECT.y) + Vector2(randf_range(-15, 15), randf_range(-10, 10))
		grit_out += 1
	FX.burst(get_parent(), at, Color(0.62, 0.55, 0.5, 0.8), 5, 45.0, 0.4, 1.6)
	SFX.play_small(self, SFX.sfx_grind(), -12.0, 1.2 if k == "copper" else 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + STONE) < STONE_R + 2:
		side = -side
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the trough, A-frame and millstone are sprites (see _ready); the stone
	# shows the frame for how far it has turned
	_stone.frame = int(fposmod(_turn * side, PI / 2.0) / (PI / 2.0) * 6.0) % 6
	# which way it sends: a small chevron at the out end
	var o := Vector2(side * (BED - 3), -4)
	draw_line(o + Vector2(-side * 3, -3), o, brass, 1.0)
	draw_line(o + Vector2(-side * 3, 3), o, brass, 1.0)
	if _intake == null:
		return
	# held pieces as pips over the stone, and the grind's progress arc
	for i in HOLD:
		var p := STONE + Vector2(-7.5 + i * 5, -STONE_R - 5)
		draw_circle(p, 2.0, dark)
		if i < _queue.size():
			draw_circle(p, 1.4, Color(0.62, 0.64, 0.7) if _queue[i] == "iron" else Color(0.85, 0.5, 0.3))
	if not _queue.is_empty():
		var f := clampf(_work / GRIND.get(_queue[0], 0.6), 0.0, 1.0)
		draw_arc(STONE, STONE_R + 2.5, -PI / 2, -PI / 2 + TAU * f, 16, Color(0.95, 0.8, 0.45), 1.5)
