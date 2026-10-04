extends Node2D
## Flak cannon: anti-air fed by the marble line. A squat mortar on a brass
## turntable, standing on the ground, with a hopper funnel at its side.
## Pieces dropped into the hopper are loaded (up to CAP, shown as pips in
## the sockets along the plinth). When a flier (ornithopter, magpie,
## airship, dreadnought) is overhead, within REACH either side, the mortar
## tips toward it and lobs a loaded piece nearly straight up, led to where
## the flier will be; at the burst height the shell bursts into a ring of
## shrapnel that hurts every flier within BURST_R (iron 5, copper 3, grit
## 1). The burst height is the flier's own height, or a set fuse: click to
## cycle auto / 120 / 200 / 280 px. One shot every COOLDOWN s. Unloaded,
## it does nothing. Walkers pass through it.
## Art: tools/art/gen_flak_cannon.py.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const G := 980.0
const CAP := 6
const PIVOT := Vector2(0, -16)     # the trunnion the barrel turns on
const MUZZLE := 16.0               # px from the pivot to the muzzle
const HOPPER := Vector2(-20, -25)  # the hopper's mouth
const REACH := 200.0               # px either side, horizontally
const MIN_UP := 50.0               # a flier must be this far above the muzzle
const MAX_UP := 460.0
const FUSES := [0.0, 120.0, 200.0, 280.0]   # mode 0: at the flier's height
const COOLDOWN := 0.8
const BURST_R := 40.0
const OVERSHOOT := 24.0            # the shell's apex is this far above the burst
const MAX_TILT := 0.5              # radians either side of straight up
const TURN := 5.0                  # the turntable, radians/s
const DAMAGE := {"iron": 5, "copper": 3, "grit": 1, "shot": 4, "scrap": 3}
const COLORS := {"iron": Color(0.62, 0.66, 0.72), "copper": Color(0.88, 0.55, 0.28),
	"grit": Color(0.62, 0.56, 0.48), "shot": Color(0.5, 0.52, 0.58)}

@export var mode := 0              # the fuse: index into FUSES

var loaded: Array[String] = []     # kinds loaded, in order (the next shot is [0])
var shots := 0                     # tests
var bursts := 0
var hits := 0
var downed := 0
var last_burst := Vector2.ZERO     # tests: where, and how high over the muzzle
var last_height := 0.0
var _cool := 0.0
var _aim := 0.0                    # the barrel, radians from straight up (+ toward +x)
var _kick := 0.0
var _shells: Array = []            # [{pos, vel, kind, t, fuse}] in flight, global coords
var _frags: Array = []             # [{pos, vel, t, col}] shrapnel, drawn only
var _seen := {}                    # flier instance id -> [last pos, velocity]
var _took := {}                    # ore instance id -> time (don't count one twice)
var _barrel: Sprite2D


