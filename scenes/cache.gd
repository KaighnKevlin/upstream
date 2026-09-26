extends Node2D
## A salvage cache: a strapped brass strongbox left in a cave (a handful are
## hidden around each world, in the fog). Walk into it and the lid springs
## open, spilling a random haul: science flasks, blast shells, springs,
## gears, ingots, scrap. Once opened it stays open, empty.
## Art: tools/art/gen_cache.py (2 frames of 36x28: closed, open).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

# what a haul can hold: [kind (ore kinds; "ingot:x" for ingots), weight]
const LOOT := [["flask", 3], ["shell", 3], ["spring", 3], ["gear", 3], ["ingot:iron", 2], ["ingot:copper", 2], ["scrap", 2]]

var opened := false
var haul := 0            # tests
var _spr: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group("caches")
	z_index = 1
	_spr = Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = preload("res://assets/sprites/cache.png")
	a.region = Rect2(0, 0, 36, 28)
	_spr.texture = a
	_spr.centered = false
	_spr.offset = Vector2(-18, -27)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(64)
	_light.color = Color(1.0, 0.75, 0.4)
	_light.energy = 0.35
	_light.position = Vector2(0, -12)
	add_child(_light)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 32        # the player
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 20)
	cs.shape = r
	cs.position = Vector2(0, -10)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_touch, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	if not opened:
		_light.energy = 0.3 + 0.12 * sin(Time.get_ticks_msec() * 0.004)


func _on_touch(_b) -> void:
	open()


func open() -> void:
	if opened:
		return
	opened = true
	(_spr.texture as AtlasTexture).region = Rect2(36, 0, 36, 28)
	FX.pop(_spr, Vector2(1.2, 0.85), 0.18)
	FX.burst(get_parent(), global_position + Vector2(0, -14), Color(1.0, 0.85, 0.45), 18, 120.0, 0.6, 1.8, -60.0)
	SFX.play(self, SFX.sfx_ammo_received(), 0.0, 0.8)
	SFX.play(self, SFX.sfx_clink(), -2.0, 0.7)
	var total := 0
	for l in LOOT:
		total += int(l[1])
	var n := randi_range(6, 10)
	for k in n:
		var pick := randi() % total
		var kind := ""
		for l in LOOT:
			pick -= int(l[1])
			if pick < 0:
				kind = l[0]
				break
		var b: RigidBody2D
		if kind.begins_with("ingot:"):
			b = preload("res://scenes/ingot.tscn").instantiate()
			b.kind = kind.get_slice(":", 1)
		else:
			b = preload("res://scenes/ore.tscn").instantiate()
			b.kind = kind
			b.lifetime = 60.0          # a haul waits for you to collect it
		b.global_position = global_position + Vector2(randf_range(-8, 8), -16)
		b.linear_velocity = Vector2(randf_range(-150, 150), randf_range(-300, -170))
		get_parent().add_child.call_deferred(b)
		haul += 1
	var main := get_tree().current_scene
	if main.has_method("_show_banner"):
		main._show_banner("SALVAGE CACHE", "%d pieces of salvage" % n)
	var t := create_tween()
	t.tween_property(_light, "energy", 1.2, 0.1)
	t.tween_property(_light, "energy", 0.0, 1.2)


## Scatters caches on cave floors across the world: open air above, rock
## below, well away from the dome and from each other, below the surface.
static func scatter(main: Node, tm: TileMapLayer, count := 8) -> void:
	var WG := preload("res://scripts/world_gen.gd")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Vector2] = []
	for attempt in 4000:
		if spots.size() >= count:
			break
		var c := Vector2i(rng.randi_range(4, WG.WORLD_WIDTH - 5), rng.randi_range(WG.SURFACE_ROWS + 9, WG.WORLD_HEIGHT - 3))
		if tm.get_cell_source_id(c) != -1 or tm.get_cell_source_id(c + Vector2i.UP) != -1 \
				or tm.get_cell_source_id(c + Vector2i.DOWN) == -1:
			continue
		if tm.get_cell_source_id(c + Vector2i(-1, 1)) == -1 or tm.get_cell_source_id(c + Vector2i(1, 1)) == -1:
			continue   # wants a flat bit of floor
		var at := tm.to_global(tm.map_to_local(c)) + Vector2(0, 8)
		if absf(at.x - 1200.0) < 160.0:
			continue
		var ok := true
		for s in spots:
			if s.distance_to(at) < 260.0:
				ok = false
				break
		if ok:
			spots.append(at)
	for at in spots:
		var cache: Node2D = load("res://scenes/cache.tscn").instantiate()
		cache.global_position = at
		main.add_child(cache)
