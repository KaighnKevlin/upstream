extends Node2D
## Ore geyser: a crusted vent on a cave floor (a few per world, hidden in
## the fog). Every so often it rumbles, its mouth glows, and it erupts: a
## column of steam and a spray of copper and iron ore blasted up out of the
## deep. A free, wild ore source: catch the spray with chutes, a tube, a
## hopper. Anything standing on the vent when it blows gets thrown.
## Art: tools/art/gen_geyser.py (3 frames of 44x24: dormant, building,
## erupting).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const MOUTH := Vector2(0, -18)
const QUIET := Vector2(15.0, 25.0)     # seconds between eruptions
const BUILD := 2.5                      # rumbling before it blows
const BURST := 1.4                      # how long it spews
const PIECES := Vector2i(6, 11)

var eruptions := 0                      # tests
var thrown := 0
var _t := 0.0
var _stage := 0
var _spew_t := 0.0
var _left := 0
var _spr: Sprite2D
var _light: PointLight2D
var _steam: CPUParticles2D


func _ready() -> void:
	add_to_group("geysers")
	z_index = 1
	_spr = Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = preload("res://assets/sprites/geyser.png")
	a.region = Rect2(0, 0, 44, 24)
	_spr.texture = a
	_spr.centered = false
	_spr.offset = Vector2(-22, -23)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(128)
	_light.color = Color(1.0, 0.6, 0.3)
	_light.energy = 0.0
	_light.position = MOUTH
	add_child(_light)
	_steam = CPUParticles2D.new()
	_steam.emitting = false
	_steam.amount = 60
	_steam.lifetime = 1.4
	_steam.position = MOUTH
	_steam.direction = Vector2.UP
	_steam.spread = 12.0
	_steam.initial_velocity_min = 180.0
	_steam.initial_velocity_max = 280.0
	_steam.gravity = Vector2(0, 90)
	_steam.damping_min = 60.0
	_steam.damping_max = 100.0
	_steam.scale_amount_min = 2.0
	_steam.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.6, 0.8))
	ramp.add_point(0.2, Color(0.85, 0.85, 0.85, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.7, 0.72, 0.0))
	_steam.color_ramp = ramp
	add_child(_steam)
	_t = randf_range(3.0, QUIET.y)


func _set_stage(s: int) -> void:
	_stage = s
	(_spr.texture as AtlasTexture).region = Rect2(s * 44, 0, 44, 24)


func _physics_process(delta: float) -> void:
	_t -= delta
	match _stage:
		0:
			if _t <= BUILD:
				_set_stage(1)
		1:
			_light.energy = lerpf(_light.energy, 0.6, 0.05)
			if randf() < 0.3:
				FX.burst(get_parent(), global_position + MOUTH + Vector2(randf_range(-4, 4), 0), Color(0.6, 0.55, 0.5, 0.6), 1, 25.0, 0.6, 2.0, -40.0)
			_spr.position = Vector2(randf_range(-0.5, 0.5), 0) if randf() < 0.5 else Vector2.ZERO
			if _t <= 0:
				_erupt()
		2:
			_spew_t -= delta
			if _left > 0 and randf() < 0.45:
				_launch_one()
			if _spew_t <= 0:
				_set_stage(0)
				_steam.emitting = false
				_spr.position = Vector2.ZERO
				_t = randf_range(QUIET.x, QUIET.y)
	if _stage != 1:
		_light.energy = lerpf(_light.energy, 1.2 if _stage == 2 else 0.0, 0.08)


func _erupt() -> void:
	_set_stage(2)
	eruptions += 1
	_spew_t = BURST
	_left = randi_range(PIECES.x, PIECES.y)
	_steam.emitting = true
	var at := global_position + MOUTH
	FX.burst(get_parent(), at, Color(1.0, 0.8, 0.5), 14, 160.0, 0.4, 2.0, -200.0)
	SFX.play_small(self, SFX.sfx_mine_break(1), -6.0, 0.6)
	SFX.play_small(self, SFX.sfx_bounce(), -8.0, 0.5)
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(global_position) < 280.0:
		FX.shake(self, 3.0, 0.3)
	# whatever's standing on the vent gets thrown
	for b in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("player"):
		if b is CharacterBody2D and absf(b.global_position.x - global_position.x) < 16.0 \
				and absf(b.global_position.y - (global_position.y + MOUTH.y)) < 24.0:
			if b.has_method("launch"):
				b.launch(Vector2(randf_range(-60, 60), -520))
			elif b.has_method("knock"):
				b.knock(Vector2(randf_range(-60, 60), -520))
			thrown += 1


func _launch_one() -> void:
	_left -= 1
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "iron" if randf() < 0.35 else "copper"
	o.global_position = global_position + MOUTH + Vector2(randf_range(-3, 3), -4)
	o.linear_velocity = Vector2(randf_range(-110, 110), randf_range(-620, -420))
	o.angular_velocity = randf_range(-10, 10)
	get_parent().add_child(o)


## A few vents on cave floors across the world (below the surface, away
## from the dome, from each other and from salvage caches).
static func scatter(main: Node, tm: TileMapLayer, count := 4) -> void:
	var WG := preload("res://scripts/world_gen.gd")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Vector2] = []
	for attempt in 4000:
		if spots.size() >= count:
			break
		var c := Vector2i(rng.randi_range(6, WG.WORLD_WIDTH - 7), rng.randi_range(WG.SURFACE_ROWS + 10, WG.WORLD_HEIGHT - 3))
		var ok := tm.get_cell_source_id(c + Vector2i.DOWN) != -1
		for dx in [-1, 0, 1]:
			ok = ok and tm.get_cell_source_id(c + Vector2i(dx, 0)) == -1 and tm.get_cell_source_id(c + Vector2i(dx, 1)) != -1
			for dy in range(1, 5):
				ok = ok and tm.get_cell_source_id(c + Vector2i(dx, -dy)) == -1   # headroom for the spray
		if not ok:
			continue
		var at := tm.to_global(tm.map_to_local(c)) + Vector2(0, 8)
		if absf(at.x - 1200.0) < 200.0:
			continue
		var clear := true
		for s in spots:
			clear = clear and s.distance_to(at) > 360.0
		for cch in main.get_tree().get_nodes_in_group("caches"):
			clear = clear and cch.global_position.distance_to(at) > 80.0
		if clear:
			spots.append(at)
	for at in spots:
		var g: Node2D = load("res://scenes/geyser.tscn").instantiate()
		g.global_position = at
		main.add_child(g)
