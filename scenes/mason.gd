extends CharacterBody2D
## Clockwork mason: a bricklayer with a hod of bricks on its back. At the lip
## of a ditch it stops and lobs bricks in, filling the ditch layer by layer
## from the bottom (lowest cell first, nearest first), so your pit gets
## shallower with every throw and, given enough bricks, level with the
## ground. The bricks are real stone tiles: the ditch stays filled after the
## mason is gone, until you dig it out again. It won't brick over anything
## standing in the ditch; it waits for the cell to clear. Out of bricks, it
## walks on like anyone else.
## Art: tools/art/gen_mason.py (10 frames of 48x44: 6 walk, 4 lob).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const SPEED := 28.0
const GRAVITY := 980.0
const BRICKS := 14
const LOB_EVERY := 0.9
const MAX_GAP := 10
const MAX_DEPTH := 12
const MAX_HP := 8
const HAND := Vector2(10, -26)

var hp := MAX_HP
var damage := 8
var direction := -1.0
var bricks := BRICKS
var laid := 0                 # tests
var _dying := false
var _laying := false
var _lob_t := 0.0
var _check := 0.0
var _knock_t := 0.0
var _spr: AnimatedSprite2D
static var _pending := {}     # cells a brick is in flight to (shared by all masons)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 30)
	cs.shape = r
	cs.position = Vector2(0, -15)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/mason.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 9.0, true], ["lob", [6, 7, 8, 9], 10.0, false], ["idle", [9], 1.0, true]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 48, 0, 48, 44)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-20, -42)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	_spr.frame_changed.connect(_on_frame)
	add_child(_spr)
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D if scene else null
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -20)


func hit_radius() -> float:
	return 13.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v
		_knock_t = 0.4


func _tm() -> TileMapLayer:
	return get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif _knock_t <= 0:
		velocity.y = 0
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
		move_and_slide()
		return
	_lob_t -= delta
	if bricks > 0 and is_on_floor():
		_check -= delta
		if _check <= 0:
			_check = 0.15
			_laying = _pick_cell() != Vector2i(-1, -1)
	else:
		_laying = false
	if _laying:
		velocity.x = 0
		if _lob_t <= 0:
			_lob_t = LOB_EVERY
			_spr.play("lob")
		elif not (_spr.animation == "lob" and _spr.is_playing()):
			_spr.play("idle")
	else:
		velocity.x = SPEED * direction
		_spr.play("walk")
		# the edge of a pit with nothing to brick: climbs out like a soldier would
		if is_on_wall():
			velocity.y = -28.0
	_spr.flip_h = direction < 0
	_spr.offset.x = -20 if direction > 0 else -28
	move_and_slide()


## The ditch ahead, filled lowest-first and nearest-first. (-1, -1) when
## there is no ditch at its feet (or it's too deep to fill).
func _pick_cell() -> Vector2i:
	var tm := _tm()
	var none := Vector2i(-1, -1)
	if tm == null:
		return none
	var ground := tm.local_to_map(tm.to_local(global_position + Vector2(0, 4)))
	var nose := Vector2i(tm.local_to_map(tm.to_local(global_position + Vector2(direction * 12.0, 4.0))).x, ground.y)
	if tm.get_cell_source_id(nose) != -1 or tm.get_cell_source_id(nose + Vector2i.UP) != -1:
		return none
	if preload("res://scenes/trapdoor.gd").covers(get_tree(), global_position.x + direction * 12.0, global_position.y):
		return none                     # turf over there: nothing to fill
	var dir := int(direction)
	var cols := []
	for k in MAX_GAP:
		var c := Vector2i(nose.x + dir * k, ground.y)
		if tm.get_cell_source_id(c) != -1:
			break
		cols.append(c.x)
	if cols.size() >= MAX_GAP:
		cols = [nose.x]                 # no far side in reach: fill the near column only
	var best := none
	var best_row := -1
	for x in cols:
		var row := ground.y
		while row - ground.y < MAX_DEPTH and tm.get_cell_source_id(Vector2i(x, row + 1)) == -1:
			row += 1
		if row - ground.y >= MAX_DEPTH:
			continue                    # a shaft, not a ditch
		# skip cells a brick is already flying to: aim at the next one up
		while _pending.has(Vector2i(x, row)) and row >= ground.y:
			row -= 1
		if row < ground.y:
			continue
		if row > best_row:
			best_row = row
			best = Vector2i(x, row)
	return best


func _on_frame() -> void:
	if _spr.animation != "lob" or _spr.frame != 2 or _dying or bricks <= 0:
		return
	var cell := _pick_cell()
	if cell == Vector2i(-1, -1):
		return
	bricks -= 1
	_pending[cell] = true
	var tm := _tm()
	var from := global_position + Vector2(HAND.x * direction, HAND.y)
	var to := tm.to_global(tm.map_to_local(cell))
	var b := Sprite2D.new()
	b.texture = preload("res://assets/sprites/brick.png")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.z_index = 3
	b.global_position = from
	get_parent().add_child(b)
	var apex := minf(from.y, to.y) - 24.0
	var t := b.create_tween()
	t.tween_method(func(u: float):
		var p := from.lerp(to, u)
		p.y = lerpf(lerpf(from.y, apex, u), lerpf(apex, to.y, u), u)
		b.global_position = p
		b.rotation = u * TAU * direction, 0.0, 1.0, 0.4)
	t.tween_callback(func():
		b.queue_free()
		_land(cell))
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 0.8)


func _land(cell: Vector2i) -> void:
	_pending.erase(cell)
	var tm := _tm()
	if tm == null or tm.get_cell_source_id(cell) != -1:
		if not _dying:
			bricks += 1        # beaten to it: the brick goes back in the hod
		return
	var at := tm.to_global(tm.map_to_local(cell))
	if _occupied(at):
		# something's standing there: the brick clatters off, it'll try again
		FX.burst(get_parent(), at, Color(0.7, 0.4, 0.28), 5, 60.0, 0.3, 1.5)
		if not _dying:
			bricks += 1
		return
	WorldGen.set_tile(tm, cell, WorldGen.TILE_STONE)
	get_tree().call_group("tile_shading", "mark_dirty", cell)
	laid += 1
	FX.burst(get_parent(), at, Color(0.62, 0.55, 0.5), 6, 50.0, 0.35, 1.8)
	SFX.play_small(self, SFX.sfx_ore_knock("stone"), -6.0, randf_range(0.6, 0.75))


func _occupied(at: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(15, 15)
	q.shape = r
	q.transform = Transform2D(0.0, at)
	q.collision_mask = 2 | 8 | 32
	q.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount, self)
	FX.burst(get_parent(), hit_center(), Color(0.85, 0.72, 0.45), 5, 80.0, 0.3, 1.5)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit())
		return
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 2)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.6, 0.3), 12, 140.0, 0.4, 2.0)
	FX.debris(get_parent(), hit_center(), 6, 170.0, false)
	# the hod spills its last bricks
	FX.burst(get_parent(), hit_center() + Vector2(-direction * 8, 0), Color(0.7, 0.4, 0.28), mini(bricks, 10) + 3, 120.0, 0.6, 2.0, 200.0)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(queue_free)
