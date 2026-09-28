extends Node2D
## Pair gate: the marble machine's AND. Two cups, left and right, each
## holding what drops into it; only when both have something does it let
## one from each go together, out of the spout between them. Matches two
## streams one for one (a copper with each iron, for a recipe that needs
## both) and makes either wait for the other. Shows what each side holds.

const SFX = preload("res://scripts/sfx.gd")
const CUP_X := 22.0

var pairs := 0                   # tests
var _held: Array = [[], []]
var _cool := {}
var _flash := 0.0


func _cup(k: int) -> Vector2:
	return Vector2(-CUP_X if k == 0 else CUP_X, 0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		for k in 2:
			if o in _held[k]:
				continue
			var p: Vector2 = o.global_position - (global_position + _cup(k))
			if absf(p.x) < 11 and p.y > -16 and p.y < 4:
				_held[k].append(o)
				o.gravity_scale = 0.0
	# both sides stocked: one of each goes
	for k in 2:
		_held[k] = _held[k].filter(func(b): return is_instance_valid(b))
	if not _held[0].is_empty() and not _held[1].is_empty():
		for k in 2:
			var b: RigidBody2D = _held[k].pop_front()
			b.gravity_scale = 1.0
			b.global_position = global_position + Vector2(-4 if k == 0 else 4, 14)
			b.linear_velocity = Vector2(0, 80)
			_cool[b.get_instance_id()] = now + 1.0
		pairs += 1
		_flash = 1.0
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 1.1)
	# hold the rest stacked in their cups
	for k in 2:
		var i := 0
		for b in _held[k]:
			var at := global_position + _cup(k) + Vector2(0, -6 - i * 12)
			b.linear_velocity = (at - b.global_position) / delta
			if "_timer" in b:
				b._timer = 0.0
			i += 1
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	for k in 2:
		var c := _cup(k)
		draw_line(c + Vector2(-10, -16), c + Vector2(-8, 2), dark, 3.0)
		draw_line(c + Vector2(8, 2), c + Vector2(10, -16), dark, 3.0)
		draw_line(c + Vector2(-8, 2), c + Vector2(8, 2), dark, 3.0)
		draw_line(c + Vector2(-8, 1), c + Vector2(8, 1), brass, 1.0)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-4, 14), str(_held[k].size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.8, 0.55))
	# the joint spout and an ampersand plate
	draw_line(Vector2(-12, 4), Vector2(-5, 14), dark, 3.0)
	draw_line(Vector2(12, 4), Vector2(5, 14), dark, 3.0)
	draw_circle(Vector2(0, -6), 6.0, dark)
	draw_circle(Vector2(0, -6), 4.5, brass)
	draw_string(ThemeDB.fallback_font, Vector2(-3, -2), "&", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dark)
