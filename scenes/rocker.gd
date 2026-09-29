extends Node2D
## Flip-flop: the marble-machine toggle. A brass see-saw on a pin under a
## little funnel, held tipped one way by an over-centre detent (an iron cam
## lobe under its hub, a leaf spring with a roller pressing up beside it).
## Its raised side is where the next marble goes: a marble dropping onto it
## tips it over (the lobe shoves the roller down past centre, the spring
## snaps it back up: click), rolls off down the side that just went down,
## and leaves the other side raised for the next one. Every other, by the
## marble's own weight. Ore-only layer (like chutes): walkers pass through.
##
## Rate: up to 4 a second (it takes 0.25 s to tip over).
##
## On a track (scripts/track/track_net.gd): when a track's open end sits at
## its funnel's mouth (a chute ending over it, MOUTH), it's a junction on
## the net (scripts/track/track_fork.gd): a short feed from that end down
## to the pivot, and the two halves of the see-saw as branches, left and
## right, whose ends are open (the marble flies off the end as it always
## did) or feed whatever track is laid from them. pick() sends each rider
## to the raised side (`tilt`), which the rider's weight then tips down; if
## that way is backed up it sends it down the side already down (no tip);
## both backed up, the rider waits on the feed and the queue behind it
## waits too. No zone. Ore dropped into the funnel from the air tips it the
## same way as it lands, and rolls off the side that went down. The points
## switch, the overflow gate and the weigh scale are rockers too: they say
## which way (_want), whether a backed-up way may be dodged (_dodges), what
## a marble going by does (_went), and draw their own parts (_build_art,
## _pose).

const SFX = preload("res://scripts/sfx.gd")
const TrackFork = preload("res://scripts/track/track_fork.gd")
const ORE_ONLY := 64
const TILT := 0.55               # rad each way
const ARM := 15.0                # half-length of the rocker
const MOUTH := Rect2(-30, -60, 60, 52)   # a feeding track end in here makes it a junction
const GAP := 15                  # net ticks between riders it sends (0.25 s: at most 4/s)
const LANDING := 60.0            # px/s a rider keeps coming down the feed: the funnel and the bar soak up the drop, so it rolls off the bar's end as a marble landing on it would

var tilt := 1.0                  # which way the next marble goes (+1 right): the flip-flop's raised side, the others' low side
var sent := [0, 0]               # tests: left, right
var _body: StaticBody2D
var _shape: CollisionShape2D
var _sense: Area2D
var _angle := TILT               # the bar's angle (its collision), +: right end down
var _vis := TILT                 # the angle drawn: eases after _angle
var _cool := 0.0
var _bar: Sprite2D
var _spring: Sprite2D            # flip-flop: the detent's leaf spring (frames: relaxed .. squashed)
var _fork = null                 # its junction on the track net (TrackFork), when fed by a track
var _next := 0                   # net tick it may send the next rider at
var _tw: Tween


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too
	_build_art()
	_angle = _pose_angle()
	_vis = _angle
	_pose(_vis)
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
	_sense.body_entered.connect(_on_land)
	_fork = TrackFork.new(self, MOUTH)
	_apply()


## The flip-flop itself (not the pieces built on it).
func _is_flipflop() -> bool:
	return get_script().resource_path == "res://scenes/rocker.gd"


func _sprite(tex: Texture2D, off: Vector2, behind := true) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = behind
	add_child(sp)
	return sp


## The piece's sprites (ghosts too). The flip-flop: oak A-frame and funnel,
## the detent spring, the see-saw. The weigh scale keeps the plain rocker.
func _build_art() -> void:
	if _is_flipflop():
		_sprite(preload("res://assets/sprites/flipflop_frame.png"), Vector2(-22, -28))
		_spring = _sprite(preload("res://assets/sprites/flipflop_spring.png"), Vector2(-11, 0))
		_spring.hframes = 5
		_bar = _sprite(preload("res://assets/sprites/flipflop_rocker.png"), Vector2(-18, -5))
		return
	_sprite(preload("res://assets/sprites/rocker_base.png"), Vector2(-22, -28))
	_bar = _sprite(preload("res://assets/sprites/rocker_bar.png"), Vector2(-18, -4))


## The bar's angle for the current tilt. The flip-flop lies with its raised
## side toward where the next goes (that side's end up); the others lean
## down the way they send.
func _pose_angle() -> float:
	return -TILT * tilt if _is_flipflop() else TILT * tilt


## Draws the moving parts at bar angle a.
func _pose(a: float) -> void:
	if _bar:
		_bar.rotation = a
	if _spring:
		# the cam lobe presses the roller down hardest straight down (mid-tip)
		var c := clampf(1.0 - absf(a) / TILT, 0.0, 1.0)
		_spring.frame = clampi(roundi(c * 4.0), 0, 4)


func _set_vis(a: float) -> void:
	_vis = a
	_pose(a)


func _exit_tree() -> void:
	if _fork:
		_fork.teardown()


## Sets the bar (its collision at once) and swings the drawn parts over.
func _apply() -> void:
	var to := _pose_angle()
	var moved := not is_equal_approx(to, _angle)
	_angle = to
	if _shape:
		_shape.rotation = _angle
	if not moved or not is_inside_tree():
		_set_vis(_angle)
	else:
		if _tw:
			_tw.kill()
		_tw = create_tween()
		_tw.tween_method(_set_vis, _vis, _angle, _swing_time()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Seconds the drawn bar takes to swing over.
func _swing_time() -> float:
	return 0.2


## A physics marble coming down into the flip-flop: its weight on the raised
## side tips it over, so it rolls off the side that went down.
func _on_land(b) -> void:
	if not _is_flipflop() or not is_instance_valid(b) or not b is RigidBody2D or _cool > 0:
		return
	if b.get_meta("rocked_by", 0) == get_instance_id() or b.get_meta("tipped_by", 0) == get_instance_id():
		return
	if b.global_position.y > global_position.y or b.linear_velocity.y < 0:
		return                   # only one dropping in from above
	b.set_meta("tipped_by", get_instance_id())
	tilt = -tilt
	_cool = 0.25
	_apply()
	_clack()


## The tip over the detent: the spring's click and the see-saw's knock.
func _clack() -> void:
	SFX.play_small(self, SFX.sfx_latch(), -14.0, 0.75)
	SFX.play_small(self, SFX.sfx_ore_knock("wood"), -18.0, 1.1)


func _on_leave(b) -> void:
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	# once per marble, and only as it rolls off the end (not a bounce out the top)
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	sent[1 if b.global_position.x > global_position.x else 0] += 1


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


## The way a rider of `kind` should go (0 left, 1 right): the raised side.
func _want(_kind: String) -> int:
	return 1 if tilt > 0 else 0


## Whether it sends a rider the free way when the way it wants is backed up.
func _dodges() -> bool:
	return true


## A rider went way i: its weight tips the see-saw down that side (if it
## was raised), leaving the other side raised for the next.
func _went(i: int, _kind: String) -> void:
	var was := tilt
	tilt = -1.0 if i == 1 else 1.0
	_apply()
	if tilt != was:
		_clack()


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
	pass   # frame, funnel, see-saw and detent spring are sprites (_build_art)
