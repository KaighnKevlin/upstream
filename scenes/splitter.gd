extends Node2D
## Splitter: a clockwork paddle on a pivot. Ore landing on it rolls off the
## low side; each piece that leaves tips the paddle the other way, so a
## stream alternates left, right, left (Factorio's splitter, done with
## gravity). One tapper can then keep a turret and a hopper both fed.
##
## Click it to cycle the mode: alternate -> always left -> always right.
## Like the chute, only ore and ingots collide with it.
##
## Rate: up to 10 a second (the paddle flicks over in 0.09 s).
##
## On a track (scripts/track/track_net.gd): when a track's open end sits
## over it (MOUTH: a chute ending above the paddle), it's a junction on the
## net (scripts/track/track_fork.gd): a feed from that end to the pivot and
## a branch down each half of the paddle, open at the paddle's ends (the
## piece flies off as it always did) or feeding track laid from them.
## Alternating, each rider goes the way the paddle leans and flicks it
## over; if that way is backed up the rider takes the free way. Locked left
## or right, it only goes that way: backed up, the rider waits, and the
## queue behind it. No zone. Ore landing on the paddle from the air rolls
## off it as physics, as before.

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

var side := -1.0              # which way the next piece goes (-1 left, +1 right)
var passed := [0, 0]          # pieces sent left, right (for tests / tuning)
var _paddle: StaticBody2D
var _zone: Area2D
var _tilt := -TILT            # drawn angle, tweened
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
	if has_meta("ghost"):
		return
	_paddle = StaticBody2D.new()
	_paddle.collision_layer = ORE_ONLY
	_paddle.collision_mask = 0
	_paddle.physics_material_override = _steel
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-HALF, 0)
	seg.b = Vector2(HALF, 0)
	cs.shape = seg
	_paddle.add_child(cs)
	_paddle.rotation = _tilt
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


## Paddle angle for the current side: the low end is the side ore goes.
func _target_tilt() -> float:
	return TILT * side


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
	SFX.play(self, SFX.sfx_clink())
	var t := create_tween()
	t.tween_method(_set_tilt, _tilt, _target_tilt(), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_tilt(a: float) -> void:
	_tilt = a
	if _paddle:
		_paddle.rotation = a
	queue_redraw()


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


# ── look: steel paddle on a brass cog, mode arrows above ────────────────

const DARK := Color(0.09, 0.07, 0.1)
const STEEL := Color(0.42, 0.44, 0.5)
const SHINE := Color(0.78, 0.82, 0.86)
const BRASS := Color(0.85, 0.62, 0.28)
const BRASS_DK := Color(0.52, 0.34, 0.16)
const CYAN := Color(0.45, 0.85, 0.95)


func _draw() -> void:
	# cog hub behind the paddle, turning with it
	var teeth := 8
	for k in teeth:
		var a := _tilt + k * TAU / teeth
		var p := Vector2.from_angle(a) * 7.0
		draw_rect(Rect2(p.round() - Vector2(2, 2), Vector2(4, 4)), DARK)
	draw_circle(Vector2.ZERO, 7.0, DARK)
	draw_circle(Vector2.ZERO, 5.5, BRASS_DK)
	draw_circle(Vector2.ZERO, 4.0, BRASS)
	for k in teeth:
		var p := Vector2.from_angle(_tilt + k * TAU / teeth) * 7.0
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), BRASS)
	# paddle
	var t := Vector2.from_angle(_tilt)
	var n := Vector2(t.y, -t.x)
	var a0 := -t * HALF
	var a1 := t * HALF
	draw_line(a0 - n * 2, a1 - n * 2, DARK, 6.0)
	draw_line(a0 - n * 2, a1 - n * 2, STEEL, 3.0)
	draw_line(a0 - n * 0.5, a1 - n * 0.5, SHINE, 1.0)
	draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), DARK)  # axle pin
	# mode: which way the next piece goes, and a bar when locked
	var dir := side
	var tip := Vector2(dir * 9, -22)
	var col := CYAN if mode == Mode.ALTERNATE else BRASS
	draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 3, 0), tip + Vector2(-dir * 3, -4), tip + Vector2(-dir * 3, 4)]), DARK)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 2, 0), tip + Vector2(-dir * 2, -2.5), tip + Vector2(-dir * 2, 2.5)]), col)
	if mode == Mode.ALTERNATE:
		var o := Vector2(-dir * 9, -22)  # the other way, dim: it'll swap
		draw_colored_polygon(PackedVector2Array([o + Vector2(-dir * 2, 0), o + Vector2(dir * 2, -2.5), o + Vector2(dir * 2, 2.5)]), Color(CYAN, 0.35))
	else:
		draw_rect(Rect2(Vector2(-dir * 9 - 1, -26), Vector2(2, 8)), BRASS)  # locked


# ── click to cycle the mode ─────────────────────────────────────────────

func set_mode(m: Mode) -> void:
	mode = m
	match m:
		Mode.LEFT:
			_flip(-1.0)
		Mode.RIGHT:
			_flip(1.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _paddle == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position + Vector2(0, -8)) < 18:
			set_mode(((mode + 1) % 3) as Mode)
			SFX.play(self, SFX.sfx_clink())
			get_viewport().set_input_as_handled()
