extends Node2D
## Splitter: a tipping-T toggle. A steel tent (two plates sloping down from
## a brass apex) with a pivoted T on its apex: an upright blade leaning
## over one plate and blocking it, a toe lying along each plate, and a tail
## hanging inside the tent. A piece rolls down the open plate over that
## side's raised toe, presses it flat, and the T rocks over: the blade now
## blocks the side just used, so a stream alternates left, right, left
## (Factorio's splitter, done with the pieces' own weight). One tapper can
## then keep a turret and a hopper both fed.
##
## Setting: a brass locking peg on the plate under the apex, in one of three
## holes. Parked at the bottom, the T rocks freely (alternate); in the left
## hole it jams the tail so the blade stays over the right plate (always
## left); in the right hole, always right. Click it to move the peg on.
## Like the chute, only ore and ingots collide with it.
##
## Rate: up to 10 a second (the T flicks over in 0.09 s).
##
## On a track (scripts/track/track_net.gd): when a track's open end sits
## over it (MOUTH: a chute ending above the apex), it's a junction on the
## net (scripts/track/track_fork.gd): a feed from that end to the apex and
## a branch down each plate, open at the plates' ends (the piece flies off
## as it always did) or feeding track laid from them. Alternating, each
## rider goes the open way and rocks the T over; if that way is backed up
## the rider takes the other, over the blade, and the T stays as it is.
## Locked, it only goes
## the pegged way: backed up, the rider waits, and the queue behind it. No
## zone. Ore landing on it from the air rolls off as physics, as before.

const SFX = preload("res://scripts/sfx.gd")
const TrackFork = preload("res://scripts/track/track_fork.gd")

enum Mode { ALTERNATE, LEFT, RIGHT }
@export var mode: Mode = Mode.ALTERNATE

const ORE_ONLY := 64
const HALF := 15.0            # paddle half-length
const TILT := 0.5             # radians (~29 degrees)
const POST_MAX := 220.0
const MOUTH := Rect2(-24, -50, 48, 44)   # a feeding track end in here makes it a junction
const GAP := 6                   # net ticks between riders (0.1 s)
const LANDING := 60.0            # px/s a rider keeps coming down the feed: the paddle soaks up the landing
const VANE := 0.45               # rad the T rocks each way from upright
const BLADE := 10.0              # blade length up from the pivot
const PEG_HOLES := [Vector2(0, 15), Vector2(-2, 10), Vector2(2, 10)]   # parked, left lock, right lock (by Mode)

var side := -1.0              # which way the next piece goes (-1 left, +1 right)
var passed := [0, 0]          # pieces sent left, right (for tests / tuning)
var _paddle: StaticBody2D     # the tent and the blade (physics)
var _blade: CollisionShape2D
var _zone: Area2D
var _tilt := 0.0              # the T's drawn angle, tweened
var _vane: Sprite2D
var _peg: Sprite2D
var _fork = null              # its junction on the track net (TrackFork), when fed by a track
var _next := 0
static var _steel := _make_steel()


static func _make_steel() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.5
	m.absorbent = true   # landings stick, then roll off
	m.friction = 1.0
	return m


func _ready() -> void:
	z_index = 1
	if mode == Mode.RIGHT:
		side = 1.0
	_tilt = _target_tilt()
	# sprites first (ghosts and build-bar icons too)
	_part(preload("res://assets/sprites/splitter_roof.png"), Vector2(-17, -5))
	_vane = _part(preload("res://assets/sprites/splitter_vane.png"), Vector2(-15, -13))
	_peg = _part(preload("res://assets/sprites/splitter_peg.png"), Vector2(-2, -2))
	_set_tilt(_tilt)
	if has_meta("ghost"):
		return
	_paddle = StaticBody2D.new()
	_paddle.collision_layer = ORE_ONLY
	_paddle.collision_mask = 0
	_paddle.physics_material_override = _steel
	for sx in [-1.0, 1.0]:              # the tent's plates
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = Vector2.ZERO
		seg.b = Vector2(sx * HALF * cos(TILT), HALF * sin(TILT))
		cs.shape = seg
		_paddle.add_child(cs)
	_blade = CollisionShape2D.new()     # the T's blade: blocks the plate it leans over
	var bs := SegmentShape2D.new()
	bs.a = Vector2.ZERO
	bs.b = Vector2(0, -BLADE)
	_blade.shape = bs
	_blade.rotation = _tilt
	_paddle.add_child(_blade)
	add_child(_paddle)
	_zone = Area2D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var zs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2, 22)
	zs.shape = r
	zs.position = Vector2(0, -9)
	_zone.add_child(zs)
	add_child(_zone)
	_zone.body_exited.connect(_on_left, CONNECT_DEFERRED)
	_build_post()
	_fork = TrackFork.new(self, MOUTH)


