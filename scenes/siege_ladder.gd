extends Node2D
## Siege ladder: soldiers and shieldbearers carry these. The first to reach
## a ditch wall plants one against it and climbs; everyone after it uses the
## same ladder. Ore that hits it hard knocks it over (iron in one blow,
## copper takes two), and anyone on it drops back into the ditch.
## The node's origin is the foot of the ladder; it leans on the wall on the
## `side` it faces. Drawn here in brass and timber (no sprite: it's sized to
## the wall).

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const WIDTH := 7.0
const RUNG_EVERY := 6.0
const RAIL := Color(0.53, 0.38, 0.24)
const RAIL_LIT := Color(0.66, 0.5, 0.32)
const RUNG := Color(0.66, 0.56, 0.4)
const OUTLINE := Color(0.16, 0.15, 0.12)
const BRASS := Color(0.85, 0.72, 0.45)

var height := 48.0
var side := -1.0              # which way the wall is (+1 right, -1 left)
var lean := 5.0               # the foot stands this far out from the wall
var falling := false
var _hits := 0.0
var _grow := 0.0              # unfolds when planted


func _ready() -> void:
	add_to_group("siege_ladders")
	z_index = 1
	var t := create_tween()
	t.tween_property(self, "_grow", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func top_y() -> float:
	return global_position.y - height


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if falling:
		return
	var foot := global_position
	var top := foot + Vector2(side * lean, -height)
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.linear_velocity.length() < 140.0:
			continue
		var p: Vector2 = o.global_position
		if p.y < top.y - 4 or p.y > foot.y + 4:
			continue
		var x_at := lerpf(foot.x, top.x, (foot.y - p.y) / height)
		if absf(p.x - x_at) < WIDTH * 0.5 + 6.0:
			_hits += o.mass
			o.linear_velocity = o.linear_velocity * Vector2(-0.4, 0.5)
			SFX.play_small(self, SFX.sfx_ore_knock("wood"), -6.0, randf_range(0.8, 1.0))
			FX.burst(get_parent(), p, RAIL_LIT, 4, 60.0, 0.3, 1.2)
			if _hits >= 2.0:
				knock_over()
				return


func knock_over() -> void:
	if falling:
		return
	falling = true
	remove_from_group("siege_ladders")
	SFX.play(self, SFX.sfx_clink(), -4.0, 0.6)
	var t := create_tween()
	t.tween_property(self, "rotation", -side * 1.45, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): FX.burst(get_parent(), global_position + Vector2(-side * height * 0.7, -4), RAIL_LIT, 8, 70.0, 0.4, 1.8))
	t.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.tween_callback(queue_free)


func _draw() -> void:
	var h := height * _grow
	var top := Vector2(side * lean * _grow, -h)
	var along := top.normalized()
	var across := Vector2(-along.y, along.x) * WIDTH * 0.5
	# rungs first, rails over them
	var n := int(h / RUNG_EVERY)
	for k in range(1, n + 1):
		var p := along * (k * RUNG_EVERY)
		draw_line(p - across, p + across, OUTLINE, 3.0)
	for k in range(1, n + 1):
		var p := along * (k * RUNG_EVERY)
		draw_line(p - across * 0.8, p + across * 0.8, RUNG, 1.0)
	for s: float in [-1.0, 1.0]:
		var a: Vector2 = across * s
		draw_line(a, top + a + along * 2.0, OUTLINE, 4.0)
	for s: float in [-1.0, 1.0]:
		var a: Vector2 = across * s
		draw_line(a, top + a + along * 2.0, RAIL if s < 0 else RAIL_LIT, 2.0)
	# brass hooks over the lip and feet
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(top + across * s + Vector2(-1, -1), Vector2(2, 2)), BRASS)
		draw_rect(Rect2(across * s + Vector2(-1, -1), Vector2(2, 2)), BRASS)
