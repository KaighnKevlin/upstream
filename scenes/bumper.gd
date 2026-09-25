extends Node2D
## Bumper: a sprung brass knob, pinball style. Anything that touches it gets
## kicked away: ore rebounds off it faster than it arrived (a 360-degree
## trampoline), enemies are knocked back and chipped, the player is flung.
## Put one at a pit's edge and walkers get batted in; stand one in ore's
## path for chaos.
## Stands on the floor like spikes; the knob is KNOB_Y above it.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const KNOB_Y := -17.0
const KNOB_R := 8.0
const ORE_KICK := 380.0       # added along the contact normal
const ORE_MAX := 900.0
const WALKER_KICK := Vector2(300, -250)
const ENEMY_DAMAGE := 1
const COOLDOWN := 0.25        # per body, so one touch is one kick

var hits := 0                 # for tests
var _area: Area2D
var _last := {}               # body id -> time of last kick
var _pulse := 0.0             # 1 on a hit, decays: knob swells and lights


func _ready() -> void:
	z_index = 1
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm and not has_meta("ghost"):  # stand on the floor under the placement point
		var cell := tm.local_to_map(tm.to_local(global_position))
		for i in 6:
			if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
				break
			cell.y += 1
		var c := tm.to_global(tm.map_to_local(cell))
		global_position = Vector2(global_position.x, c.y + 8)
	if has_meta("ghost"):
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2 | 8 | 32   # ore/ingots, enemies, player
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(KNOB_R * 2 + 6, 30)
	cs.shape = r
	cs.position = Vector2(0, -15)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_touch)


func _process(delta: float) -> void:
	if _pulse > 0:
		_pulse = maxf(0.0, _pulse - delta * 5.0)
		queue_redraw()
	# something resting against the knob keeps getting kicked
	if _area and Engine.get_process_frames() % 6 == 0:
		for b in _area.get_overlapping_bodies():
			_on_touch(b)


func _on_touch(body: Node2D) -> void:
	if not is_instance_valid(body) or body.has_meta("caught_by"):
		return
	var id := body.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -9.0)) < COOLDOWN:
		return
	var knob := global_position + Vector2(0, KNOB_Y)
	var n := (body.global_position - knob).normalized()
	if n == Vector2.ZERO:
		n = Vector2.UP
	if body is RigidBody2D:
		var b := body as RigidBody2D
		if b.freeze:
			return
		var v := b.linear_velocity
		var vn := v.dot(n)
		if vn < 0:
			v -= n * vn * 2.0   # reflect off the knob
		b.linear_velocity = (v + n * ORE_KICK / sqrt(maxf(b.mass, 0.1))).limit_length(ORE_MAX)
		b.sleeping = false
	elif body.has_method("knock"):
		var side := signf(n.x) if absf(n.x) > 0.05 else -signf(body.get("direction") if "direction" in body else 1.0)
		body.knock(Vector2(side * WALKER_KICK.x, WALKER_KICK.y))
		body.take_damage(ENEMY_DAMAGE)
	elif body.has_method("launch"):
		var side := signf(n.x) if absf(n.x) > 0.05 else 1.0
		body.launch(Vector2(side * WALKER_KICK.x, WALKER_KICK.y))
	else:
		return
	_last[id] = now
	hits += 1
	_pulse = 1.0
	queue_redraw()
	SFX.play(self, SFX.sfx_bumper())
	FX.burst(get_parent(), knob + n * KNOB_R, Color(1.0, 0.85, 0.45, 0.9), 5, 60.0, 0.25, 1.5)


# ── look: floor plate, coil, brass knob with a lit core ────────────────

const DARK := Color(0.09, 0.07, 0.1)
const STEEL := Color(0.42, 0.44, 0.5)
const SHINE := Color(0.78, 0.82, 0.86)
const BRASS := Color(0.85, 0.62, 0.28)
const BRASS_DK := Color(0.52, 0.34, 0.16)
const BRASS_HI := Color(1.0, 0.86, 0.5)
const CORE := Color(0.45, 0.85, 0.95)


func _draw() -> void:
	# base plate
	draw_rect(Rect2(-9, -3, 18, 3), DARK)
	draw_rect(Rect2(-8, -3, 16, 2), BRASS_DK)
	draw_rect(Rect2(-8, -3, 16, 1), BRASS)
	# coil spring up to the knob (squashes a touch on a hit)
	var top := KNOB_Y + KNOB_R - 1 + _pulse * 2.0
	var y := -4.0
	var k := 0
	while y > top:
		var w := 4.0 if k % 2 == 0 else -4.0
		draw_line(Vector2(-w, y), Vector2(w, y - 2), DARK, 2.0)
		draw_line(Vector2(-w, y), Vector2(w, y - 2), STEEL, 1.0)
		y -= 2.0
		k += 1
	# knob: swells and its core flares white on a hit
	var c := Vector2(0, KNOB_Y)
	var r := KNOB_R + _pulse * 2.5
	draw_circle(c, r + 1.5, DARK)
	draw_circle(c, r, BRASS_DK)
	draw_circle(c + Vector2(-0.5, -0.5), r - 1.2, BRASS)
	draw_circle(c, r * 0.55, DARK)
	draw_circle(c, r * 0.42, CORE.lerp(Color.WHITE, _pulse))
	draw_rect(Rect2((c + Vector2(-r * 0.55, -r * 0.6)).round(), Vector2(2, 1)), BRASS_HI)  # glint
	for a in 6:  # rivets round the rim
		var p := c + Vector2.from_angle(a * TAU / 6 + 0.3) * (r - 1.5)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), BRASS_HI)
