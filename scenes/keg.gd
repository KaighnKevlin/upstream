extends Node2D
## Powder keg: a barrel of blasting powder that sits on the ground and
## waits. It goes off when something sets it off:
##   - ore (or a blast shell, a spring...) slamming into it fast
##   - a shot: your gun or an enemy's
##   - another blast close by (shells, meteors, other kegs: chain reactions)
##   - an enemy blundering into it lights the fuse (FUSE seconds)
## The blast is big: it wrecks walkers, flings everything loose (ore,
## enemies, you), sets off kegs and shells nearby, and blows a crater in
## soft rock, so a keg is also a way to dig a ditch in a hurry.
## Art: tools/art/gen_keg.py (2 frames of 22x26: resting, lit).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const RADIUS := 92.0
const DAMAGE := 16
const IMPACT := 260.0          # ore at least this fast sets it off
const FUSE := 1.4
const CHAIN := 130.0           # kegs this close go up too, a beat later
const HIT := 13.0              # shot radius around the barrel's middle

var fuse := -1.0               # counting down once lit
var blown := false             # tests
var _spr: AnimatedSprite2D
var _spark := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/keg.png")
	for i in 2:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 22, 0, 22, 26)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-11, -25)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("kegs")
	# solid: ore bounces off it, walkers bump into it
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 22)
	cs.shape = r
	cs.position = Vector2(0, -11)
	body.add_child(cs)
	add_child(body)
	var sense := Area2D.new()
	sense.collision_layer = 0
	sense.collision_mask = 2 | 8          # ore, enemies
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(22, 26)
	cs2.shape = r2
	cs2.position = Vector2(0, -12)
	sense.add_child(cs2)
	add_child(sense)
	sense.body_entered.connect(_on_touch)


func center() -> Vector2:
	return global_position + Vector2(0, -12)


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


func _on_touch(b: Node) -> void:
	if blown:
		return
	if b is RigidBody2D and b.is_in_group("ore"):
		if (b as RigidBody2D).linear_velocity.length() >= IMPACT or b.get("_prev_speed") != null and float(b.get("_prev_speed")) >= IMPACT:
			detonate()
	elif b.is_in_group("enemies"):
		light()


## Light the fuse (no-op if it's already burning).
func light() -> void:
	if fuse < 0 and not blown:
		fuse = FUSE
		_spr.frame = 1
		SFX.play_small(self, SFX.sfx_clink(), -6.0, 2.0)


func _process(delta: float) -> void:
	if fuse < 0 or blown:
		return
	fuse -= delta
	_spark -= delta
	if _spark <= 0:
		_spark = 0.05
		FX.burst(get_parent(), global_position + Vector2(0, -25), Color(1.0, 0.8, 0.35), 2, 50.0, 0.25, 1.2, -60.0)
	_spr.modulate = Color.WHITE if int(fuse * 10) % 2 else Color(1.4, 1.1, 1.0)
	if fuse <= 0:
		detonate()


## Shots (bullet.gd, enemy_bullet.gd) ask this: a keg the shot is inside goes up.
static func shot_hits(tree: SceneTree, at: Vector2) -> bool:
	for k in tree.get_nodes_in_group("kegs"):
		if is_instance_valid(k) and not k.blown and k.center().distance_to(at) < HIT:
			k.detonate()
			return true
	return false


## Something hit it hard enough: it goes up at once.
func detonate() -> void:
	if blown:
		return
	blown = true
	var at := center()
	var parent := get_parent()
	var scene := get_tree().current_scene
	FX.burst(parent, at, Color(1.0, 0.9, 0.5), 34, 320.0, 0.4, 2.6)
	FX.burst(parent, at, Color(1.0, 0.5, 0.15), 24, 220.0, 0.6, 3.0)
	FX.burst(parent, at, Color(0.3, 0.28, 0.3, 0.7), 18, 60.0, 1.8, 5.0, -50.0)
	FX.debris(parent, at, 10, 260.0, false)
	FX.shake(self, 9.0, 0.45)
	var l := PointLight2D.new()
	l.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
	l.color = Color(1.0, 0.7, 0.35)
	l.energy = 2.6
	l.texture_scale = 2.8
	l.global_position = at
	parent.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "energy", 0.0, 0.45)
	lt.tween_callback(l.queue_free)
	SFX.play(scene, SFX.sfx_mine_break(), 4.0, 0.5)
	SFX.play(scene, SFX.sfx_turret_fire(), 2.0, 0.4)
	_crater(at)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var d := c.distance_to(at)
		var reach: float = RADIUS + (e.hit_radius() if e.has_method("hit_radius") else 10.0) * 0.5
		if d < reach:
			e.take_damage(maxi(3, int(DAMAGE * (1.0 - d / (reach * 1.4)))))
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock((c - at).normalized() * 380.0 * (1.0 - d / (reach * 1.3)) + Vector2(0, -320))
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.has_meta("store_material"):
			continue
		var d: float = o.global_position.distance_to(at)
		if o.get("kind") == "shell" and d < RADIUS * 0.9:
			o.call_deferred("explode")
		elif d < RADIUS * 1.6:
			o.sleeping = false
			o.linear_velocity += (o.global_position - at).normalized() * 520.0 * (1.0 - d / (RADIUS * 1.6)) + Vector2(0, -140)
	for k in get_tree().get_nodes_in_group("kegs"):
		if k != self and is_instance_valid(k) and not k.blown and k.center().distance_to(at) < CHAIN:
			k.get_tree().create_timer(0.12 + randf() * 0.1).timeout.connect(k.detonate)
	var p := scene.get_node_or_null("Player") as Node2D
	if p:
		var d := p.global_position.distance_to(at)
		if d < RADIUS:
			if d < RADIUS * 0.6 and p.has_method("take_damage"):
				p.take_damage(12)
			if p.has_method("launch"):
				p.launch((p.global_position - at).normalized() * 420.0 + Vector2(0, -260))
	remove_from_group("kegs")
	queue_free()


## Soft rock around the blast is blown out (never hard rock or ore veins,
## never under the dome).
func _crater(at: Vector2) -> void:
	var scene := get_tree().current_scene
	var tm := scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	if dome and absf(dome.global_position.x - at.x) < 150.0:
		return
	var c0 := tm.local_to_map(tm.to_local(at))
	for dy in range(-2, 4):
		for dx in range(-2, 3):
			if absi(dx) + absi(dy - 1) > 2:
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
			FX.tile_break(get_parent(), tm, c, src, Vector2i(t, 0), (tm.to_global(tm.map_to_local(c)) - at).normalized())
