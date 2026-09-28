extends Node2D
## Rust mite: a clockwork tick the size of a rivet. They come as a swarm
## (swarm() below) and seep through the cracks in the rock toward your
## powered machinery: a wheel or engine that makes power, or a machine a
## wheel is driving (a powered one before one that isn't). There they
## cling and feed, and every mite on a piece keeps a share of its power
## back (scripts/power.gd MITE_DRAIN: five on one leave it a third). They
## spread themselves over the pieces rather than all piling on one.
## One hit of anything kills a mite (fast ore rolling or dropped through
## them, a shot); a knock (heavy ore ploughing past) shakes it off to crawl
## back; the prospector brushes off any he walks into, and gets nipped.
## After LIFETIME they rust through and crumble.
## Art: a 4-frame sprite (tools/art/gen_rust_mite.py), stepped in _draw.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const Power = preload("res://scripts/power.gd")

enum State { SEEK, CLING, FALL, DYING }

const SPEED := 60.0             # crawling in the open
const ROCK_SPEED := 22.0        # squeezing through cracks in the rock
const GRAVITY := 600.0
const CLING_DIST := 10.0
const CLING_SPREAD := 12.0      # where on a piece it settles (px from its origin)
const CROWD := 0.6              # each mite already on a piece makes it look this much further
const BRUSH := 22.0             # the prospector this close (to his middle) brushes it off
const SWITCH := 0.6             # only changes its mind for a piece this much better
const LIFETIME := 90.0
const SWARM := 5

var hp := 1
var damage := 1                 # a nip
var velocity := Vector2.ZERO
var buried := false             # in the rock: aimed guns can't see it
var clinging_to: Node2D = null  # what it's feeding on (scripts/power.gd reads this)
var drained := 0.0              # seconds spent feeding (tests)
var brushed := 0                # times knocked or brushed off (tests)
var _dying := false
var _state := State.SEEK
var _target: Node2D = null
var _spot := Vector2.ZERO       # where on the target it holds on
var _retarget := 0.0
var _life := LIFETIME
var _anim := randf() * 10.0
var _fall_t := 0.0
var _spr: Sprite2D              # crawling / feeding frames


## A swarm of n mites around `at`, added to `parent`.
static func swarm(parent: Node, at: Vector2, n := SWARM) -> Array:
	var out := []
	for i in n:
		var m: Node2D = load("res://scenes/rust_mite.tscn").instantiate()
		m.global_position = at + Vector2(randf_range(-18, 18), randf_range(-10, 10))
		parent.add_child(m)
		out.append(m)
	return out


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/rust_mite.png")
	_spr.hframes = 4
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	add_to_group("enemies")
	add_to_group("rust_mites")
	z_index = 4
	_life = LIFETIME * randf_range(0.9, 1.1)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 5.0


func knock(v: Vector2) -> void:
	if _dying:
		return
	_let_go()
	velocity = v * 0.6
	_state = State.FALL
	_fall_t = 0.0


func _tm() -> TileMapLayer:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("TileMapLayer") as TileMapLayer if scene else null


func _solid_at(tm: TileMapLayer, p: Vector2) -> bool:
	return tm != null and tm.get_cell_source_id(tm.local_to_map(tm.to_local(p))) != -1


## Mites on a piece already.
func _crowd(b: Node) -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("rust_mites"):
		if m != self and (m.clinging_to == b or m._target == b):
			n += 1
	return n