func _exit_tree() -> void:
	if _fork:
		_fork.teardown()


func _physics_process(_delta: float) -> void:
	if _fork:
		_fork.update()


# ── on the track net: a junction ───────────────────────────────────────

## The paddle's end (0 left, 1 right), world space, for laying track on.
func branch_end(i: int) -> Vector2:
	var sx := -1.0 if i == 0 else 1.0
	return global_position + Vector2(sx * HALF * cos(TILT), HALF * sin(TILT))


func fork_paths(src: Vector2, _tangent: Vector2) -> Dictionary:
	var pivot := global_position
	return {"feed": PackedVector2Array([src, pivot]),
		"branches": [PackedVector2Array([pivot, branch_end(0)]), PackedVector2Array([pivot, branch_end(1)])],
		"feed_vcap": LANDING}


## Junction router: the way the paddle leans; alternating, the free way if
## that one's backed up; -1 to wait.
func pick(_kind: String, free: Array) -> int:
	if _fork.net.tick < _next:
		return -1
	var w := 0 if side < 0 else 1
	if free[w]:
		return w
	if mode == Mode.ALTERNATE and free[1 - w]:
		return 1 - w
	return -1


func passed_at(_tr, i: int, _kind: String) -> void:
	_next = _fork.net.tick + GAP
	passed[i] += 1
	if mode == Mode.ALTERNATE:
		_flip(1.0 if i == 0 else -1.0)


func rider_released(_tr, body: RigidBody2D) -> void:
	body.set_meta("split_by", get_instance_id())


func _part(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


## The T's angle for the current side: its blade leans over the other plate.
func _target_tilt() -> float:
	return -VANE * side


func _on_left(body) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(body) or body.get_meta("split_by", 0) == get_instance_id():
		return
	passed[0 if body.global_position.x < global_position.x else 1] += 1
	if mode == Mode.ALTERNATE:
		_flip(-side)


func _flip(to: float) -> void:
	if to == side:
		return
	side = to
	if _blade:
		_blade.rotation = _target_tilt()
	SFX.play(self, SFX.sfx_clink())
	var t := create_tween()
	t.tween_method(_set_tilt, _tilt, _target_tilt(), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_tilt(a: float) -> void:
	_tilt = a
	if _vane:
		_vane.rotation = a
	if _peg:
		_peg.position = PEG_HOLES[mode]


func _build_post() -> void:
	var space := get_world_2d().direct_space_state
	var top := global_position + Vector2(0, 5)
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(top, top + Vector2(0, POST_MAX), 1))
	if hit.is_empty():
		return
	var leg := Line2D.new()
	leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
	leg.texture = preload("res://assets/sprites/strut.png")
	leg.texture_mode = Line2D.LINE_TEXTURE_TILE
	leg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	leg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leg.width = 5.0
	leg.z_index = -2
	add_child(leg)


# ── click to move the locking peg ───────────────────────────────────────

func set_mode(m: Mode) -> void:
	mode = m
	match m:
		Mode.LEFT:
			_flip(-1.0)
		Mode.RIGHT:
			_flip(1.0)
	_set_tilt(_tilt)             # the peg to its hole


func _input(event: InputEvent) -> void:
	if _paddle == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Pointer.world(self).distance_to(global_position + Vector2(0, 2)) < 18:
			set_mode(((mode + 1) % 3) as Mode)
			SFX.play_small(self, SFX.sfx_latch(), -10.0, 1.3)
			get_viewport().set_input_as_handled()
