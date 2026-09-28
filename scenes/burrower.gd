extends Node2D
## Clockwork burrower: a brass mole with a drill for a nose. It comes in
## from the edge of the map underground, digging straight through the rock
## for your nearest marble-machine piece (anything you built; a wheel or
## engine that powers things tempts it most, then what they drive, like
## the gremlin). Where it breaks into a cave it drops to the floor and
## scuttles across, chewing through any wall in the way. At the piece it
## sets to gnawing (CHEW seconds, a bar over the piece): then the piece
## comes apart in a burst of scrap and it goes for the next one. With
## nothing left to chew it burrows back off the map.
## Its tunnels stay open: every one it comes by perforates your caves (ore
## veins it cuts spill into the tunnel). Fragile: fast ore hurts it (a
## gauss shot, a stamp, anything dropped on it), and a knock shakes it off
## its meal. Dust puffs from the ground above give it away while it digs.
## Iron plating (scenes/iron_plating.gd) turns its drill: it digs round
## whichever end of the run is quicker going (the rock in the way), never
## gnaws at a piece through a plate, and gives a piece walled in all round
## up after a few tries. Come up through a cave floor, it scrambles out.
## Art: a 4-frame sprite (tools/art/gen_burrower.py), posed in _draw.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const Gremlin = preload("res://scenes/gremlin.gd")
const Plating = preload("res://scenes/iron_plating.gd")

enum State { DIG, CHEW, LEAVE, DYING }

const SPEED := 55.0              # through open tunnel or cave
const FALL := 520.0              # dropping to a cave floor
const DIG_TIME := {              # seconds to grind out a tile, by tile type
	WorldGen.TILE_DIRT: 0.14, WorldGen.TILE_GRASS: 0.14, WorldGen.TILE_STONE: 0.26,
	WorldGen.TILE_DEEP_STONE: 0.36, WorldGen.TILE_IRON: 0.32, WorldGen.TILE_COPPER: 0.3,
	WorldGen.TILE_HARD: 1.0,
}
const DIVE_ROWS := 8             # it goes down this far below the surface before turning for the piece
const MAX_HP := 7
const CHEW := 3.0                # seconds to gnaw a piece apart
const REACH := Vector2(26, 50)   # close enough to gnaw (x, y from the piece's origin)
const GIVE_UP := 8.0             # no nearer this long: try another piece
const PROGRESS := 16.0
const FORGET := 20.0
const RUMBLE_EVERY := 0.5
const BODY := 8.0                # half its height: stands this far over a floor
const ROUND := 32.0              # how far clear of a plate's end it digs round it
const ROUND_TIME := 10.0         # gives up on a way round after this
const SPILL_SAFE := 12.0         # s its own spilled vein ore can't hurt it (it falls down the shaft onto it)
const MAX_ROUNDS := 6            # turned by plating this often for one piece: walled in, try another

var hp := MAX_HP
var damage := 5                  # a bite if the prospector gets in its way
var velocity := Vector2.ZERO     # turrets lead on this
var direction := -1.0
var buried := true               # in the rock: turrets that aim can't see it
var dug := 0                     # tiles carved (tests)
var chewed := 0                  # pieces wrecked (tests)
var _dying := false
var _state := State.DIG
var _heading := Vector2(-0.4, 0.9).normalized()
var _target: Node2D = null
var _dig := 0.0
var _work := 0.0
var _fall := 0.0
var _rumble := 0.0
var _gnaw := 0.0
var _retarget := 0.0
var _best_d := INF
var _progress_t := 0.0
var _skip := {}
var _knock := Vector2.ZERO
var _anim := 0.0
var _flash := 0.0
var _judder := Vector2.ZERO
var _round: Array = []           # waypoints round iron plating, next first
var _round_t := 0.0
var _round_plate: Node2D = null
var _round_pad := 0.0
var detours := 0                 # tests: times it had to go round plating
var _rounds_here := 0
var _step_t := 0.0
var _spill: Array = []           # [ore, s]: what it spilled from a vein, tumbling down its own tunnel
var _spr: Sprite2D               # the mole: drill turning, claws scratching


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/burrower.png")
	_spr.hframes = 4
	_spr.offset = Vector2(0, -1)     # frames are 38x24 about (19, 13)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	add_to_group("enemies")
	add_to_group("burrowers")
	z_index = 3
	direction = -1.0 if global_position.x > WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE * 0.5 else 1.0
	_heading = Vector2(direction * 0.4, 0.9).normalized()
	# a faint lamp-glow so you can see it in a dark cave
	var glow := PointLight2D.new()
	glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(32)
	glow.color = Color(1.0, 0.55, 0.25)
	glow.energy = 0.55
	glow.texture_scale = 1.1
	add_child(glow)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 10.0