func _pick() -> void:
	var cands := []
	for g in ["power_wheels", "power_users"]:
		for b in get_tree().get_nodes_in_group(g):
			if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.has_meta("ghost"):
				cands.append(b)
	if cands.is_empty():
		var bs := get_node_or_null("/root/BuildSystem")
		if bs:
			cands = bs._placed_buildings.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	var was := _target
	var keep := INF
	_target = null
	var best := INF
	for b in cands:
		var d: float = b.global_position.distance_to(global_position)
		# powered pieces first: a dead machine is poor feeding
		var fed: float = b.power() if b.is_in_group("power_wheels") and b.has_method("power") else Power.level_at(get_tree(), b.global_position)
		d *= 1.0 if fed > 0.05 else 3.0
		d *= 1.0 + CROWD * _crowd(b)
		if b == was:
			keep = d
		if d < best:
			best = d
			_target = b
	if keep < INF and best > keep * SWITCH:
		_target = was   # set on it: crawling past another piece doesn't turn it
	if _target and _target != was:
		_spot = Vector2(randf_range(-CLING_SPREAD, CLING_SPREAD), randf_range(-CLING_SPREAD, CLING_SPREAD * 0.4))


func _let_go() -> void:
	if clinging_to:
		brushed += 1
	clinging_to = null


func _physics_process(delta: float) -> void:
	if _dying:
		return
	_anim += delta
	_life -= delta
	if _life <= 0:
		_crumble()
		return
	var tm := _tm()
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and (p.global_position + Vector2(0, -10)).distance_to(global_position) < BRUSH and _state != State.FALL:
		knock(Vector2(signf(global_position.x - p.global_position.x) * 140.0, -120.0))
	buried = _solid_at(tm, global_position)
	match _state:
		State.FALL:
			_fall_t += delta
			velocity.y += GRAVITY * delta
			var nxt := global_position + velocity * delta
			if _solid_at(tm, nxt + Vector2(0, 3)) and not buried:
				velocity = Vector2.ZERO
				if _fall_t > 0.3:
					_state = State.SEEK
					_retarget = 0.0
			else:
				global_position = nxt
			if _fall_t > 2.0:
				_state = State.SEEK
		State.SEEK:
			_retarget -= delta
			if _target == null or not is_instance_valid(_target) or _retarget <= 0:
				_retarget = 2.0
				_pick()
			if _target == null:
				velocity = Vector2.ZERO
			else:
				var goal := _target.global_position + _spot
				var d := goal - global_position
				if d.length() < CLING_DIST:
					_state = State.CLING
					clinging_to = _target
					SFX.play_small(self, SFX.sfx_clink(), -18.0, 2.2)
				else:
					var sp := ROCK_SPEED if buried else SPEED
					velocity = d.normalized() * sp
					global_position += velocity * minf(delta, d.length() / sp)
		State.CLING:
			if clinging_to == null or not is_instance_valid(clinging_to) or clinging_to.is_queued_for_deletion():
				clinging_to = null
				_state = State.SEEK
				_retarget = 0.0
			else:
				global_position = clinging_to.global_position + _spot
				velocity = Vector2.ZERO
				drained += delta
				if randf() < delta * 1.5:
					FX.burst(get_parent(), global_position, Color(0.72, 0.36, 0.16), 1, 30.0, 0.5, 1.2, 60.0)
	queue_redraw()


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	if hp > 0:
		return
	_let_go()
	_die(Color(0.8, 0.4, 0.18))
	SFX.play_small(self, SFX.sfx_clink(), -12.0, 2.6)


func _crumble() -> void:
	_let_go()
	_die(Color(0.55, 0.3, 0.15))


func _die(c: Color) -> void:
	_dying = true
	_state = State.DYING
	clinging_to = null
	remove_from_group("enemies")
	remove_from_group("rust_mites")
	FX.burst(get_parent(), global_position, c, 6, 70.0, 0.35, 1.3)
	queue_free()


## A copper-red tick: a domed back, six scrabbling legs, rust flecks.
func _draw() -> void:
	var feeding := _state == State.CLING
	var wig := sin(_anim * (30.0 if feeding else 18.0))
	_spr.frame = (2 if feeding else 0) + (1 if wig < 0.0 else 0)
	if absf(velocity.x) > 2.0 and not feeding:
		_spr.flip_h = velocity.x < 0.0
