extends Node2D
## Clockwork sapper: a brass drill-mole. It doesn't walk to the dome, it
## goes under: it drills down from the edge of the map, bores a tunnel a
## few tiles beneath the surface toward the dome, and bursts up at its rim
## for a big hit. You can see it coming: dust puffs from the ground above
## it and it rumbles. It carves real tunnels (ore veins it cuts through
## spill their ore into the tunnel), so its path is open to whatever you can
## get down there: ore rolling along the tunnel, a flamer at a shaft mouth,
## a tesla coil (lightning finds it through the rock). Guns that lob ore
## (funnel turrets, the flamer's cone) can't see it while it's buried.
## Art: tools/art/gen_sapper.py (6 frames of 44x30, facing right).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

enum State { DIVE, TUNNEL, RISE, DYING }

const SPEED := 50.0              # through open tunnel; rock has to be ground away first
const DIG_TIME := {              # seconds to grind out one tile, by tile type
	WorldGen.TILE_DIRT: 0.22, WorldGen.TILE_GRASS: 0.22, WorldGen.TILE_STONE: 0.4,
	WorldGen.TILE_DEEP_STONE: 0.55, WorldGen.TILE_IRON: 0.5, WorldGen.TILE_COPPER: 0.45,
	WorldGen.TILE_HARD: 1.3,
}
const DEPTH_ROWS := 5            # tunnels this many rows under the surface
const MAX_HP := 12
const RUMBLE_EVERY := 0.45

var hp := MAX_HP
var damage := 18                 # to the dome when it breaches
var velocity := Vector2.ZERO     # turrets lead on this
var direction := -1.0
var buried := true               # hidden from turrets that aim (funnel, flamer)
var dug := 0                     # tiles carved (tests)
var _dying := false
var _state := State.DIVE
var _heading := Vector2(-0.6, 0.8).normalized()
var _dig := 0.0
var _rumble := 0.0
var _tunnel_y := 0.0
var _breach_x := 1200.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	z_index = 3
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 14.0)
	var tex := preload("res://assets/sprites/sapper.png")
	for i in 6:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 44, 0, 44, 30)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-20, -13)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play()
	add_child(_spr)
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D if scene else null
	var dome_x := dome.global_position.x if dome else 1200.0
	direction = signf(dome_x - global_position.x) if absf(dome_x - global_position.x) > 1 else -1.0
	# comes up at the dome's rim, on the side it tunnels in from
	_breach_x = dome_x - direction * 30.0
	_heading = Vector2(direction * 0.6, 0.8).normalized()
	_tunnel_y = (WorldGen.SURFACE_ROWS + DEPTH_ROWS) * WorldGen.TILE_SIZE + WorldGen.TILE_SIZE * 0.5


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 11.0


func _tm() -> TileMapLayer:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("TileMapLayer") as TileMapLayer if scene else null


func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		return
	var tm := _tm()
	match _state:
		State.DIVE:
			if global_position.y >= _tunnel_y:
				_state = State.TUNNEL
				_heading = Vector2(direction, 0)
		State.TUNNEL:
			if absf(global_position.x - _breach_x) < 3.0:
				_state = State.RISE
				_heading = Vector2.UP
		State.RISE:
			if tm and global_position.y < WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE - 2 \
					and _solid_at(tm, global_position + Vector2(0, -8)) < 0:
				_breach()
				return
	var moved := _advance(tm, delta)
	velocity = _heading * SPEED if moved else Vector2.ZERO
	# crawling through a cave: it drops to the floor and tunnels on from there
	if _state == State.TUNNEL and tm and moved and _solid_at(tm, global_position + Vector2(0, 12)) < 0 \
			and _solid_at(tm, global_position + Vector2(0, 26)) < 0:
		global_position.y += 70.0 * delta
	buried = global_position.y > WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE + 10
	# face the way it's drilling, never upside down
	rotation = _heading.angle() if _heading.x >= 0 or _state == State.RISE else _heading.angle() + PI
	_spr.flip_h = _heading.x < 0 and _state != State.RISE
	_spr.speed_scale = 1.0 if moved else 1.8
	_rumble -= delta
	if _rumble <= 0 and buried:
		_rumble = RUMBLE_EVERY
		_puff_surface(tm)