func knock(v: Vector2) -> void:
	if _dying:
		return
	_knock = v * 0.5
	_work = maxf(0.0, _work - CHEW * 0.5)   # shaken off its meal: loses half its progress


func _tm() -> TileMapLayer:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("TileMapLayer") as TileMapLayer if scene else null


func _solid_at(tm: TileMapLayer, p: Vector2) -> bool:
	return tm.get_cell_source_id(tm.local_to_map(tm.to_local(p))) != -1


func _machines() -> Array:
	var bs := get_node_or_null("/root/BuildSystem")
	if bs == null:
		return []
	return bs._placed_buildings.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion() and not _skip.has(b) and not b.is_in_group("iron_plating"))


func _pick() -> void:
	var was := _target
	_target = null
	var best := INF
	for b in _machines():
		var d: float = b.global_position.distance_to(global_position) * Gremlin.lure(b)
		if d < best:
			best = d
			_target = b
	if _target != was:
		_best_d = INF
		_progress_t = 0.0
		_round.clear()
		_round_plate = null
		_rounds_here = 0


## In an open cave rather than its own tunnel: the rock above it is clear
## for a good way (a tunnel is only a few tiles wide).
func _in_cave(tm: TileMapLayer) -> bool:
	for y in [-14.0, -28.0, -42.0]:
		for x in [-28.0, -14.0, 0.0, 14.0, 28.0]:
			if _solid_at(tm, global_position + Vector2(x, y)):
				return false
	return true


func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		return
	_anim += delta
	_flash = maxf(0.0, _flash - delta)
	var tm := _tm()
	if tm == null:
		return
	for i in range(_spill.size() - 1, -1, -1):
		_spill[i][1] -= delta
		if _spill[i][1] <= 0.0 or not is_instance_valid(_spill[i][0]):
			_spill.remove_at(i)
		else:
			_spill[i][0]._hurt_cooldown = 0.1
	for k in _skip.keys():
		if not is_instance_valid(k):
			_skip.erase(k)
			continue
		_skip[k] -= delta
		if _skip[k] <= 0:
			_skip.erase(k)
	_retarget -= delta
	if _state != State.CHEW and (_retarget <= 0 or _target == null or not is_instance_valid(_target)):
		_retarget = 1.0
		_pick()
		_state = State.DIG if _target else State.LEAVE
	if _state == State.CHEW and (_target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion()):
		_state = State.DIG
		_work = 0.0
	# a knock: slides it a little, through open space only
	if _knock.length() > 5.0:
		var step := _knock * delta
		if not _solid_at(tm, global_position + step + Vector2(0, step.y * 2.0)):
			global_position += step
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var cave := _in_cave(tm)
	buried = not cave
	var floored := _solid_at(tm, global_position + Vector2(0, BODY + 1)) or _solid_at(tm, global_position + Vector2(0, BODY + 14))
	# dropped into a cave: fall to its floor
	if cave and not _solid_at(tm, global_position + Vector2(0, BODY + 1)):
		_fall = minf(_fall + FALL * delta, 400.0)
		var dy := _fall * delta
		for i in 4:
			if _solid_at(tm, global_position + Vector2(0, BODY + dy)):
				dy *= 0.5
		global_position.y += dy
	else:
		_fall = 0.0
	match _state:
		State.CHEW:
			_chew(delta)
			velocity = Vector2.ZERO
		State.DIG:
			_seek(tm, delta, cave, floored)
		State.LEAVE:
			direction = signf(global_position.x - WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE * 0.5)   # the nearer edge
			_heading = _going_round(Vector2(direction, 0), cave, delta)
			if _heading == Vector2.ZERO:
				_heading = Vector2(direction, 0)
			var moved := _advance(tm, delta)
			velocity = _heading * SPEED if moved else Vector2.ZERO
			if global_position.x < 10 or global_position.x > WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE - 10:
				queue_free()
	_rumble -= delta
	if _rumble <= 0 and buried and _state != State.CHEW:
		_rumble = RUMBLE_EVERY
		_puff_surface(tm)
	queue_redraw()


