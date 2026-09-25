extends StaticBody2D
## Field bridge: the plank-and-truss span a bridge engine swings across a
## ditch. Enemies (and ore, and you) walk on it like ground. It unfolds from
## the near lip over about a second. Hard hits from ore wear it down (iron
## counts for more); when it gives, it snaps in the middle, both halves
## swing down on their lip hinges, and whoever was on it drops into the
## ditch. The origin is the near lip, at the surface; it spans `span`
## pixels toward `side`.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const DECK := 5.0
const STRENGTH := 5.0          # summed ore mass of hard hits it takes
const PLANK := Color(0.53, 0.38, 0.24)
const PLANK_LIT := Color(0.66, 0.5, 0.32)
const PLANK_DARK := Color(0.4, 0.28, 0.19)
const OUTLINE := Color(0.16, 0.15, 0.12)
const BRASS := Color(0.85, 0.72, 0.45)
const BRASS_DARK := Color(0.53, 0.38, 0.24)

var span := 64.0
var side := -1.0
var broken := false
var ready_to_walk := false
var _ext := 0.0
var _damage := 0.0
var _shape: CollisionShape2D
var _halves := [0.0, 0.0]      # drop angles once broken


func _ready() -> void:
	add_to_group("field_bridges")
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.one_way_collision = true   # climbers coming up a lip wall pass through from below
	_shape.disabled = true
	add_child(_shape)
	var t := create_tween()
	t.tween_property(self, "_ext", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_lay)


func _lay() -> void:
	(_shape.shape as RectangleShape2D).size = Vector2(span + 10.0, DECK)
	_shape.position = Vector2(side * span * 0.5, DECK * 0.5)
	_shape.disabled = false
	ready_to_walk = true
	SFX.play(self, SFX.sfx_clink(), -4.0, 0.55)
	FX.burst(get_parent(), global_position + Vector2(side * span, 0), Color(0.55, 0.45, 0.35), 8, 60.0, 0.4, 1.8)


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if broken or not ready_to_walk:
		return
	var x0 := global_position.x
	var x1 := x0 + side * span
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze:
			continue
		var p: Vector2 = o.global_position
		if p.x < minf(x0, x1) or p.x > maxf(x0, x1) or p.y < global_position.y - 16.0 or p.y > global_position.y + 8.0:
			continue
		var v: float = maxf(o.linear_velocity.length(), float(o.get("_prev_speed")) if o.get("_prev_speed") != null else 0.0)
		if v < 170.0 or o.has_meta("hit_bridge"):
			continue
		o.set_meta("hit_bridge", true)
		get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(o): o.remove_meta("hit_bridge"))
		_damage += o.mass * clampf(v / 300.0, 0.6, 1.6)
		SFX.play_small(self, SFX.sfx_ore_knock("wood"), -4.0, randf_range(0.7, 0.9))
		FX.burst(get_parent(), p, PLANK_LIT, 5, 70.0, 0.35, 1.4)
		if _damage >= STRENGTH:
			snap()
			return


func snap() -> void:
	if broken:
		return
	broken = true
	remove_from_group("field_bridges")
	_shape.set_deferred("disabled", true)
	SFX.play(self, SFX.sfx_mine_break(), -2.0, 0.8)
	FX.debris(get_parent(), global_position + Vector2(side * span * 0.5, 0), 6, 140.0, false)
	FX.burst(get_parent(), global_position + Vector2(side * span * 0.5, 0), PLANK_LIT, 12, 90.0, 0.5, 2.0)
	var t := create_tween()
	t.tween_method(func(a: float): _halves = [a, a * 0.9], 0.0, 1.35, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(2.5)
	t.tween_callback(queue_free)


func _draw() -> void:
	var ln := span * _ext
	if not broken:
		_draw_span(Vector2.ZERO, side, ln)
		return
	# two halves hanging from their hinges
	var half := span * 0.5
	draw_set_transform(Vector2.ZERO, side * _halves[0], Vector2.ONE)
	_draw_span(Vector2.ZERO, side, half)
	draw_set_transform(Vector2(side * span, 0), -side * _halves[1], Vector2.ONE)
	_draw_span(Vector2.ZERO, -side, half)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_span(from: Vector2, dir: float, ln: float) -> void:
	if ln < 1:
		return
	var a := from
	var b := from + Vector2(dir * ln, 0)
	var lo := minf(a.x, b.x)
	# truss under the deck: a brass zigzag between two chords
	draw_line(Vector2(lo, DECK + 5), Vector2(lo + ln, DECK + 5), OUTLINE, 3.0)
	var n := maxi(1, int(ln / 8.0))
	for k in n:
		var x0 := lo + k * ln / n
		var x1 := lo + (k + 1) * ln / n
		var up := k % 2 == 0
		draw_line(Vector2(x0, DECK if up else DECK + 5), Vector2(x1, DECK + 5 if up else DECK), OUTLINE, 2.5)
	for k in n:
		var x0 := lo + k * ln / n
		var x1 := lo + (k + 1) * ln / n
		var up := k % 2 == 0
		draw_line(Vector2(x0, DECK if up else DECK + 5), Vector2(x1, DECK + 5 if up else DECK), BRASS_DARK, 1.0)
	draw_line(Vector2(lo, DECK + 5), Vector2(lo + ln, DECK + 5), BRASS, 1.0)
	# deck planks
	draw_rect(Rect2(lo - 1, -1, ln + 2, DECK + 2), OUTLINE)
	var x := lo
	var k := 0
	while x < lo + ln:
		var w := minf(4.0, lo + ln - x)
		draw_rect(Rect2(x, 0, w - 0.5, DECK), [PLANK, PLANK_LIT, PLANK_DARK][k % 3])
		draw_rect(Rect2(x, 0, w - 0.5, 1), PLANK_LIT)
		x += 4.0
		k += 1
	# hinge pins at the ends
	draw_rect(Rect2(a + Vector2(-1.5, 1), Vector2(3, 3)), BRASS)
	draw_rect(Rect2(b + Vector2(-1.5, 1), Vector2(3, 3)), BRASS)
