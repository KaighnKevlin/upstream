extends "res://scenes/chute.gd"
## Booster rail: a chute with driven rollers in it that push whatever rolls
## onto it along the rail, from where it was placed toward its end, at a
## set speed: uphill too, so a run can climb, or a slow stream be sped up
## to make a jump or a loop. Runs slowly on its own and at full speed when
## a gravity wheel or steam engine is in reach. No stop-lip: it drives
## through both ends.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const SPEED := 420.0             # px/s along the rail at full power
const RAIL_TEX := preload("res://assets/sprites/booster_rail.png")
const ROLLER_TEX := preload("res://assets/sprites/booster_roller.png")
const CAP_TEX := preload("res://assets/sprites/booster_cap.png")

var boosted := 0                 # tests
var _grip: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _phase := 0.0
var _seen := {}
var _art: Node2D                 # the roller channel, pixel art tiled along the rail


func _ready() -> void:
	has_lip = false
	# art first, so ghosts and build-bar icons have it; behind our own _draw
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	super._ready()
	if not has_meta("ghost"):
		add_to_group("power_users")


func _rebuilt() -> void:
	if _grip:
		_grip.queue_free()
	_grip = Area2D.new()
	_grip.collision_layer = 0
	_grip.collision_mask = 2
	var a := Vector2.ZERO
	var b := end_offset
	var t := (b - a).normalized()
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2((b - a).length(), 14)
	cs.shape = r
	cs.position = (a + b) * 0.5 + up * 6.0
	cs.rotation = (b - a).angle()
	_grip.add_child(cs)
	add_child(_grip)


func _physics_process(delta: float) -> void:
	if _grip == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_phase += delta * _rate * 12.0
	var dir := end_offset.normalized()
	var want := SPEED * _rate
	for o in _grip.get_overlapping_bodies():
		if not (o is RigidBody2D) or o.freeze:
			continue
		var along: float = o.linear_velocity.dot(dir)
		if along < want:
			# the rollers take it up to speed quickly, keeping it on the rail
			o.linear_velocity += dir * minf(want - along, 1400.0 * delta)
		if not _seen.has(o.get_instance_id()):
			_seen[o.get_instance_id()] = true
			boosted += 1
			SFX.play_small(self, SFX.sfx_hiss(), -18.0, 1.4)
	queue_redraw()


## The chute's own look is replaced by the art; the drive chevron and the selection
## handle are drawn over it.
func _draw() -> void:
	if _art:
		_art.queue_redraw()
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	var t := (b - a) / l
	_draw_surface(a, b, t, Vector2(t.y, -t.x), l)
	_draw_selected()


## The channel (a tiled strip, row 3 on the rail line), the rollers turning
## along it the way they drive (dimmer when unpowered) and the end caps.
func _draw_art() -> void:
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	var ang := (b - a).angle()
	_art.draw_set_transform(a, ang)
	_art.draw_texture_rect(RAIL_TEX, Rect2(0, -3, l, 12), true)
	var dir := 1.0 if end_offset.dot(b - a) > 0 else -1.0
	var k := fmod(_phase * dir, 10.0)
	if k < 0:
		k += 10.0
	var tint := Color.WHITE.lerp(Color(0.55, 0.55, 0.6), 1.0 - _rate)
	while k < l:
		_art.draw_set_transform(a + (b - a) / l * k + Vector2((b - a).y, -(b - a).x) / l * 1.5, ang + _phase * dir / 2.5)
		_art.draw_texture(ROLLER_TEX, Vector2(-3, -3), tint)
		k += 10.0
	_art.draw_set_transform(a, ang)
	_art.draw_texture(CAP_TEX, Vector2(-3, -4))
	_art.draw_texture(CAP_TEX, Vector2(l - 3, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_surface(a: Vector2, b: Vector2, t: Vector2, n: Vector2, _l: float) -> void:
	# a chevron showing which way it drives
	var dir := 1.0 if end_offset.dot(b - a) > 0 else -1.0
	var mid := (a + b) * 0.5 + n * 7.0
	var f := t * dir * 4.0
	draw_line(mid - f + n * 3, mid + f, Color(1.0, 0.8, 0.4, 0.7), 1.5)
	draw_line(mid - f - n * 3, mid + f, Color(1.0, 0.8, 0.4, 0.7), 1.5)
