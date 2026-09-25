extends Node2D
## A meteor: a burning chunk of ore falling out of the sky at a slant during
## a meteor shower. Where it lands it punches a small crater (soft rock
## only, never ore veins, never near the dome), bursts into loose ore (copper, sometimes
## iron) and hurts and shoves anything close. Free ore, and chaos.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const SPLASH := 40.0
const DAMAGE := 5

var velocity := Vector2(-120, 420)
var iron := false
var size := 1.0
var _trail := 0.0
var _spin := 0.0


func _ready() -> void:
	z_index = 4
	var l := PointLight2D.new()
	l.texture = LightTextures.create_radial_light(96)
	l.color = Color(1.0, 0.6, 0.25)
	l.energy = 1.1
	l.texture_scale = 1.2 * size
	add_child(l)


func _physics_process(delta: float) -> void:
	velocity.y += 200.0 * delta
	global_position += velocity * delta
	_spin += delta * 6.0
	_trail -= delta
	if _trail <= 0:
		_trail = 0.02
		FX.burst(get_parent(), global_position, Color(1.0, 0.7, 0.3, 0.9), 2, 30.0, 0.35, 2.0 * size, 0.0)
		FX.burst(get_parent(), global_position - velocity.normalized() * 6.0, Color(0.35, 0.3, 0.32, 0.6), 1, 15.0, 1.0, 2.6 * size, -20.0)
	queue_redraw()
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if (tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position))) != -1) or global_position.y > 1400:
		_impact(tm)


func _impact(tm: TileMapLayer) -> void:
	var at := global_position
	var scene := get_tree().current_scene
	FX.shake(self, 3.0 * size, 0.25)
	FX.burst(get_parent(), at, Color(1.0, 0.75, 0.35), int(18 * size), 190.0, 0.45, 2.2)
	FX.burst(get_parent(), at, Color(0.5, 0.42, 0.35), int(14 * size), 120.0, 0.7, 2.6, 250.0)
	FX.burst(get_parent(), at, Color(0.35, 0.3, 0.32, 0.6), 6, 40.0, 1.4, 3.5, -40.0)
	SFX.play(scene, SFX.sfx_mine_break(), -2.0, 0.7)
	# crater: soft rock only, and never under the dome
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	var near_dome := dome != null and absf(dome.global_position.x - at.x) < 140.0
	if tm and not near_dome:
		var c0 := tm.local_to_map(tm.to_local(at))
		var r := 0 if size < 1.2 else 1          # a big one takes a small diamond, a small one a single tile
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) + absi(dy) > r:
					continue
				var c := c0 + Vector2i(dx, dy)
				var t := tm.get_cell_atlas_coords(c).x
				if tm.get_cell_source_id(c) == -1 or t in [WorldGen.TILE_HARD, WorldGen.TILE_IRON, WorldGen.TILE_COPPER] or c.x < 0 or c.x >= WorldGen.WORLD_WIDTH:
					continue
				var src := tm.get_cell_source_id(c)
				tm.set_cell(c, -1)
				WorldGen.reframe_around(tm, c)
				get_tree().call_group("tile_shading", "mark_dirty", c)
				get_tree().call_group("cave_decor", "tile_cleared", c)
				FX.tile_break(get_parent(), tm, c, src, Vector2i(t, 0), -velocity.normalized())
	# hurt and shove what's close
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if c.distance_to(at) < SPLASH * size:
			e.take_damage(DAMAGE)
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock((c - at).normalized() * 220.0 + Vector2(0, -160))
	var p := scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(at) < SPLASH * 0.6 and p.has_method("take_damage"):
		p.take_damage(8)
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(at) < SPLASH * 1.4:
			o.sleeping = false
			o.linear_velocity += (o.global_position - at).normalized() * 200.0 + Vector2(0, -150)
	# it bursts into loose ore
	for k in int(2 + size * 2):
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if iron and k % 2 == 0 else "copper"
		o.global_position = at + Vector2(randf_range(-6, 6), -10)
		o.linear_velocity = Vector2(randf_range(-180, 180), randf_range(-320, -160))
		get_parent().add_child.call_deferred(o)
	queue_free()


func _draw() -> void:
	var s := size
	var base := Color(0.45, 0.4, 0.42) if iron else Color(0.6, 0.38, 0.22)
	# a glowing, tumbling rock with a hot leading edge
	var pts := PackedVector2Array()
	for k in 7:
		var a := _spin + k * TAU / 7.0
		pts.append(Vector2.from_angle(a) * (5.0 + (k % 3)) * s)
	draw_colored_polygon(pts, Color(0.18, 0.12, 0.1))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.75)
	draw_colored_polygon(inner, base)
	var lead := velocity.normalized() * 3.0 * s
	draw_circle(lead, 3.2 * s, Color(1.0, 0.55, 0.15, 0.9))
	draw_circle(lead * 1.2, 1.8 * s, Color(1.0, 0.9, 0.6))
