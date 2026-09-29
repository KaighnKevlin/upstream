extends RefCounted
## Marbles at rest don't spin. Two cases, each left 3 s to settle and then
## watched for 3 s:
##  - riders queued on a track (scenes/chute.gd) behind a full track bin: the
##    sprite rotation of every rider (TrackNet rrot) must not change while
##    the queue stands still (spin follows the distance actually travelled);
##  - physics ore (chutes with on_track = false): three dropped into a V of
##    two chutes, one sent into the stop of a level chute: max |angular
##    velocity| of those at rest must be ~0 (scenes/ore.gd bleeds the spin
##    off a piece that's touching something and barely moving).
## Then a rolling check: a physics marble at 150 px/s on a level chute
## still carries ~124 px/s after 200 px (as tools/scenarios/roll_lab.gd).

const MW = preload("res://scripts/marble_works.gd")
const ORE = preload("res://scenes/ore.tscn")


static func _ore(t, kind: String, at: Vector2, v := Vector2.ZERO) -> RigidBody2D:
	var o: RigidBody2D = ORE.instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	o.linear_velocity = v
	t.main.add_child(o)
	return o


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	# 1. riders: a chute into a small bin (holds 2); the rest queue behind it
	var bin: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1200, 300), {"cap": 2})
	var ch: Node2D = MW._piece(t.main, "res://scenes/chute.tscn", Vector2(1000, 240), {"end_offset": Vector2(200, 60)})
	# 2. physics: a level chute kept off the track (its stop at the right
	# end), and a V of two chutes
	MW._piece(t.main, "res://scenes/chute.tscn", Vector2(1300, 420), {"end_offset": Vector2(-160, 0), "on_track": false})
	MW._piece(t.main, "res://scenes/chute.tscn", Vector2(1420, 420), {"end_offset": Vector2(60, 40), "has_lip": false, "on_track": false})
	MW._piece(t.main, "res://scenes/chute.tscn", Vector2(1540, 420), {"end_offset": Vector2(-60, 40), "has_lip": false, "on_track": false})
	# ... and a chute running down into a wall (a marble pressed against it)
	MW._piece(t.main, "res://scenes/chute.tscn", Vector2(1540, 300), {"end_offset": Vector2(100, 40), "on_track": false})
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wcs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(0, -60)
	seg.b = Vector2(0, 10)
	wcs.shape = seg
	wall.add_child(wcs)
	wall.position = Vector2(1636, 340)
	t.main.add_child(wall)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1270, 340)
	await t.wait(0.3)
	var net: Node = ch._net
	for k in 6:
		net.add_rider(ch.track, 10.0 + k * 14.0, 60.0, "copper" if k % 2 == 0 else "iron")
	var phys := []
	for k in 3:
		phys.append(_ore(t, ["copper", "iron", "copper"][k], Vector2(1470 + k * 4, 380 - k * 14)))
	phys.append(_ore(t, "iron", Vector2(1286, 413), Vector2(40, 0)))
	phys.append(_ore(t, "copper", Vector2(1550, 290)))
	phys.append(_ore(t, "iron", Vector2(1560, 285)))
	await t.wait(3.0)
	var rot0 := PackedFloat64Array(ch.track.rrot)
	var s0 := PackedFloat64Array(ch.track.rs)
	var max_w := 0.0
	var max_v := 0.0
	for f in 180:
		await t.main.get_tree().physics_frame
		for o in phys:
			if is_instance_valid(o) and o.is_inside_tree() and o.linear_velocity.length() < 5.0:
				max_w = maxf(max_w, absf(o.angular_velocity))
				max_v = maxf(max_v, o.linear_velocity.length())
	var drot := 0.0
	var dmove := 0.0
	var n: int = mini(rot0.size(), ch.track.count())
	for i in n:
		drot = maxf(drot, absf(ch.track.rrot[i] - rot0[i]))
		dmove = maxf(dmove, absf(ch.track.rs[i] - s0[i]))
	t.log_line("rest spin: riders queued behind a full bin (%d in it, %d riding): over 3 s max rotation change %.4f rad, max travel %.2f px -> %s" % [
		bin.contents.size(), ch.track.count(), drot, dmove, "STILL" if drot < 0.01 else "SPINNING"])
	var where := []
	for o in phys:
		if is_instance_valid(o):
			where.append("%s (%d,%d) v %.1f w %.2f" % [o.kind, o.global_position.x, o.global_position.y, o.linear_velocity.length(), o.angular_velocity])
	t.log_line("rest spin: physics marbles at rest (3 in a V, 1 against a stop, 2 run into a wall): over 3 s max |angular velocity| %.3f rad/s among those slower than 5 px/s (max such speed %.2f px/s) -> %s | %s" % [
		max_w, max_v, "STILL" if max_w < 0.2 else "SPINNING", where])
	await t.shot("rest_spin")
	# rolling is untouched: 150 px/s along a level physics chute, speed after 200 px
	var lvl: Node2D = MW._piece(t.main, "res://scenes/chute.tscn", Vector2(980, 520), {"end_offset": Vector2(400, 0), "has_lip": false, "on_track": false})
	var r: float = preload("res://scenes/ore.gd").KINDS.copper.radius
	var o := _ore(t, "copper", Vector2(992, 520 - r - 0.3), Vector2(150, 0))
	o.angular_velocity = 150.0 / r
	var at200 := -1.0
	for f in 240:
		await t.main.get_tree().physics_frame
		if at200 < 0.0 and o.global_position.x >= 992 + 200:
			at200 = o.linear_velocity.length()
	t.log_line("rest spin: rolling check, level physics chute 150 px/s -> %.0f px/s after 200 px (roll_lab: ~124)" % at200)
	lvl.queue_free()
