extends Node2D
## Magnet rail: an overhead bar wound with coils (drag it, like a chute).
## Iron that comes up under it (thrown, bounced, or rolling on a track just
## beneath) jumps up and clings to its underside, then slides along it,
## faster downhill, and drops off the far end. Copper takes no notice and
## falls or rolls straight on. Sorts and carries at once: iron over a gap,
## round a corner, onto a higher line; copper stays below.
## Ore-only: walkers aren't touched.

const SFX = preload("res://scripts/sfx.gd")
const LEN_MIN := 60.0
const LEN_MAX := 400.0
const PULL := 26.0               # reaches this far below the bar
const MAGNETIC := ["iron", "shot", "gear", "scrap"]
const V_MIN := 90.0
const V_MAX := 420.0
const BAR_TEX := preload("res://assets/sprites/magrail_bar.png")
const CAP_TEX := preload("res://assets/sprites/magrail_cap.png")
const HANGER_TEX := preload("res://assets/sprites/magrail_hanger.png")

@export var end_offset := Vector2(160, 20)

var carried := 0                 # tests
var _held: Array = []            # [ore, s along the bar, speed]
var _g := 980.0
var _art: Node2D                 # the bar, coils, caps and hangers (tiled along the bar)


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()
	if _art:
		_art.queue_redraw()


func _ready() -> void:
	z_index = 2
	# the art first, so ghosts and build-bar icons have it; behind our own
	# _draw (the field)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	_g = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


## Under the bar: the normal pointing down (screen-down side of it).
func _down(dir: Vector2) -> Vector2:
	var n := Vector2(-dir.y, dir.x)
	return n if n.y >= 0 else -n


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var l := end_offset.length()
	var dir := end_offset / l
	var n := _down(dir)
	var now := Time.get_ticks_msec() / 1000.0
	var held_ids := {}
	for h in _held:
		held_ids[h[0]] = true
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or held_ids.has(o) or not (o.kind in MAGNETIC):
			continue
		if o.get_meta("mag_until", 0.0) > now or o.has_meta("store_material"):
			continue
		var p: Vector2 = o.global_position - global_position
		var s := p.dot(dir)
		var d := p.dot(n)
		if s > 4 and s < l - 12 and d > -2 and d < PULL:
			o.gravity_scale = 0.0
			_held.append([o, s, clampf(o.linear_velocity.dot(dir), V_MIN, V_MAX)])
			SFX.play_small(self, SFX.sfx_clink(), -14.0, 1.6)
	var keep: Array = []
	for h in _held:
		var o = h[0]
		if not is_instance_valid(o):
			continue
		var r: float = o.KINDS[o.kind].radius
		h[2] = clampf(h[2] + _g * dir.y * delta * 0.6, V_MIN, V_MAX)
		h[1] += h[2] * delta
		if h[1] >= l:
			o.gravity_scale = 1.0
			o.linear_velocity = dir * h[2]
			o.set_meta("mag_until", now + 0.8)
			carried += 1
			continue
		var at: Vector2 = global_position + dir * h[1] + n * (r + 3.0)
		o.linear_velocity = (at - o.global_position) / delta
		o.angular_velocity = h[2] / r
		if "_timer" in o:
			o._timer = 0.0
		keep.append(h)
	_held = keep
	queue_redraw()


## The hangers up to the ceiling, then the bar tiled along its length (a
## coil every 24 px; flipped on leftward runs so the field side stays down),
## capped at each end.
func _draw_art() -> void:
	var l := end_offset.length()
	if l < 1.0:
		return
	var dir := end_offset / l
	for p in [Vector2.ZERO, end_offset]:
		_art.draw_texture(HANGER_TEX, p - Vector2(4, 18))
	_art.draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(1, 1.0 if dir.x >= 0 else -1.0))
	_art.draw_texture_rect(BAR_TEX, Rect2(0, -6, l, 12), true)
	_art.draw_texture(CAP_TEX, Vector2(-4, -6))
	_art.draw_texture(CAP_TEX, Vector2(l - 4, -6))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var l := end_offset.length()
	if l < 1.0:
		return
	var dir := end_offset / l
	var n := _down(dir)
	# the field it reaches with, faintly (the bar itself is in the art child)
	var pulse := 0.08 + 0.04 * sin(Time.get_ticks_msec() / 200.0)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, end_offset, end_offset + n * PULL, n * PULL]), Color(0.5, 0.7, 1.0, pulse))