## Moves along the heading, grinding away the tiles ahead first. Returns
## whether it moved (false while it is chewing through rock).
func _advance(tm: TileMapLayer, delta: float) -> bool:
	if tm == null:
		global_position += _heading * SPEED * delta
		return true
	var ahead := global_position + _heading * 13.0
	var side := _heading.orthogonal()
	var cells := {}
	for o in [-9.0, 0.0, 9.0]:
		var c := tm.local_to_map(tm.to_local(ahead + side * o))
		if tm.get_cell_source_id(c) != -1 and c.x >= 0 and c.x < WorldGen.WORLD_WIDTH:
			cells[c] = true
	if cells.is_empty():
		_dig = 0.0
		global_position += _heading * SPEED * delta
		return true
	var need := 0.0
	for c in cells:
		need = maxf(need, DIG_TIME.get(tm.get_cell_atlas_coords(c).x, 0.4))
	_dig += delta
	_spr.position = Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))   # judder while grinding
	if _dig >= need:
		_dig = 0.0
		_spr.position = Vector2.ZERO
		for c in cells:
			_carve(tm, c)
	return false


func _carve(tm: TileMapLayer, c: Vector2i) -> void:
	var src := tm.get_cell_source_id(c)
	var atlas := tm.get_cell_atlas_coords(c)
	var at := tm.to_global(tm.map_to_local(c))
	tm.set_cell(c, -1)
	WorldGen.reframe_around(tm, c)
	dug += 1
	FX.burst(get_parent(), at, FX.TILE_COLORS.get(atlas.x, Color.GRAY), 4, 70.0, 0.35)
	FX.tile_break(get_parent(), tm, c, src, atlas, -_heading)
	get_tree().call_group("tile_shading", "mark_dirty", c)
	get_tree().call_group("cave_decor", "tile_cleared", c)
	# a vein it cuts through spills its ore into the tunnel behind it
	if atlas.x == WorldGen.TILE_IRON or atlas.x == WorldGen.TILE_COPPER:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if atlas.x == WorldGen.TILE_IRON else "copper"
		o.global_position = at
		get_tree().current_scene.add_child.call_deferred(o)
	if dug % 3 == 0:
		SFX.play_small(self, SFX.sfx_mine_hit(), -14.0, randf_range(0.55, 0.7))


func _solid_at(tm: TileMapLayer, p: Vector2) -> int:
	return tm.get_cell_source_id(tm.local_to_map(tm.to_local(p)))


## A telltale dust puff where the ground is above it.
func _puff_surface(tm: TileMapLayer) -> void:
	if tm == null:
		return
	var col := tm.local_to_map(tm.to_local(global_position)).x
	for row in range(0, WorldGen.WORLD_HEIGHT):
		if tm.get_cell_source_id(Vector2i(col, row)) != -1:
			var top := tm.to_global(tm.map_to_local(Vector2i(col, row))) + Vector2(randf_range(-6, 6), -8)
			if top.y < global_position.y - 20:
				FX.burst(get_parent(), top, Color(0.55, 0.45, 0.33, 0.8), 4, 35.0, 0.6, 1.8, -40.0)
			return


func _breach() -> void:
	_state = State.DYING
	_dying = true
	remove_from_group("enemies")
	var at := global_position
	FX.shake(self, 6.0, 0.35)
	FX.burst(get_parent(), at, Color(0.55, 0.45, 0.33), 26, 190.0, 0.7, 2.5, 200.0)
	FX.burst(get_parent(), at, Color(1.0, 0.75, 0.35), 12, 140.0, 0.4, 2.0)
	FX.debris(get_parent(), at, 6, 210.0, false)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break())
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	var scene := get_tree().current_scene
	if scene.has_method("damage_dome"):
		scene.damage_dome(damage)
	queue_free()


func knock(_v: Vector2) -> void:
	pass   # anchored in the rock: pushes don't move it


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount, self)
	FX.burst(get_parent(), global_position, Color(0.85, 0.72, 0.45), 5, 80.0, 0.3, 1.5)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit())
		return
	_dying = true
	_state = State.DYING
	remove_from_group("enemies")
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	preload("res://scenes/ore.gd").spill(get_parent(), global_position, 2)
	FX.burst(get_parent(), global_position, Color(1.0, 0.75, 0.35), 14, 150.0, 0.4, 2.0)
	FX.debris(get_parent(), global_position, 7, 180.0, false)
	# the drill bit's gears scatter
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
