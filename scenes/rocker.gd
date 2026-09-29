extends Node2D
## Flip-flop: the marble-machine splitter. A brass rocker on a pivot under
## a little funnel, tipped one way; a marble drops onto it, rolls off the
## low side, and its weight rocks the rocker over the other way as it
## leaves, so the next goes the other way. Every other, by gravity alone.
## Ore-only layer (like chutes): walkers pass through.
##
## Rate: up to 4 a second (it takes 0.25 s to rock over).
##
## On a track (scripts/track/track_net.gd): when a track's open end sits at
## its funnel's mouth (a chute ending over it, MOUTH), it's a junction on
## the net (scripts/track/track_fork.gd): a short feed from that end down
## to the pivot, and the two halves of the bar as branches, left and right,
## whose ends are open (the marble flies off the bar's end as it always
## did) or feed whatever track is laid from them. pick() sends each rider
## the way the bar leans and rocks it over; if that way is backed up it
## sends it the free way (and rocks over from there); both backed up, the
## rider waits on the feed and the queue behind it waits too. No zone.
## Ore dropped into the funnel from the air still lands on the bar and
## rolls off it as physics, rocking it the same. The points switch, the
## overflow gate and the weigh scale are rockers too: they say which way
## (_want), whether a backed-up way may be dodged (_dodges) and what a
## marble going by does (_went).

const SFX = preload("res://scripts/sfx.gd")
const TrackFork = preload("res://scripts/track/track_fork.gd")
const ORE_ONLY := 64
const TILT := 0.55               # rad each way
const ARM := 15.0                # half-length of the rocker
const MOUTH := Rect2(-30, -60, 60, 52)   # a feeding track end in here makes it a junction
const GAP := 15                  # net ticks between riders it sends (0.25 s: at most 4/s)
const LANDING := 60.0            # px/s a rider keeps coming down the feed: the funnel and the bar soak up the drop, so it rolls off the bar's end as a marble landing on it would

var tilt := 1.0                  # +1: low side right
var sent := [0, 0]               # tests: left, right
var _body: StaticBody2D
var _shape: CollisionShape2D
var _sense: Area2D
var _angle := TILT
var _cool := 0.0
var _bar: Sprite2D
var _fork = null                 # its junction on the track net (TrackFork), when fed by a track
var _next := 0                   # net tick it may send the next rider at


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind the
	# parent so the weigh scale / gate / points extras draw over them
	var base := Sprite2D.new()
	base.texture = preload("res://assets/sprites/rocker_base.png")
	base.centered = false
	base.offset = Vector2(-22, -28)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.show_behind_parent = true
	add_child(base)
	_bar = Sprite2D.new()
	_bar.texture = preload("res://assets/sprites/rocker_bar.png")
	_bar.centered = false
	_bar.offset = Vector2(-18, -4)
	_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bar.show_behind_parent = true
	_bar.rotation = _angle
	add_child(_bar)
	if has_meta("ghost"):
		return
	add_to_group("rockers")
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()      # like a chute: landings don't bounce off it
	m.absorbent = true
	m.bounce = 1.0
	m.friction = 0.4
	_body.physics_material_override = m
	_shape = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-ARM, 0)
	seg.b = Vector2(ARM, 0)
	_shape.shape = seg
	_body.add_child(_shape)
	add_child(_body)
	# funnel lips above, so drops land on the pivot
	for s in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var sg := SegmentShape2D.new()
		sg.a = Vector2(s * 18, -24)
		sg.b = Vector2(s * 10, -12)
		cs.shape = sg
		_body.add_child(cs)
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 2
	var sc := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(ARM * 2 + 10, 14)
	sc.shape = r
	sc.position = Vector2(0, -2)
	_sense.add_child(sc)
	add_child(_sense)
	_sense.body_exited.connect(_on_leave)
	_fork = TrackFork.new(self, MOUTH)
	_apply()


func _exit_tree() -> void:
	if _fork:
		_fork.teardown()


func _apply() -> void:
	_angle = TILT * tilt
	_shape.rotation = _angle
	_bar.rotation = _angle
	queue_redraw()


func _on_leave(b) -> void:
	if not is_instance_valid(b) or not b is RigidBody2D or _cool > 0:
		return
	# once per marble, and only as it rolls off the end (not a bounce out the top)
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	var went := 1 if b.global_position.x > global_position.x else 0
	sent[went] += 1
	# its weight leaving the low end rocks it over
	tilt = -tilt
	_cool = 0.25
	_apply()
	SFX.play_small(self, SFX.sfx_latch(), -14.0, 0.75)


func _physics_process(delta: float) -> void:
	_cool -= delta
	if _fork:
		_fork.update()


# ── on the track net: a junction ───────────────────────────────────────

## Where the bar's end is (0 left, 1 right), world space, lying the way that
## side goes down: tests and layouts lay a chute on from here.
func branch_end(i: int) -> Vector2:
	var sx := -1.0 if i == 0 else 1.0
	return global_position + Vector2(sx * ARM * cos(TILT), ARM * sin(TILT))


## TrackFork: the feed from the end at its mouth down to the pivot, and a
## branch down each half of the bar.
func fork_paths(src: Vector2, _tangent: Vector2) -> Dictionary:
	var pivot := global_position
	return {"feed": PackedVector2Array([src, pivot]),
		"branches": [PackedVector2Array([pivot, branch_end(0)]), PackedVector2Array([pivot, branch_end(1)])],
		"feed_vcap": LANDING}


## The way a rider of `kind` should go (0 left, 1 right): the way it leans.
func _want(_kind: String) -> int:
	return 1 if tilt > 0 else 0


## Whether it sends a rider the free way when the way it wants is backed up.
func _dodges() -> bool:
	return true


## A rider went way i: a flip-flop rocks over (the next goes the other way).
func _went(i: int, _kind: String) -> void:
	tilt = -1.0 if i == 1 else 1.0
	_apply()
	SFX.play_small(self, SFX.sfx_latch(), -14.0, 0.75)


## Junction router (the net asks): which branch for this rider, or -1 (wait).
func pick(kind: String, free: Array) -> int:
	if _fork.net.tick < _next:
		return -1
	var w := _want(kind)
	if free[w]:
		return w
	if _dodges() and free[1 - w]:
		return 1 - w
	return -1


func passed(i: int, kind: String) -> void:
	_next = _fork.net.tick + GAP
	sent[i] += 1
	_went(i, kind)


## A rider flying off a branch's end as physics ore: it's been counted.
func rider_released(_tr, body: RigidBody2D) -> void:
	body.set_meta("rocked_by", get_instance_id())


func _draw() -> void:
	pass   # stand, pivot, bar and funnel lips are sprites (see _ready)
