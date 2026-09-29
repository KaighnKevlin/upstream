extends RefCounted
## Track net handoffs: source -> rail A, whose end is open: each marble
## flies off it as a physics ore, hits a pop bumper (an ordinary physics
## piece), is kicked up and over, comes down on rail B and becomes a rider
## again, rolls down into a bin. Logs handoffs both ways and counts every
## marble: none lost.

const MW = preload("res://scripts/marble_works.gd")
const N := 10


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var bin: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1450, 372), {"cap": 99})
	var src: Node2D = MW._piece(t.main, "res://scenes/track_source.tscn", Vector2(1000, 200), {"mode": 2, "limit": N})
	var a: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", src.spout_end(), {"end_offset": Vector2(1150, 260) - src.spout_end()})
	var bump: Node2D = MW._piece(t.main, "res://scenes/pop_bumper.tscn", Vector2(1180, 300))
	var b: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", Vector2(1236, 322), {"end_offset": Vector2(1450, 372) - Vector2(1236, 322)})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1225, 290)
	var net: Node = a._net
	var shot := false
	for s in 18:
		await t.wait(1.0)
		var flying: int = t.main.get_tree().get_nodes_in_group("ore").size()
		var on_track: int = net.rider_count()
		t.log_line("t=%2ds emitted %d | on rails %d (A %d, B %d) | flying %d | out (track->physics) %d | in (physics->track) %d | bumper kicks %d | bin %d | lost %d" % [
			s + 1, src.emitted, on_track, a.track.count(), b.track.count(), flying, net.released, net.caught, bump.kicks,
			bin.accepted, src.emitted - on_track - flying - bin.accepted])
		if not shot and flying > 0:
			shot = true
			await t.shot("in_flight")
	var flying: int = t.main.get_tree().get_nodes_in_group("ore").size()
	t.log_line("handoff: %d emitted, %d flew off rail A, %d caught on rail B, %d in the bin, %d still loose -> %s" % [
		src.emitted, net.released, net.caught, bin.accepted, flying,
		"NONE LOST" if bin.accepted == N and net.released == N and net.caught == N else "CHECK"])
	for o in t.main.get_tree().get_nodes_in_group("ore"):
		t.log_line("  loose ore at (%d,%d) v (%d,%d)" % [o.global_position.x, o.global_position.y, o.linear_velocity.x, o.linear_velocity.y])
	await t.shot("end")
