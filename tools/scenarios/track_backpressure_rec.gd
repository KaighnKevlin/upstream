extends RefCounted
## Track net backpressure: source -> rail -> splitter -> two rails -> two
## bins (12 each). The bins fill, both lines queue back to the splitter and
## up the feed rail to the source, which stops (emitted count flat). Then a
## click empties the left bin: its line drains into it, the source restarts
## and the left side fills again.

const MW = preload("res://scripts/marble_works.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var bin_l: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1040, 390))
	var bin_r: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1400, 400))
	var src: Node2D = MW._piece(t.main, "res://scenes/track_source.tscn", Vector2(1000, 250), {"mode": 0})
	var feed: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", Vector2(1028, 257), {"end_offset": Vector2(170, 60)})
	var sp: Node2D = MW._piece(t.main, "res://scenes/track_splitter.tscn", Vector2(1198, 317))
	var left: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", sp.branch_end(0), {"end_offset": Vector2(1040, 390) - sp.branch_end(0)})
	var right: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", sp.branch_end(1), {"end_offset": Vector2(1400, 400) - sp.branch_end(1)})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.9, 1.9)
	cam.global_position = Vector2(1215, 330)
	var net: Node = feed._net
	var line := func(label: String) -> void:
		t.log_line("%s tick %d | emitted %d%s | spout %d feed %d L %d R %d | bins L %d R %d | split L %d R %d" % [
			label, net.tick, src.emitted, " (blocked)" if src.blocked else "", src.track.count(), feed.track.count(),
			left.track.count(), right.track.count(), bin_l.contents.size(), bin_r.contents.size(), sp.sent[0], sp.sent[1]])
	for s in 24:
		await t.wait(1.0)
		line.call("t=%2ds" % (s + 1))
		if s == 21:
			await t.shot("both_backed_up")
	var before: int = src.emitted
	await t.wait(3.0)
	line.call("3 s later")
	t.log_line("backpressure: source %s while both lines full (emitted %d -> %d)" % ["PAUSED" if src.emitted == before else "still emitting", before, src.emitted])
	# empty the left bin by clicking it
	await t.click_world(Vector2(1040, 410))
	t.log_line("clicked left bin: emptied %d" % bin_l.emptied)
	for s in 6:
		await t.wait(0.5)
		line.call("drain %.1fs" % ((s + 1) * 0.5))
		if s == 1:
			await t.shot("left_draining")
	await t.wait(3.0)
	line.call("after drain")
	t.log_line("riders on net %d, released %d, caught %d, clacks played %d skipped %d" % [net.rider_count(), net.released, net.caught, preload("res://scripts/sfx.gd").small_played, preload("res://scripts/sfx.gd").small_skipped])
	await t.shot("refilled")
