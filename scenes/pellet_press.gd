extends Node2D
## Pellet press: a brass hopper over a screw press. Grit dropped into the
## hopper is kept (up to CAP); every three it presses together into one
## iron shot, pushed out of the spout on the `side` side: crusher and
## grindstone waste turned back into heavy turret ammo. Anything that
## isn't grit is thrown back out of the hopper. When it's full, grit
## waits in the hopper throat until there's room. Slow on its own, full
## speed with a gravity wheel or steam engine in reach.
## Put its feet on the floor or a ledge; click the body to turn it round.

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ORE := preload("res://scenes/ore.tscn")

const ORE_ONLY := 64
const PER_SHOT := 3
const CAP := 12
const PRESS := 0.8           # s per stroke at full power
const TOP := -50.0           # hopper rim
const RIM := 16.0            # half-width at the rim
const COLLAR := 12.0         # upright lip round the rim: catches grit flying across
const THROAT := -34.0        # hopper floor, over the press
const EJECT := Vector2(100, -30)

## Which side the shot comes out of: 1 right, -1 left.
@export var side := 1.0

var held := 0                # grit in the hopper (tests)
var taken := 0               # grit taken in, all told (tests)
var pressed := 0             # shot made (tests)
var rejected := 0            # other things thrown back out (tests)
var _work := -1.0            # 0..PRESS while a stroke runs; < 0 idle
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _flash := 0.0


func _ready() -> void:
	z_index = 1
	queue_redraw()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	# the hopper and the press body are solid to ore (only)
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	for seg in [[Vector2(-RIM, TOP), Vector2(-6, THROAT)], [Vector2(RIM, TOP), Vector2(6, THROAT)], [Vector2(-6, THROAT), Vector2(6, THROAT)],
			[Vector2(-RIM, TOP - COLLAR), Vector2(-RIM, TOP)], [Vector2(RIM, TOP - COLLAR), Vector2(RIM, TOP)]]:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = seg[0]
		sh.b = seg[1]
		cs.shape = sh
		body.add_child(cs)
	var box := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, -THROAT)
	box.shape = r
	box.position = Vector2(0, THROAT / 2.0)
	body.add_child(box)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(22, 14)
	ic.shape = ir
	ic.position = Vector2(0, THROAT - 7)
	_intake.add_child(ic)
	add_child(_intake)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_flash = maxf(0.0, _flash - delta * 4.0)
	for b in _intake.get_overlapping_bodies():
		if not (b is RigidBody2D) or b.is_queued_for_deletion() or b.freeze or b.has_meta("caught_by"):
			continue
		if b.is_in_group("ore") and b.get("kind") == "grit":
			if held < CAP:
				held += 1
				taken += 1
				b.queue_free()
				SFX.play_small(self, SFX.sfx_ore_knock("ore"), -20.0, 1.5)
		else:
			# not grit: thrown back up and out
			var rb := b as RigidBody2D
			if rb.linear_velocity.y > -200.0:
				rb.linear_velocity = Vector2(side * 90.0, -320.0)
				rejected += 1
	if _work < 0 and held >= PER_SHOT:
		held -= PER_SHOT
		_work = 0.0
	if _work >= 0:
		_work += delta * _rate * Tech.mult("assembly")
		if _work >= PRESS:
			_work = -1.0
			_eject()
	queue_redraw()


func _eject() -> void:
	pressed += 1
	_flash = 1.0
	var at := global_position + Vector2(side * 17, -6)
	var o: RigidBody2D = ORE.instantiate()
	o.kind = "shot"
	o.global_position = at
	get_tree().current_scene.add_child(o)
	o.linear_velocity = Vector2(EJECT.x * side, EJECT.y)
	FX.burst(get_parent(), at, Color(0.7, 0.7, 0.72, 0.8), 4, 35.0, 0.35, 1.5)
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.2)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := to_local(get_global_mouse_position())
	if absf(p.x) < 12 and p.y > THROAT and p.y < 0:
		side = -side
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	var steel := Color(0.42, 0.44, 0.5)
	# the press frame: two steel cheeks and a base
	draw_rect(Rect2(-12, THROAT, 24, -THROAT), dark)
	draw_rect(Rect2(-11, THROAT + 1, 22, -THROAT - 2), steel.darkened(0.25))
	draw_rect(Rect2(-11, THROAT + 1, 3, -THROAT - 2), steel)
	draw_rect(Rect2(8, THROAT + 1, 3, -THROAT - 2), steel)
	draw_rect(Rect2(-14, -4, 28, 4), dark)
	draw_rect(Rect2(-13, -3, 26, 2), brass.darkened(0.2))
	# the ram, coming down on the die as the stroke runs
	var f := 0.0 if _work < 0 else sin(clampf(_work / PRESS, 0.0, 1.0) * PI)
	var ram := THROAT + 4 + f * 14.0
	draw_line(Vector2(0, THROAT + 1), Vector2(0, ram), Color(0.7, 0.72, 0.76), 2.0)
	draw_rect(Rect2(-5, ram, 10, 4), dark)
	draw_rect(Rect2(-4, ram + 1, 8, 2), brass)
	draw_rect(Rect2(-5, -12, 10, 6), dark)                      # the die
	draw_rect(Rect2(-4, -11, 8, 4), steel.lightened(0.15))
	# the spout on the out side
	draw_rect(Rect2(side * 12 - (4 if side < 0 else 0), -10, 4, 5), dark)
	draw_rect(Rect2(side * 12 - (3 if side < 0 else 0), -9, 3, 3), brass.darkened(0.1))
	# the hopper: a brass funnel, grit showing in its throat
	var pts := PackedVector2Array([Vector2(-RIM, TOP), Vector2(RIM, TOP), Vector2(6, THROAT), Vector2(-6, THROAT)])
	draw_colored_polygon(pts, Color(0.2, 0.16, 0.12))
	var g := clampf(float(held) / CAP, 0.0, 1.0)
	if g > 0:
		var h := (THROAT - TOP) * g
		var w := 6.0 + (RIM - 6.0) * g
		draw_colored_polygon(PackedVector2Array([Vector2(-w, THROAT - h), Vector2(w, THROAT - h), Vector2(6, THROAT), Vector2(-6, THROAT)]), Color(0.55, 0.5, 0.46))
	for s in [-1.0, 1.0]:
		draw_line(Vector2(s * RIM, TOP - COLLAR), Vector2(s * RIM, TOP), dark, 3.0)
		draw_line(Vector2(s * RIM, TOP), Vector2(s * 6, THROAT), dark, 3.0)
		draw_line(Vector2(s * RIM, TOP - COLLAR), Vector2(s * RIM, TOP), brass.darkened(0.15), 1.0)
		draw_line(Vector2(s * RIM, TOP), Vector2(s * 6, THROAT), brass, 1.0)
	if _intake == null:
		return
	# what it's holding: a count over the hopper, pips toward the next shot
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-3 if held < 10 else -6, TOP - 6), str(held), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.8, 0.55))
	for i in PER_SHOT:
		var p := Vector2(-5 + i * 5, TOP - 3)
		draw_circle(p, 1.8, dark)
		if i < mini(held, PER_SHOT) or _work >= 0:
			draw_circle(p, 1.2, Color(0.95, 0.8, 0.45) if _work >= 0 else Color(0.62, 0.58, 0.54))
