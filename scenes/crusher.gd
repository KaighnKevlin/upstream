extends Node2D
## Crusher (R): two toothed rollers turning into each other on an iron
## housing. Ore dropped onto the rollers is drawn in and comes out of the
## spout as grit: three light chips per piece, more ammo but lighter hits.
## Anything walking on the rollers gets chewed, so a crusher at the bottom
## of a pit (under a trapdoor) is a grinder. Faster when a gravity wheel
## drives it. Iron takes longer to crush than copper.
## Art: tools/art/gen_crusher.py (4 frames of 52x40, feet at the bottom).

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const TOP := -30.0            # roller tops, from the feet
const SPOUT := Vector2(26, -7)
const EJECT := Vector2(150, -40)
const GRIND := {"copper": 0.5, "iron": 0.9, "gear": 0.7, "shot": 0.6, "spring": 0.6, "scrap": 0.7}
const GRIT_PER := 3
const CHEW_EVERY := 0.25
const CHEW_DAMAGE := 2
const HOLD := 6

var crushed := 0              # pieces ground (tests)
var chewed := 0               # damage ticks dealt (tests)
var _queue := []              # kinds waiting to be ground
var _work := 0.0
var _chew_t := 0.0
var _spr: AnimatedSprite2D
var _intake: Area2D
var _teeth: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/crusher.png")
	sf.set_animation_speed("default", 10.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 52, 0, 52, 40)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-26, -39)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_spr.play()
	# the rollers are a floor: things land on them (and get chewed there)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(42, 26)
	cs.shape = r
	cs.position = Vector2(0, TOP + 13)
	body.add_child(cs)
	add_child(body)
	_intake = _area(Vector2(36, 8), Vector2(0, TOP - 3), 2)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)
	_teeth = _area(Vector2(40, 14), Vector2(0, TOP - 6), 8)


func _area(size: Vector2, at: Vector2, mask: int) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = mask
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = at
	a.add_child(cs)
	add_child(a)
	return a


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


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.has_meta("caught_by"):
		return
	var k = b.get("kind")
	if b.is_in_group("ore") and GRIND.has(k) and _queue.size() < HOLD:
		_queue.append(k)
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -10.0, 0.7)
	elif not (b.is_in_group("ore") and k == "grit"):
		# ingots, flasks, a full hopper: thrown back off the rollers
		(b as RigidBody2D).linear_velocity = Vector2(randf_range(-1, 1) * 120.0, -220.0)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var speed := _rate * Tech.mult("assembly")
	_spr.speed_scale = 0.4 + speed
	if not _queue.is_empty():
		_work += delta * speed
		_spr.position = Vector2(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4))
		if _work >= GRIND.get(_queue[0], 0.6):
			_work = 0.0
			_spr.position = Vector2.ZERO
			_spit(_queue.pop_front())
	# chew whatever stands on the rollers
	_chew_t -= delta * speed
	if _chew_t <= 0:
		_chew_t = CHEW_EVERY
		for e in _teeth.get_overlapping_bodies():
			if e.is_in_group("enemies") and e.has_method("take_damage") and not ("_dying" in e and e._dying):
				e.take_damage(int(round(CHEW_DAMAGE * Tech.mult("grinders"))))
				chewed += 1
				FX.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), TOP), Color(1.0, 0.8, 0.4), 5, 110.0, 0.25, 1.2, -120.0)
				FX.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), TOP - 2), Color(0.6, 0.66, 0.66), 3, 80.0, 0.4, 1.6)
				SFX.play_small(self, SFX.sfx_ore_knock("metal"), -6.0, randf_range(0.5, 0.7))


func _spit(k: String) -> void:
	crushed += 1
	for n in GRIT_PER:
		var g: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		g.kind = "grit"
		g.global_position = global_position + SPOUT + Vector2(0, randf_range(-1.5, 1.5))
		get_tree().current_scene.add_child(g)
		g.linear_velocity = EJECT + Vector2(randf_range(-30, 30), randf_range(-30, 20))
	FX.burst(get_parent(), global_position + SPOUT, Color(0.62, 0.55, 0.5, 0.8), 5, 50.0, 0.4, 1.6)
	SFX.play_small(self, SFX.sfx_mine_hit(), -10.0, 1.2 if k == "copper" else 0.9)
