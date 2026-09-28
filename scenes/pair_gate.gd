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
var _plate: Sprite2D             # the medallion, brightening as a pair goes


func _ready() -> void:
	# sprites (for ghosts and build-bar icons too), behind our own _draw
	# (the counts and the ampersand)
	var bd := Sprite2D.new()
	bd.texture = preload("res://assets/sprites/pair_gate.png")
	bd.centered = false
	bd.offset = Vector2(-34, -20)
	bd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bd.show_behind_parent = true
	add_child(bd)
	_plate = Sprite2D.new()
	_plate.texture = preload("res://assets/sprites/pair_gate_plate.png")   # centred on it
	_plate.position = Vector2(0, -6)
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.show_behind_parent = true
	add_child(_plate)


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
	# cups, spout and medallion are sprites (see _ready)
	_plate.self_modulate = Color.WHITE.lerp(Color(1.45, 1.35, 1.1), _flash)
	var dark := Color(0.1, 0.08, 0.07)
	for k in 2:
		var c := _cup(k)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-4, 14), str(_held[k].size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.8, 0.55))
	draw_string(ThemeDB.fallback_font, Vector2(-3, -2), "&", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dark)