func _seek(tm: TileMapLayer, delta: float, cave: bool, floored: bool) -> void:
	var goal := _target.global_position
	var d := goal - global_position
	if absf(d.x) < REACH.x and absf(d.y) < REACH.y and not Plating.crosses(get_tree(), global_position, goal):
		_state = State.CHEW
		_work = 0.0
		direction = signf(d.x) if absf(d.x) > 2 else direction
		return
	# stops getting nearer (a piece up in the air it can't climb to): another one
	if d.length() < _best_d - PROGRESS:
		_best_d = d.length()
		_progress_t = 0.0
	else:
		_progress_t += delta
	if _progress_t > GIVE_UP:
		_skip[_target] = FORGET
		_target = null
		_retarget = 0.0
		return
	var surface_y := (WorldGen.SURFACE_ROWS + DIVE_ROWS) * WorldGen.TILE_SIZE
	var want := d.normalized()
	if global_position.y < minf(surface_y, goal.y - 20.0):
		# first down, out of sight, well clear of the dome and the surface works
		want = Vector2(signf(d.x) * 0.4, 0.9).normalized()
	elif cave:
		# on a cave floor it can't climb the air: across, or down through the floor
		if not floored:
			want = Vector2(signf(d.x), 0) if absf(d.x) > 4 else Vector2.ZERO
		elif d.y > REACH.y:
			want = Vector2(signf(d.x) * 0.5, 0.85).normalized()
		else:
			want = Vector2(signf(d.x), 0)
	want = _going_round(want, cave, delta)
	if want == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	_heading = want
	if absf(_heading.x) > 0.05:
		direction = signf(_heading.x)
	_step_t -= delta
	if d.y < -4.0 and absf(_heading.x) > 0.2 and _step_t <= 0.0 and _step_up(tm):
		_step_t = 0.25
		velocity = _heading * SPEED
		return
	var moved := _advance(tm, delta)
	velocity = _heading * SPEED if moved else Vector2.ZERO


## Moves along the heading, grinding away the tiles ahead first. Returns
## whether it moved (false while it is chewing through rock).
func _advance(tm: TileMapLayer, delta: float) -> bool:
	var ahead := global_position + _heading * 12.0
	var side := _heading.orthogonal()
	# iron plating: the drill skids off it, so it plans a way round
	for o in [-8.0, 0.0, 8.0]:
		var plate := Plating.at(get_tree(), ahead + side * o, Plating.GUARD)
		if plate:
			plate.scraped(ahead + side * o)
			_plan_round(plate)
			_dig = 0.0
			_judder = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
			return false
	var cells := {}
	for o in [-8.0, 0.0, 8.0]:
		var c := tm.local_to_map(tm.to_local(ahead + side * o))
		if tm.get_cell_source_id(c) != -1 and c.x >= 1 and c.x < WorldGen.WORLD_WIDTH - 1 and c.y < WorldGen.WORLD_HEIGHT - 1:
			cells[c] = true
	if cells.is_empty():
		_dig = 0.0
		_judder = Vector2.ZERO
		global_position += _heading * SPEED * delta
		return true
	var need := 0.0
	for c in cells:
		need = maxf(need, DIG_TIME.get(tm.get_cell_atlas_coords(c).x, 0.3))
	_dig += delta
	_judder = Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
	if randf() < delta * 10.0:
		FX.burst(get_parent(), ahead, Color(0.55, 0.47, 0.38), 1, 60.0, 0.3, 1.3)
	if _dig >= need:
		_dig = 0.0
		for c in cells:
			_carve(tm, c)
	return false


## Its piece is higher up and there's a one-tile lip ahead with air over
## it and over itself (come up through a cave floor from below, into a
## trench of its own digging): it scrambles up onto it rather than grinding
## along inside the floor, falling back into its own hole.
func _step_up(tm: TileMapLayer) -> bool:
	var ahead := Vector2(direction * 12.0, 0.0)
	var up := Vector2(0, -WorldGen.TILE_SIZE)
	if not _solid_at(tm, global_position + ahead) or _solid_at(tm, global_position + ahead + up) \
			or _solid_at(tm, global_position + up) or _solid_at(tm, global_position + ahead + up * 1.5):
		return false
	global_position += Vector2(direction * 4.0, -WorldGen.TILE_SIZE)
	return true


