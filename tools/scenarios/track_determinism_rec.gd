extends RefCounted
## Track net determinism: one layout (source -> rail -> escapement -> rail
## -> splitter -> two rails -> two bins, a bin emptied part way) built and
## run twice in this process, every rider's state hashed every 60 ticks.
## Run it again with another SEED (a different world) and diff the hashes.

const MW = preload("res://scripts/marble_works.gd")
const TICKS := 1500


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var runs := []
	for pass_i in 2:
		var pieces := []
		var bin_l: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1040, 420))
		var bin_r: Node2D = MW._piece(t.main, "res://scenes/track_bin.tscn", Vector2(1420, 430))
		var src: Node2D = MW._piece(t.main, "res://scenes/track_source.tscn", Vector2(980, 200), {"mode": 0})
		var feed: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", src.spout_end(), {"end_offset": Vector2(130, 50)})
		var esc: Node2D = MW._piece(t.main, "res://scenes/track_escapement.tscn", src.spout_end() + Vector2(130, 50), {"mode": 0})
		var mid: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", esc.end_point(), {"end_offset": Vector2(60, 60)})
		var sp: Node2D = MW._piece(t.main, "res://scenes/track_splitter.tscn", esc.end_point() + Vector2(60, 60))
		var left: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", sp.branch_end(0), {"end_offset": Vector2(1040, 420) - sp.branch_end(0)})
		var right: Node2D = MW._piece(t.main, "res://scenes/track_rail.tscn", sp.branch_end(1), {"end_offset": Vector2(1420, 430) - sp.branch_end(1)})
		pieces = [bin_l, bin_r, src, feed, esc, mid, sp, left, right]
		var net: Node = feed._net
		net.snap_every = 60
		while net.tick < TICKS:
			await t.main.get_tree().physics_frame
			if net.tick == 700:
				bin_l.empty()
		var hashes: Array = net.snapshots.map(func(s): return s.md5_text().substr(0, 8))
		t.log_line("determinism pass %d: emitted %d esc released %d bins %d/%d (emptied %d) riders %d | hashes %s" % [
			pass_i + 1, src.emitted, esc.released, bin_l.accepted, bin_r.accepted, bin_l.emptied, net.rider_count(), " ".join(hashes)])
		t.log_line("FINAL %s" % net.snapshots[net.snapshots.size() - 1].md5_text())
		runs.append(hashes)
		if pass_i == 0:
			var cam: Camera2D = t.main.get_node("Player/Camera2D")
			cam.top_level = true
			cam.position_smoothing_enabled = false
			cam.zoom = Vector2(1.8, 1.8)
			cam.global_position = Vector2(1200, 330)
			await t.shot("layout")
		for tr in net.tracks:
			tr.clear_riders()   # (removing a rail drops its riders as loose ore)
		for p in pieces:
			p.queue_free()
		net.queue_free()
		await t.wait(0.2)
	t.log_line("determinism: two runs in one process %s (%d snapshots)" % ["IDENTICAL" if runs[0] == runs[1] else "DIFFER", runs[0].size()])
