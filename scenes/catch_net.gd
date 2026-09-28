extends Node2D
## Catch net: a wide net slung between two posts, sagging to a ring at its
## middle. Ore flying into it (a trampoline's or catapult's shot, a wild
## ricochet) has its bounce soaked up, rolls down the sag and drops
## straight out of the ring: a loose arc turned into one exact point
## below. Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const HALF := 44.0
const SAG := 14.0
const HOLE := 9.0                # half-width of the ring: a marble (6.5) drops through
const POST_TEX := preload("res://assets/sprites/catch_net_post.png")
const RING_TEX := preload("res://assets/sprites/catch_net_ring.png")

var caught := 0                  # tests: dropped out through the ring
var _throat: Area2D
var _wobble := 0.0
var _t := 0.0
var _art: Node2D                 # posts, hoop and cords (pixel art, nearest)


func _ready() -> void:
	z_index = 1
	_art = Node2D.new()          # before the ghost return: ghosts and icons draw too
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true           # the net gives: no bounce off it
	m.bounce = 1.0
	m.friction = 0.6
	body.physics_material_override = m
	for s in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = Vector2(s * HALF, 0)
		seg.b = Vector2(s * HOLE, SAG)
		cs.shape = seg
		body.add_child(cs)
		# a rim at each post so a flat shot doesn't skim straight over
		var rim := CollisionShape2D.new()
		var rs := SegmentShape2D.new()
		rs.a = Vector2(s * HALF, 0)
		rs.b = Vector2(s * (HALF + 3), -26)
		rim.shape = rs
		body.add_child(rim)
	add_child(body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2, 18)
	ac.shape = r
	ac.position = Vector2(0, 2)
	a.add_child(ac)
	add_child(a)
	a.body_entered.connect(_catch)
	# the ring's throat: whatever drops through leaves straight down, not drifting
	_throat = Area2D.new()
	_throat.collision_layer = 0
	_throat.collision_mask = 2
	var tc := CollisionShape2D.new()
	var tr := RectangleShape2D.new()
	tr.size = Vector2(HOLE * 2 + 4, 10)
	tc.shape = tr
	tc.position = Vector2(0, SAG + 4)
	_throat.add_child(tc)
	add_child(_throat)


func _physics_process(_delta: float) -> void:
	if _throat == null:
		return
	for b in _throat.get_overlapping_bodies():
		if b is RigidBody2D:
			if b.get_meta("netted_by", 0) != get_instance_id():
				b.set_meta("netted_by", get_instance_id())
				caught += 1              # counted as it leaves through the ring
			var dx: float = global_position.x - b.global_position.x
			b.linear_velocity = Vector2(dx * 8.0, maxf(b.linear_velocity.y, 60.0))


func _catch(b) -> void:
	if not (b is RigidBody2D):
		return
	_wobble = 1.0
	SFX.play_small(self, SFX.sfx_ore_knock("wood"), -20.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if _wobble > 0:
		_wobble = maxf(0.0, _wobble - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	if _art:
		_art.queue_redraw()


## Posts (sprites), a diamond mesh between the net's front and back cords
## sagging to the hoop (sprite), the front cord last.
func _draw_art() -> void:
	var dark := Color(0.16, 0.13, 0.1)
	var cord := Color(0.78, 0.7, 0.52)
	var sag := SAG + sin(_t * 18.0) * 4.0 * _wobble
	for s in [-1.0, 1.0]:
		_art.draw_set_transform(Vector2(s * HALF, 0), 0.0, Vector2(-s, 1))
		_art.draw_texture(POST_TEX, Vector2(-6, -29))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rows := 6
	for s in [-1.0, 1.0]:
		var f0 := Vector2(s * HALF, 0)
		var f1 := Vector2(s * HOLE, sag)
		var b0 := Vector2(s * HALF, -8)
		var b1 := Vector2(s * HOLE, sag - 4)
		_art.draw_line(b0, b1, Color(cord, 0.55), 1.0)
		for i in rows:
			var a := float(i) / rows
			var b := float(i + 1) / rows
			_art.draw_line(f0.lerp(f1, a), b0.lerp(b1, b), Color(cord, 0.75), 1.0)
			_art.draw_line(b0.lerp(b1, a), f0.lerp(f1, b), Color(cord, 0.75), 1.0)
	_art.draw_texture(RING_TEX, Vector2(-12, sag - 2 - 6))
	for s in [-1.0, 1.0]:
		_art.draw_line(Vector2(s * HALF, 0), Vector2(s * HOLE, sag), dark, 3.0)
		_art.draw_line(Vector2(s * HALF, 0), Vector2(s * HOLE, sag), cord, 1.5)