## Following a way round iron plating: the heading to the next waypoint
## (on a cave floor it can't climb the air), or `want` when it isn't.
func _going_round(want: Vector2, cave: bool, delta: float) -> Vector2:
	if _round.is_empty():
		return want
	_round_t -= delta
	if _round_t <= 0.0:
		_round.clear()
		_round_plate = null
		return want
	var to: Vector2 = _round[0] - global_position
	# a waypoint up in the air over a cave floor it has come out onto: as near as it gets
	if to.length() < 10.0 or (not buried and to.y < -8.0 and absf(to.x) < 20.0):
		_round.pop_front()
		_best_d = INF             # a leg of the way round done: that's progress
		_progress_t = 0.0
		if _round.is_empty():
			_round_plate = null
			_round_pad = 0.0
			return want
		to = _round[0] - global_position
	var h := to.normalized()
	if cave and h.y < 0.0:
		h = Vector2(signf(h.x) if absf(h.x) > 0.01 else direction, 0.0)
	return h


## Turned by a plate: round whichever end of its run is the shorter way to
## the piece (down and under, if it's standing on a cave floor): out past
## the end on its own side, across, and then on for the piece.
func _plan_round(plate: Node2D) -> void:
	if plate == _round_plate and not _round.is_empty():
		if ROUND_TIME - _round_t < 0.4:
			return              # only just planned: grinding its nose on it a moment
		# scraped it again on the way: give it a wider berth, up to a point
		_round_pad = _round_pad + 12.0 if _round_pad < 36.0 else 0.0
	elif plate != _round_plate:
		_round_pad = 0.0
		detours += 1
	_rounds_here += 1
	if _rounds_here > MAX_ROUNDS and _target:
		# walled in all round: leave that piece be for a while
		_skip[_target] = FORGET
		_target = null
		_retarget = 0.0
		_round.clear()
		_round_plate = null
		return
	_round_plate = plate
	var goal: Vector2 = _target.global_position if _target and is_instance_valid(_target) else global_position + _heading * 200.0
	var pad := ROUND + _round_pad
	var best := []
	var best_cost := INF
	var cave := not buried
	var re: Array = plate.run_ends()
	for k in 2:
		var end_at: Vector2 = re[k][0]
		var out: Vector2 = re[k][1]
		# out past the end on its own side of the run, then across
		var m := out.orthogonal()
		var s := signf(m.dot(global_position - end_at))
		if s == 0.0:
			s = 1.0
		var w1: Vector2 = end_at + out * pad + m * s * pad
		var w2: Vector2 = end_at + out * pad - m * s * pad
		# seconds: the rock it would have to grind through on the way, and the going
		var cost := _leg_cost(global_position, w1) + _leg_cost(w1, w2) + _leg_cost(w2, goal)
		if w2.y > goal.y + 20.0:
			cost *= 1.3         # and it comes up at the piece through its floor, clumsily
		if cave:
			cost -= end_at.y * 10.0        # on a cave floor: under, never over (it can't climb the air)
		if cost < best_cost:
			best_cost = cost
			best = [w1, w2]
	_round = best
	_round_t = ROUND_TIME


## Rough seconds to get from a to b: the rock in the way (a swathe three
## tiles wide, like its drill), then the distance; through plating, no go.
func _leg_cost(a: Vector2, b: Vector2) -> float:
	var tm := _tm()
	var t := a.distance_to(b) / SPEED
	if Plating.crosses(get_tree(), a, b):
		t += 30.0               # straight through more plating: no way at all
	if tm == null:
		return t
	var cells := {}
	var n := int(a.distance_to(b) / 8.0) + 1
	var side := (b - a).normalized().orthogonal() * 8.0
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for o in [-1.0, 0.0, 1.0]:
			var c := tm.local_to_map(tm.to_local(p + side * o))
			if not cells.has(c) and tm.get_cell_source_id(c) != -1:
				cells[c] = true
				t += DIG_TIME.get(tm.get_cell_atlas_coords(c).x, 0.3) / 3.0   # it grinds three at once
	return t


func _carve(tm: TileMapLayer, c: Vector2i) -> void:
	var src := tm.get_cell_source_id(c)
	var atlas := tm.get_cell_atlas_coords(c)
	var at := tm.to_global(tm.map_to_local(c))
	tm.set_cell(c, -1)
	WorldGen.reframe_around(tm, c)
	dug += 1
	FX.tile_break(get_parent(), tm, c, src, atlas, -_heading)
	get_tree().call_group("tile_shading", "mark_dirty", c)
	get_tree().call_group("cave_decor", "tile_cleared", c)
	# a vein it cuts through spills its ore into the tunnel behind it
	if atlas.x == WorldGen.TILE_IRON or atlas.x == WorldGen.TILE_COPPER:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if atlas.x == WorldGen.TILE_IRON else "copper"
		o.global_position = at
		_spill.append([o, SPILL_SAFE])
		get_tree().current_scene.add_child.call_deferred(o)
	if dug % 3 == 0:
		SFX.play_small(self, SFX.sfx_mine_hit(), -14.0, randf_range(0.8, 1.0))


