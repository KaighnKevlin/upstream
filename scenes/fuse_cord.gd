extends Node2D
## Fuse cord: a length of tarred safety fuse lying in a gentle sag between
## a tin lighting cap (its start) and a brass detonator cap (its end); drag
## it out like a chute. Light it (a signal: it's triggerable; a click on
## the start cap; or a lit piece, an igniter's or a bomb, touching the
## cord) and a spark crawls along it at SPEED px/s, burning it to ash, and
## when it reaches the detonator it fires what's at its end, like a speed
## trap's wire. So the delay is the length you lay: a visible delay line
## (the label reads its burn time). Chain cords end to start to bend it
## round a corner or zig-zag it along a wall: a cord's end lights only
## the cords whose start cap it touches (CAP_REACH), not every cord in a
## wire's reach, so a folded line still burns in order. A burning or burnt
## cord ignores further lights; it re-knits, fresh, REKNIT s after it burns
## out.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const LEN_MIN := 30.0
const LEN_MAX := 400.0
const SPEED := 40.0              # px/s of burn: 120 px = a 3 s delay
const REKNIT := 3.0
const CAP_REACH := 16.0          # a cord's end lights a cord whose start is this close
const CAP_CLICK := 7.0
const TOUCH := 4.0               # a lit piece this close (plus its radius) lights it
const SEGS := 6.0                # px per drawn segment of the sag
const CORD_TEX := preload("res://assets/sprites/fuse_cord.png")
const ASH_TEX := preload("res://assets/sprites/fuse_cord_ash.png")
const START_TEX := preload("res://assets/sprites/fuse_cap_start.png")
const END_TEX := preload("res://assets/sprites/fuse_cap_end.png")

@export var end_offset := Vector2(120, 0)

var lit := 0                     # tests: times lit
var fired := 0                   # tests: times it reached its end
var ignored := 0                 # tests: lights refused while burning / ash
var age := 0.0                   # tests: game time, for lit_at / fired_at
var lit_at := -1.0
var fired_at := -1.0
var burning := false
var _s := 0.0                    # how far the spark has crawled (along the chord)
var _ash := 0.0                  # > 0: burnt out, re-knitting
var _crackle := 0.0
var _flash := 0.0
var _art: Node2D                 # the cord (fresh and ash) and its two caps


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()
	if _art:
		_art.queue_redraw()


func _ready() -> void:
	z_index = 2
	# the art first, so ghosts and build-bar icons have it; behind our own
	# _draw (the spark, the delay label)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


## The sag: how far the middle hangs below the chord.
func _sag() -> float:
	return clampf(end_offset.length() * 0.07, 2.0, 14.0)


## A point on the cord, t 0 (start cap) .. 1 (detonator).
func _pt(t: float) -> Vector2:
	return end_offset * t + Vector2(0, _sag() * 4.0 * t * (1.0 - t))


func _points() -> PackedVector2Array:
	var n := maxi(4, int(end_offset.length() / SEGS))
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(_pt(float(i) / n))
	return pts


func trigger() -> void:
	if has_meta("ghost"):
		return
	light()


func light() -> void:
	if burning or _ash > 0:
		ignored += 1
		return
	burning = true
	_s = 0.0
	lit += 1
	lit_at = age
	_crackle = 0.0
	SFX.play_small(self, SFX.sfx_hiss(), -14.0, 2.2)
	FX.burst(get_parent(), global_position, Color(1.0, 0.85, 0.4), 6, 60.0, 0.25, 1.0, -30.0)
	queue_redraw()


