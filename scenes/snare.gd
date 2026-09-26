extends Node2D
## Snare: a clockwork bear trap. Set, its jaws lie flat either side of a
## brass pressure pan. A walker that steps on the pan gets snapped (a bite
## of damage) and held fast for HOLD seconds, a sitting duck for your
## turrets; titans tear free in half the time. Ore landing on the pan trips
## it too, and the jaws flip it high into the air: a spring you can time.
## After it lets go, its spring drums wind the jaws back open (REWIND).
## Fliers, the prospector and anything already dying walk over it.
## Art: tools/art/gen_snare.py (4 frames of 36x20: set, snapping, shut,
## winding).

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

enum State { SET, SHUT, REWIND }

const HOLD := 3.0
const REWIND := 2.5
const BITE := 3
const FLIP := Vector2(0, -640)     # what the jaws do to ore

var snapped := 0                   # tests
var flipped := 0
var _state := State.SET
var _t := 0.0
var _victim: CharacterBody2D = null
var _spr: AnimatedSprite2D


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/snare.png")
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 36, 0, 36, 20)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-18, -19)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	var pan := Area2D.new()
	pan.collision_layer = 0
	pan.collision_mask = 2 | 8           # ore, walkers
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 10)
	cs.shape = r
	cs.position = Vector2(0, -5)
	pan.add_child(cs)
	add_child(pan)
	pan.body_entered.connect(_on_pan, CONNECT_DEFERRED)


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


func _on_pan(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if _state != State.SET or not is_instance_valid(b):
		return
	if b is RigidBody2D:
		if b.freeze or b.has_meta("caught_by"):
			return
		_snap()
		b.sleeping = false
		b.linear_velocity = FLIP + Vector2(randf_range(-40, 40), 0)
		flipped += 1
		_state = State.REWIND
		_t = REWIND
	elif b is CharacterBody2D and b.is_in_group("enemies") and "_knock_t" in b and not ("_dying" in b and b._dying):
		_snap()
		_victim = b
		_state = State.SHUT
		var heavy: bool = b.get("enemy_type") == 0    # titans
		_t = HOLD * (0.5 if heavy else 1.0)
		snapped += 1
		if b.has_method("take_damage"):
			b.take_damage(BITE)


func _snap() -> void:
	_spr.frame = 1
	get_tree().create_timer(0.05).timeout.connect(func(): if _state != State.SET: _spr.frame = 2)
	SFX.play(self, SFX.sfx_clink(), -2.0, 0.55)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -4.0, 0.7)
	FX.burst(get_parent(), global_position + Vector2(0, -8), Color(0.85, 0.9, 0.9), 6, 90.0, 0.2, 1.2)


func _physics_process(delta: float) -> void:
	match _state:
		State.SHUT:
			_t -= delta
			if _victim and is_instance_valid(_victim) and not ("_dying" in _victim and _victim._dying) and _t > 0:
				# held fast by the leg: no walking, no climbing, dragged onto the pan
				_victim.velocity = Vector2.ZERO
				_victim._knock_t = 0.1
				_victim.global_position.x = move_toward(_victim.global_position.x, global_position.x, 60.0 * delta)
				if randf() < delta * 3.0:
					FX.burst(get_parent(), global_position + Vector2(randf_range(-6, 6), -6), Color(0.8, 0.8, 0.8), 1, 40.0, 0.2, 1.0)
			else:
				if _victim and is_instance_valid(_victim) and not ("_dying" in _victim and _victim._dying):
					SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.8)   # it tears free
				_victim = null
				_state = State.REWIND
				_t = REWIND
		State.REWIND:
			_t -= delta
			_spr.frame = 3 if _t < REWIND * 0.7 else 2
			if _t <= 0:
				_state = State.SET
				_spr.frame = 0
				SFX.play_small(self, SFX.sfx_clink(), -12.0, 1.8)