func _chew(delta: float) -> void:
	var d := _target.global_position - global_position
	if absf(d.x) > REACH.x * 1.4 or absf(d.y) > REACH.y * 1.4:   # knocked off it
		_state = State.DIG
		return
	_work += delta
	_gnaw -= delta
	_judder = Vector2(randf_range(-0.6, 0.6), 0)
	direction = signf(_target.global_position.x - global_position.x) if absf(_target.global_position.x - global_position.x) > 2 else direction
	_heading = Vector2(direction, 0)
	if _gnaw <= 0:
		_gnaw = 0.25
		var at := global_position + Vector2(12 * direction, -2)
		FX.burst(get_parent(), at, Color(1.0, 0.8, 0.4), 3, 90.0, 0.2, 1.1, -40.0)
		SFX.play_small(self, SFX.sfx_clink(), -10.0, randf_range(0.7, 0.9))
	if _work >= CHEW:
		_wreck(_target)
		_work = 0.0
		_target = null
		_retarget = 0.0
		_state = State.DIG


func _wreck(b: Node2D) -> void:
	var at := b.global_position + Vector2(0, -12)
	FX.burst(get_parent(), at, Color(0.7, 0.62, 0.5), 16, 150.0, 0.5, 2.2)
	FX.debris(get_parent(), at, 8, 180.0, false)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), -2.0, 0.8)
	preload("res://scenes/ore.gd").spill(get_parent(), at, 2)
	var bs := get_node_or_null("/root/BuildSystem")
	if bs:
		bs._placed_buildings.erase(b)
	b.queue_free()
	chewed += 1
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner") and chewed == 1:
		scene._show_banner("A BURROWER ATE A MACHINE", "it tunnels in from the edge: hit it with ore")


## A telltale dust puff where the ground is above it.
func _puff_surface(tm: TileMapLayer) -> void:
	var col := tm.local_to_map(tm.to_local(global_position)).x
	for row in range(0, WorldGen.WORLD_HEIGHT):
		if tm.get_cell_source_id(Vector2i(col, row)) != -1:
			var top := tm.to_global(tm.map_to_local(Vector2i(col, row))) + Vector2(randf_range(-6, 6), -8)
			if top.y < global_position.y - 20:
				FX.burst(get_parent(), top, Color(0.55, 0.45, 0.33, 0.8), 3, 30.0, 0.5, 1.6, -40.0)
			return


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_flash = 0.15
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 1.3)
		return
	_dying = true
	_state = State.DYING
	_work = 0.0
	remove_from_group("enemies")
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), -2.0, 1.2)
	preload("res://scenes/ore.gd").spill(get_parent(), global_position, 1)
	FX.burst(get_parent(), global_position, Color(1.0, 0.75, 0.35), 12, 140.0, 0.4, 1.8)
	FX.debris(get_parent(), global_position, 6, 170.0, false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


## The mole (drawn facing +x, then turned to its heading) and the gnaw bar.
func _draw() -> void:
	var ang := _heading.angle() if _heading.x >= 0 else _heading.angle() + PI
	var flip := 1.0 if (_heading.x >= 0 if absf(_heading.x) > 0.05 else direction > 0) else -1.0
	if absf(_heading.x) <= 0.05:
		ang = (PI / 2 if _heading.y > 0 else -PI / 2) * flip
	_spr.position = _judder
	_spr.rotation = ang
	_spr.scale = Vector2(flip, 1)
	_spr.frame = int(_anim * 16.0) % 4
	_spr.self_modulate = Color(3, 3, 3) if _flash > 0 else Color.WHITE
	if _state == State.CHEW and _target and is_instance_valid(_target):
		var top := to_local(_target.global_position + Vector2(-14, -46))
		draw_rect(Rect2(top, Vector2(28, 4)), Color(0.08, 0.07, 0.06, 0.85))
		draw_rect(Rect2(top + Vector2(1, 1), Vector2(26 * clampf(_work / CHEW, 0, 1), 2)), Color(0.95, 0.6, 0.3))