func _ready() -> void:
	z_index = 1
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw, which keeps the load's pips and the shells on top
	_spr(preload("res://assets/sprites/flak_hopper.png"), Vector2(-20, -3), Vector2(-8, -24))
	_barrel = _spr(preload("res://assets/sprites/flak_barrel.png"), PIVOT, Vector2(-8, -18))
	_spr(preload("res://assets/sprites/flak_base.png"), Vector2.ZERO, Vector2(-20, -24))
	if has_meta("ghost"):
		return
	_snap_to_floor()
	var body := StaticBody2D.new()
	body.collision_layer = 64            # ore-only: the hopper's funnel sides
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	body.physics_material_override = m
	for seg in [[Vector2(-27, -24), Vector2(-22.4, -12)], [Vector2(-13, -24), Vector2(-17.6, -12)],
			[Vector2(-22.4, -12), Vector2(-17.6, -12)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		cs.shape = s
		body.add_child(cs)
	add_child(body)


func _spr(tex: Texture2D, at: Vector2, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func _is_flier(e) -> bool:
	if e.get("enemy_type") == 4:     # ornithopter
		return true
	var s = e.get_script()
	return s != null and s.resource_path.get_file() in ["airship.gd", "magpie.gd", "dreadnought.gd"]


func _center(e) -> Vector2:
	return e.hit_center() if e.has_method("hit_center") else e.global_position


func _muzzle(a: float) -> Vector2:
	return to_global(PIVOT) + Vector2(sin(a), -cos(a)) * MUZZLE


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_cool -= delta
	_kick = maxf(0.0, _kick - delta * 5.0)
	_intake()
	var fliers := _track(delta)
	var want := 0.0
	var sol := {}
	var tg: Node2D = _pick(fliers)
	if tg:
		sol = _solve(tg)
		want = sol.angle
	_aim = move_toward(_aim, want, TURN * delta)
	if tg and not loaded.is_empty() and _cool <= 0.0 and absf(_aim - want) < 0.06:
		_fire(sol)
	_fly(delta, fliers)
	for f in _frags:
		f.t -= delta
		f.vel.y += G * 0.35 * delta
		f.pos += f.vel * delta
	_frags = _frags.filter(func(f): return f.t > 0.0)
	queue_redraw()


## Loads pieces that fall into the hopper's mouth.
func _intake() -> void:
	if loaded.size() >= CAP:
		return
	var mouth := global_position + HOPPER
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion() or o.has_meta("store_material"):
			continue
		var d: Vector2 = o.global_position - mouth
		if absf(d.x) < 8.0 and d.y > -10.0 and d.y < 14.0 and o.linear_velocity.y >= -5.0:
			var k = o.get("kind")
			if k == null or _took.has(o.get_instance_id()):
				continue
			_took[o.get_instance_id()] = now
			loaded.append(str(k))
			o.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.8)
			if loaded.size() >= CAP:
				break


## Every live flier, with its velocity measured frame to frame (they move
## themselves, not by `velocity`).
func _track(delta: float) -> Array:
	var out := []
	var keep := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not _is_flier(e):
			continue
		var id: int = e.get_instance_id()
		var c := _center(e)
		var v := Vector2.ZERO
		if _seen.has(id):
			var prev: Array = _seen[id]
			v = (prev[1] as Vector2).lerp((c - (prev[0] as Vector2)) / maxf(delta, 0.001), 0.3)
		keep[id] = [c, v]
		out.append(e)
	_seen = keep
	return out


func _pick(fliers: Array) -> Node2D:
	var best: Node2D = null
	var bd := REACH
	var m := _muzzle(0.0)
	for e in fliers:
		var c := _center(e)
		var up := m.y - c.y
		var dx := absf(c.x - m.x)
		if up < MIN_UP or up > MAX_UP or dx > bd:
			continue
		bd = dx
		best = e
	return best


## The shot at `e`: launch speed, flight time to the burst, barrel angle.
func _solve(e: Node2D) -> Dictionary:
	var c := _center(e)
	var v: Vector2 = _seen.get(e.get_instance_id(), [c, Vector2.ZERO])[1]
	var m := _muzzle(_aim)
	var h: float = FUSES[mode] if mode > 0 else m.y - c.y
	var t := 0.4
	for i in 2:   # auto: where it will be at the burst, not where it is
		if mode == 0:
			h = m.y - (c.y + v.y * t)
		h = maxf(h, 40.0)
		var vy := sqrt(2.0 * G * (h + OVERSHOOT))
		t = (vy - sqrt(maxf(vy * vy - 2.0 * G * h, 0.0))) / G
	var v0 := sqrt(2.0 * G * (h + OVERSHOOT))
	var vx := clampf((c.x + v.x * t - m.x) / t, -v0 * tan(MAX_TILT), v0 * tan(MAX_TILT))
	return {"angle": atan2(vx, v0), "vx": vx, "vy": -v0, "t": t, "h": h}


func _fire(sol: Dictionary) -> void:
	var kind: String = loaded.pop_front()
	var at := _muzzle(_aim)
	_shells.append({"pos": at, "vel": Vector2(sol.vx, sol.vy), "kind": kind, "t": 0.0,
		"fuse": sol.t, "h": sol.h})
	shots += 1
	_cool = COOLDOWN
	_kick = 1.0
	FX.burst(get_parent(), at, Color(1.0, 0.85, 0.5), 8, 110.0, 0.25, 1.5, 200.0)
	FX.burst(get_parent(), at, Color(0.55, 0.52, 0.5, 0.7), 5, 40.0, 0.7, 2.4, -60.0)
	SFX.play_small(self, SFX.sfx_turret_fire(), -6.0, 1.3)


func _fly(delta: float, fliers: Array) -> void:
	var left := []
	for s in _shells:
		s.t += delta
		s.vel.y += G * delta
		s.pos += s.vel * delta
		var hit := false
		for e in fliers:   # a direct hit bursts it early
			if is_instance_valid(e) and _center(e).distance_to(s.pos) < (e.hit_radius() if e.has_method("hit_radius") else 14.0):
				hit = true
				break
		if hit or s.t >= s.fuse or s.t > 3.0:
			_burst(s.pos, s.kind, s.h)
		else:
			left.append(s)
	_shells = left


## The shell comes apart: a ring of shrapnel, and every flier within
## BURST_R takes the piece's damage.
func _burst(at: Vector2, kind: String, h: float) -> void:
	bursts += 1
	last_burst = at
	last_height = h
	var col: Color = COLORS.get(kind, Color(0.6, 0.6, 0.6))
	for i in 12:
		var a := TAU * i / 12.0 + randf_range(-0.2, 0.2)
		_frags.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * randf_range(150.0, 230.0),
			"t": randf_range(0.22, 0.34), "col": col})
	FX.burst(get_parent(), at, Color(1.0, 0.9, 0.55), 14, 170.0, 0.22, 2.0, 0.0)
	# a flash that lights the cavern round it for a moment
	var glow := PointLight2D.new()
	glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
	glow.color = Color(1.0, 0.8, 0.45)
	glow.energy = 1.6
	glow.texture_scale = 1.4
	glow.global_position = at
	get_parent().add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "energy", 0.0, 0.3)
	tw.tween_callback(glow.queue_free)
	FX.burst(get_parent(), at, Color(0.35, 0.33, 0.33, 0.75), 8, 45.0, 0.9, 3.2, -30.0)
	SFX.play_small(self, SFX.sfx_turret_fire(), -8.0, 0.7)
	var dmg: int = DAMAGE.get(kind, 2)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not _is_flier(e) or not e.has_method("take_damage"):
			continue
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 14.0
		if _center(e).distance_to(at) < BURST_R + r * 0.5:
			e.take_damage(dmg)
			hits += 1
			if "_dying" in e and e._dying:
				downed += 1


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Pointer.world(self).distance_to(global_position + Vector2(0, -10)) < 14:
		mode = (mode + 1) % FUSES.size()
		SFX.play_small(self, SFX.sfx_clink(), -12.0, 1.6)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# the base, hopper and barrel are sprites (see _ready): the barrel tipped
	# to the aim, sitting back in its yoke when it fires
	_barrel.rotation = _aim
	_barrel.position = PIVOT + Vector2(-sin(_aim), cos(_aim)) * roundf(_kick * 2.0)
	var dark := Color(0.1, 0.08, 0.07)
	# the load, in the plinth's sockets
	for i in loaded.size():
		var p := Vector2(-12.5 + 5 * i, -3.5)
		draw_circle(p, 1.9, dark)
		draw_circle(p, 1.4, COLORS.get(loaded[i], Color(0.7, 0.7, 0.7)))
	# the fuse: four marks on the turntable, the set one lit
	for i in FUSES.size():
		var p := Vector2(-7.5 + 5 * i, -9.5)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.85, 0.4) if i == mode else Color(0.25, 0.2, 0.15))
	for s in _shells:
		var p := to_local(s.pos)
		draw_circle(p, 2.6, dark)
		draw_circle(p, 1.9, COLORS.get(s.kind, Color(0.7, 0.7, 0.7)))
		draw_line(p, p - (s.vel as Vector2).normalized() * 6.0, Color(1.0, 0.8, 0.45, 0.5), 1.0)
	for f in _frags:
		var p := to_local(f.pos)
		draw_line(p, p - (f.vel as Vector2) * 0.03, Color(1.0, 0.8, 0.4, 0.7), 1.0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), (f.col as Color).lightened(0.3))
