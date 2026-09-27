extends Node2D
## Firedamp: a pocket of mine gas hanging in a deep cave, a faint green-gold
## haze that glows a little in the dark. Standing in it slowly chokes you.
## Any spark sets it off in a fireball: a shot through it, a blast shell, a
## grenadier's bomb, a powder keg, a meteor, a tesla bolt (ignite_near()).
## The fireball burns everything in it, blows out soft rock around it, and
## lights any other pocket it touches, so one careless shot can rip through
## a whole cave system. A handful are scattered in each world's deep caves.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const RADIUS := 44.0
const BLAST := 80.0             # fireball reach
const DAMAGE := 10
const CHOKE_EVERY := 1.2
const CHAIN_DELAY := 0.15

var lit := false                # tests
var _puffs := []                # [offset, radius, phase]
var _choke := 0.0
var _haze: Node2D
var _glow: PointLight2D


func _ready() -> void:
	add_to_group("firedamp")
	z_index = 3
	for k in 7:
		_puffs.append([Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * RADIUS * 0.6, randf_range(0.45, 0.75) * RADIUS, randf() * TAU])
	_haze = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED    # it glows faintly in the dark
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_haze.material = mat
	_haze.draw.connect(_draw_haze)
	add_child(_haze)
	_glow = PointLight2D.new()
	_glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(64)
	_glow.color = Color(0.7, 0.9, 0.4)
	_glow.energy = 0.25
	_glow.texture_scale = 1.4
	add_child(_glow)


func _draw_haze() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for p in _puffs:
		var off: Vector2 = p[0] + Vector2(sin(t * 0.5 + p[2]), cos(t * 0.4 + p[2])) * 4.0
		var r: float = p[1] * (1.0 + 0.06 * sin(t * 0.9 + p[2]))
		for ring in 4:     # soft edge: rings fading outward, in pixel-ish steps
			var rr := r * (1.0 - ring * 0.2)
			_haze.draw_circle(off, rr, Color(0.32, 0.42, 0.12, 0.05 + ring * 0.018))


func _process(delta: float) -> void:
	if lit:
		return
	_haze.queue_redraw()
	# choking: the prospector standing in it
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(global_position) < RADIUS * 0.85:
		_choke -= delta
		if _choke <= 0:
			_choke = CHOKE_EVERY
			if p.has_method("take_damage"):
				p.take_damage(2)
			SFX.play_small(self, SFX.sfx_clink(), -16.0, 0.4)
	else:
		_choke = 0.3


## Anything that makes a spark or a blast calls this: every pocket within
## `reach` of `at` goes up.
static func ignite_near(tree: SceneTree, at: Vector2, reach: float) -> void:
	for g in tree.get_nodes_in_group("firedamp"):
		if is_instance_valid(g) and not g.lit and g.global_position.distance_to(at) < reach + RADIUS:
			g.ignite()


## A shot passing through (bullet.gd) asks this.
static func shot_hits(tree: SceneTree, at: Vector2) -> bool:
	for g in tree.get_nodes_in_group("firedamp"):
		if is_instance_valid(g) and not g.lit and g.global_position.distance_to(at) < RADIUS * 0.8:
			g.ignite()
			return true
	return false


func ignite() -> void:
	if lit:
		return
	lit = true
	remove_from_group("firedamp")
	var at := global_position
	var parent := get_parent()
	var scene := get_tree().current_scene
	# the fireball: a rolling bloom of flame across the whole pocket
	for p in _puffs:
		FX.burst(parent, at + p[0], Color(1.0, 0.75, 0.3), 12, 160.0, 0.45, 2.6)
		FX.burst(parent, at + p[0], Color(1.0, 0.4, 0.1), 8, 110.0, 0.6, 3.0)
	FX.burst(parent, at, Color(0.28, 0.25, 0.25, 0.7), 16, 50.0, 2.0, 5.0, -40.0)
	FX.shake(self, 7.0, 0.4)
	_haze.visible = false
	_glow.color = Color(1.0, 0.65, 0.3)
	_glow.energy = 2.6
	_glow.texture_scale = 3.0
	var gt := _glow.create_tween()
	gt.tween_property(_glow, "energy", 0.0, 0.6)
	SFX.play(scene, SFX.sfx_mine_break(), 4.0, 0.45)
	SFX.play(scene, SFX.sfx_laser(), 0.0, 0.3)
	_crater(at)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if c.distance_to(at) < BLAST:
			e.take_damage(DAMAGE)
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock((c - at).normalized() * 260.0 + Vector2(0, -200))
	var pl := scene.get_node_or_null("Player") as Node2D
	if pl and pl.global_position.distance_to(at) < BLAST:
		if pl.has_method("take_damage"):
			pl.take_damage(12)
		if pl.has_method("launch"):
			pl.launch((pl.global_position - at).normalized() * 380.0 + Vector2(0, -220))
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(at) < BLAST * 1.3:
			if o.get("kind") in ["shell", "bomb"]:
				o.call_deferred("explode")
			else:
				o.sleeping = false
				o.linear_velocity += (o.global_position - at).normalized() * 300.0 + Vector2(0, -120)
	for kg in get_tree().get_nodes_in_group("kegs"):
		if kg.center().distance_to(at) < BLAST:
			kg.call_deferred("detonate")
	# the flame front runs on into the next pocket
	var tree := get_tree()
	tree.create_timer(CHAIN_DELAY).timeout.connect(func(): ignite_near(tree, at, BLAST))
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(queue_free)


func _crater(at: Vector2) -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var c0 := tm.local_to_map(tm.to_local(at))
	var r := int(RADIUS / 16.0) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r - 1, r + 2):
			var c := c0 + Vector2i(dx, dy)
			if Vector2(dx * 0.75, dy).length() > r + 0.3:
				continue
			var t := tm.get_cell_atlas_coords(c).x
			if tm.get_cell_source_id(c) == -1 or t in [WorldGen.TILE_HARD, WorldGen.TILE_IRON, WorldGen.TILE_COPPER] or c.x < 1 or c.x >= WorldGen.WORLD_WIDTH - 1 or c.y < WorldGen.SURFACE_ROWS + 4:
				continue
			if randf() < 0.35:      # a ragged edge, not a perfect ellipse
				continue
			var src := tm.get_cell_source_id(c)
			tm.set_cell(c, -1)
			WorldGen.reframe_around(tm, c)
			get_tree().call_group("tile_shading", "mark_dirty", c)
			get_tree().call_group("cave_decor", "tile_cleared", c)
			FX.tile_break(get_parent(), tm, c, src, Vector2i(t, 0), (tm.to_global(tm.map_to_local(c)) - at).normalized())


## Pockets in the deep caves: open air around them, below the upper
## caves, away from the dome, spread apart.
static func scatter(main: Node, tm: TileMapLayer, count := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Vector2] = []
	for attempt in 4000:
		if spots.size() >= count:
			break
		var c := Vector2i(rng.randi_range(4, WorldGen.WORLD_WIDTH - 5), rng.randi_range(WorldGen.SURFACE_ROWS + 22, WorldGen.WORLD_HEIGHT - 5))
		var open := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				open += 1 if tm.get_cell_source_id(c + Vector2i(dx, dy)) == -1 else 0
		if open < 22:
			continue
		var at := tm.to_global(tm.map_to_local(c))
		if absf(at.x - 1200.0) < 200.0:
			continue
		var ok := true
		for s in spots:
			ok = ok and s.distance_to(at) > 200.0
		if ok:
			spots.append(at)
	for at in spots:
		var g: Node2D = load("res://scenes/firedamp.tscn").instantiate()
		g.global_position = at
		main.add_child(g)