func fire() -> void:
	fired += 1
	fired_at = age
	_flash = 1.0
	var at := global_position + end_offset
	FX.burst(get_parent(), at, Color(1.0, 0.9, 0.5), 10, 110.0, 0.25, 1.5)
	FX.burst(get_parent(), at, Color(0.3, 0.28, 0.3, 0.6), 4, 30.0, 0.9, 3.0, -40.0)
	SFX.play_small(self, SFX.sfx_latch(), -10.0, 1.6)
	for n in Tripwire.linked_to(get_tree(), [at]):
		if n == self or not n.has_method("trigger"):
			continue
		# another fuse cord only if its start cap is on our detonator
		if n.get_script() == get_script() and n.global_position.distance_to(at) > CAP_REACH:
			continue
		n.trigger()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	age += delta
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()
	if burning:
		var l := end_offset.length()
		_s += SPEED * delta
		var at := global_position + _pt(minf(1.0, _s / l))
		if randf() < 0.6:
			FX.burst(get_parent(), at, Color(1.0, 0.8, 0.35), 1, 50.0, 0.2, 1.0, 60.0)
		if randf() < 0.12:
			FX.burst(get_parent(), at, Color(0.35, 0.32, 0.32, 0.5), 1, 12.0, 0.8, 2.5, -30.0)
		_crackle -= delta
		if _crackle <= 0:
			_crackle = randf_range(0.08, 0.2)
			SFX.play_small(self, SFX.sfx_ratchet(), -20.0, randf_range(2.2, 3.0))
		if _s >= l:
			burning = false
			_ash = REKNIT
			fire()
		queue_redraw()
		_art.queue_redraw()
		return
	if _ash > 0:
		_ash -= delta
		if _ash <= 0:
			_ash = 0.0
			SFX.play_small(self, SFX.sfx_clink(), -18.0, 2.0)
			_art.queue_redraw()
		return
	_touch()


## A lit piece (an igniter's, meta "lit") or a bomb touching the cord.
func _touch() -> void:
	var pts := _points()
	var lo := Vector2(minf(0.0, end_offset.x), minf(0.0, end_offset.y)) - Vector2(16, 16)
	var box := Rect2(global_position + lo, end_offset.abs() + Vector2(32, 32 + _sag()))
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or not (o.has_meta("lit") or o.get("kind") == "bomb"):
			continue
		var p: Vector2 = o.global_position
		if not box.has_point(p):
			continue
		var r: float = o.KINDS.get(o.kind, {}).get("radius", 5.0)
		var local := p - global_position
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(local, pts[i], pts[i + 1])
			if q.distance_to(local) < r + TOUCH:
				light()
				return


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < CAP_CLICK:
		light()
		get_viewport().set_input_as_handled()


## The cord tiled along its sag, segment by segment (ash behind the spark,
## tar ahead of it; flipped on leftward runs so the lit side stays up),
## then the caps at each end turned to the cord's tangent.
func _draw_art() -> void:
	var l := end_offset.length()
	if l < 1.0:
		return
	var pts := _points()
	var flip := 1.0 if end_offset.x >= 0 else -1.0
	var burnt := 1.0 if _ash > 0 else (_s / l if burning else 0.0)
	var n := pts.size() - 1
	var along := 0.0
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var sl := d.length()
		var tex := ASH_TEX if (float(i) + 0.5) / n < burnt else CORD_TEX
		_art.draw_set_transform(a, d.angle(), Vector2(1, flip))
		_art.draw_texture_rect_region(tex, Rect2(0, -2, sl + 0.5, 4), Rect2(fmod(along, 12.0), 0, sl + 0.5, 4))
		along += sl
	var d0 := pts[1] - pts[0]
	_art.draw_set_transform(pts[0], d0.angle(), Vector2(1, flip))
	_art.draw_texture(START_TEX, Vector2(-6, -4))
	var d1 := pts[n] - pts[n - 1]
	_art.draw_set_transform(pts[n], d1.angle(), Vector2(1, flip))
	_art.draw_texture(END_TEX, Vector2(-2, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var l := end_offset.length()
	if l < 1.0:
		return
	if burning:
		var at := _pt(minf(1.0, _s / l))
		var fl := 0.7 + 0.3 * sin(age * 40.0)
		draw_circle(at, 4.0 * fl, Color(1.0, 0.55, 0.15, 0.35))
		draw_circle(at, 1.8, Color(1.0, 0.9, 0.55))
	if _flash > 0:
		draw_circle(end_offset, 6.0 * _flash, Color(1.0, 0.85, 0.4, 0.6 * _flash))
	if has_meta("icon"):
		return
	# its delay: the burn time left, or the whole length's
	var font := ThemeDB.fallback_font
	var label := "%.1fs" % ((l - _s) / SPEED) if burning else "%.1fs" % (l / SPEED)
	draw_string(font, Vector2(-8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55) if _ash <= 0 else Color(0.6, 0.56, 0.5))
