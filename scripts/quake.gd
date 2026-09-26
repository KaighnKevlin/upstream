extends Node2D
## An earthquake (a random event; F4 in sandbox). For DURATION seconds the
## ground heaves in waves: the camera shakes, everything loose (ore, scrap,
## ingots) is jolted about, enemies stumble, and chunks of cave ceiling near
## the camera crack loose and come down as falling rocks that hurt whatever
## they land on. The holes they leave stay.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const DURATION := 8.0
const ROCK_DAMAGE := 5

var falls := 0            # tests
var jolts := 0
var _t := 0.0
var _pulse := 0.0
var _crack := 0.6
var _rocks := []          # [pos, vy, tile color]


func _ready() -> void:
	z_index = 4


func _tm() -> TileMapLayer:
	return get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer


func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size / (cam.zoom if cam else Vector2.ONE)
	var c := cam.get_screen_center_position() if cam else Vector2(1200, 300)
	return Rect2(c - size * 0.5, size)


func _physics_process(delta: float) -> void:
	_t += delta
	var strength := sin(PI * clampf(_t / DURATION, 0.0, 1.0))   # builds, peaks, dies away
	if _t < DURATION:
		_pulse -= delta
		if _pulse <= 0:
			_pulse = randf_range(0.35, 0.7)
			_heave(strength)
		_crack -= delta * strength
		if _crack <= 0:
			_crack = randf_range(0.25, 0.6)
			_break_ceiling()
	_fall_rocks(delta)
	queue_redraw()
	if _t > DURATION + 2.0 and _rocks.is_empty():
		queue_free()


func _heave(strength: float) -> void:
	FX.shake(self, 3.0 + 6.0 * strength, 0.35)
	SFX.play_small(self, SFX.sfx_mine_break(1), -14.0 + 6.0 * strength, randf_range(0.35, 0.5))
	var view := _view().grow(300)
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if is_instance_valid(o) and not o.freeze and view.has_point(o.global_position):
			o.sleeping = false
			o.linear_velocity += Vector2(randf_range(-90, 90), randf_range(-240, -120)) * strength
			jolts += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is CharacterBody2D and e.has_method("knock") and e.is_on_floor() and view.has_point(e.global_position) and randf() < 0.5:
			e.knock(Vector2(randf_range(-80, 80), -140.0 * strength))
	# dust shaken off the surface in view
	var v := _view()
	for k in 4:
		var x := randf_range(v.position.x, v.end.x)
		FX.burst(get_parent(), Vector2(x, WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE - 2), Color(0.55, 0.45, 0.35, 0.6), 3, 30.0, 0.8, 2.4, -30.0)


## A ceiling cell near the camera (soft rock with air below) cracks loose.
func _break_ceiling() -> void:
	var tm := _tm()
	if tm == null:
		return
	var v := _view()
	for attempt in 40:
		var p := Vector2(randf_range(v.position.x, v.end.x), randf_range(maxf(v.position.y, (WorldGen.SURFACE_ROWS + 3) * WorldGen.TILE_SIZE), v.end.y))
		var c := tm.local_to_map(tm.to_local(p))
		if tm.get_cell_source_id(c) != -1:
			continue
		# up through the air to the ceiling
		for k in 10:
			var up := c + Vector2i.UP
			if tm.get_cell_source_id(up) != -1:
				var t := tm.get_cell_atlas_coords(up).x
				if t in [WorldGen.TILE_HARD, WorldGen.TILE_IRON, WorldGen.TILE_COPPER] or up.y <= WorldGen.SURFACE_ROWS + 1:
					break
				var src := tm.get_cell_source_id(up)
				var at := tm.to_global(tm.map_to_local(up))
				tm.set_cell(up, -1)
				WorldGen.reframe_around(tm, up)
				get_tree().call_group("tile_shading", "mark_dirty", up)
				get_tree().call_group("cave_decor", "tile_cleared", up)
				FX.tile_break(get_parent(), tm, up, src, Vector2i(t, 0), Vector2.DOWN)
				_rocks.append([at, 40.0, FX.TILE_COLORS.get(t, Color(0.5, 0.45, 0.4))])
				falls += 1
				return
			c = up
		return


func _fall_rocks(delta: float) -> void:
	var tm := _tm()
	var done := []
	for r in _rocks:
		r[1] += 900.0 * delta
		var np: Vector2 = r[0] + Vector2(0, r[1] * delta)
		var landed: bool = tm != null and tm.get_cell_source_id(tm.local_to_map(tm.to_local(np + Vector2(0, 6)))) != -1
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("take_damage") and not ("_dying" in e and e._dying):
				var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
				if c.distance_to(np) < 16.0:
					e.take_damage(ROCK_DAMAGE)
					landed = true
		var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
		if p and p.global_position.distance_to(np) < 14.0 and p.has_method("take_damage"):
			p.take_damage(6)
			landed = true
		r[0] = np
		if landed or np.y > 1400:
			FX.burst(get_parent(), np, r[2], 8, 80.0, 0.4, 2.0)
			FX.burst(get_parent(), np, Color(0.5, 0.45, 0.4, 0.5), 4, 30.0, 0.8, 2.6, -30.0)
			SFX.play_small(self, SFX.sfx_ore_knock("ground"), -6.0, 0.6)
			done.append(r)
	for r in done:
		_rocks.erase(r)


func _draw() -> void:
	for r in _rocks:
		var p: Vector2 = to_local(r[0])
		var c: Color = r[2]
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.12, 0.1, 0.09))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), c)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 3)), c.lightened(0.2))
