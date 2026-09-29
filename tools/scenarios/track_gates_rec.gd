extends RefCounted
## The migrated marble pieces working natively on the track net, and
## backpressure running back through them.
##
## Line A (left): a source (a marble every 0.25 s: copper, copper, iron)
## down a chute under a tally wheel and a speed trap to an escapement (one
## per beat) at its end, into a flip-flop; the flip-flop's left half runs to
## bin L, its right half to a flap sorter (spring 2.5: iron drops through
## to bin D, copper rolls on) whose low end feeds an overflow gate: primary
## right to bin P, overflow left to bin Q. The escapement is the line's
## limit, so the source queues behind it; the bins fill, each branch backs
## up to its piece, the pieces send the rest the free way while there is
## one (flip-flop, overflow gate) or hold it (the sorter), until everything
## is full, the queue runs back through overflow gate -> sorter -> flip-flop
## -> escapement and the source stops. Then the bins are emptied: the
## queues drain into them and the source starts again.
##
## Line B (right): a source (every 1 s) down a chute through a check
## valve, under a tally wheel wired to a sluice gate (every fifth piece past
## the wheel opens it for 2.5 s), to a magnet drum at the chute's end (iron
## onto the drum and down to bin I, the rest straight on), under a second
## tally wired to a points switch (thrown every third piece) into bins C1 /
## C2.
##
## Logged every 3 s: every piece's count and rate against its stated rate,
## bins, queues and the sources. No zone on any of these tracks.

const MW = preload("res://scripts/marble_works.gd")
const CAP := 6


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(1300, 540)
	var P := func(path: String, at: Vector2, props := {}) -> Node2D:
		return MW._piece(t.main, "res://scenes/%s.tscn" % path, at, props)
	var bin := func(at: Vector2) -> Node2D:
		return MW._piece(t.main, "res://scenes/track_bin.tscn", at, {"cap": CAP})

	# ── line A ──
	var src_a: Node2D = P.call("track_source", Vector2(950, 180), {"mode": 0, "kinds": ["copper", "copper", "iron"]})
	var a1_end := Vector2(1070, 215)
	var a1 = MW._chute(t.main, src_a.spout_end(), a1_end)
	var tally_a: Node2D = P.call("tally", Vector2(1022, 190), {"mode": 1, "wire_to": Vector2(0, -80)})
	var trap: Node2D = P.call("speed_trap", Vector2(1045, 190), {"mode": 0, "wire_to": Vector2(0, -80)})
	var esc: Node2D = P.call("escapement", a1_end, {"mode": 0, "side": 1.0})
	var rk: Node2D = P.call("rocker", a1_end + Vector2(16, 28))
	var bin_l: Node2D = bin.call(Vector2(1000, 300))
	var fs_at := Vector2(1130, 265)
	MW._chute(t.main, rk.branch_end(0), Vector2(1000, 300))
	MW._chute(t.main, rk.branch_end(1), fs_at)
	var fs: Node2D = P.call("flap_sorter", fs_at, {"end_offset": Vector2(150, 40), "springs": [2.5]})
	var bin_d: Node2D = bin.call(Vector2(1180, 360))
	MW._chute(t.main, fs.drop_end(0), Vector2(1180, 360))
	var og: Node2D = P.call("overflow_gate", fs.end_point() + Vector2(16, 28), {"side": 1.0, "watch": Vector2(0, -400)})
	var bin_p: Node2D = bin.call(Vector2(1400, 400))
	var bin_q: Node2D = bin.call(Vector2(1230, 420))
	MW._chute(t.main, og.branch_end(1), Vector2(1400, 400))
	MW._chute(t.main, og.branch_end(0), Vector2(1230, 420))

	# ── line B ──
	var src_b: Node2D = P.call("track_source", Vector2(1420, 180), {"mode": 2, "kinds": ["copper", "iron"]})
	var b1_end := Vector2(1560, 215)
	var b1 = MW._chute(t.main, src_b.spout_end(), b1_end)
	var cv: Node2D = P.call("check_valve", Vector2(1470, 186), {"side": 1.0})
	var tally_b: Node2D = P.call("tally", Vector2(1458, 180), {"mode": 1})
	var sl: Node2D = P.call("sluice", Vector2(1530, 207.5), {"side": 1.0})
	tally_b.wire_to = sl.global_position - tally_b.global_position
	var dr: Node2D = P.call("magnet_drum", b1_end + Vector2(-4, 22), {"side": 1.0})
	var bin_i: Node2D = bin.call(Vector2(1495, 300))
	MW._chute(t.main, Vector2(1570, 258), Vector2(1495, 300))
	# the drum's straight-on branch ends ON px down the chute's line
	var tan: Vector2 = (b1_end - src_b.spout_end()).normalized()
	var on_end: Vector2 = b1_end + tan * preload("res://scenes/magnet_drum.gd").ON
	var pt_feed := Vector2(1605, 236)
	MW._chute(t.main, on_end, pt_feed)
	var tally_c: Node2D = P.call("tally", Vector2(1586, 218), {"mode": 0})
	var pt: Node2D = P.call("points", pt_feed + Vector2(16, 28))
	tally_c.wire_to = pt.global_position - tally_c.global_position
	var bin_c1: Node2D = bin.call(Vector2(1560, 340))
	var bin_c2: Node2D = bin.call(Vector2(1628, 340))
	MW._chute(t.main, pt.branch_end(0), Vector2(1560, 340))
	MW._chute(t.main, pt.branch_end(1), Vector2(1628, 340))

	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.72, 1.72)
	cam.global_position = Vector2(1290, 300)
	await t.wait(0.6)
	var net: Node = a1._net
	var zones := 0
	for tr in net.tracks:
		zones += tr.zones.size() / 2
	t.log_line("built: %d tracks, %d zones on them; linked: escapement %s, tallies %s/%s/%s, trap %s, check valve %s, sluice %s | junctions: flip-flop %s, overflow %s, drum %s, points %s" % [
		net.tracks.size(), zones, esc._mark.linked(), tally_a._mark.linked(), tally_b._mark.linked(), tally_c._mark.linked(),
		trap._mark.linked(), cv._mark.linked(), sl._mark.linked(), rk._fork.linked(), og._fork.linked(), dr._fork.linked(), pt._fork.linked()])

	var bins := {"L": bin_l, "D": bin_d, "P": bin_p, "Q": bin_q, "I": bin_i, "C1": bin_c1, "C2": bin_c2}
	var fill := func() -> String:
		var parts := []
		for k in bins:
			parts.append("%s %d" % [k, bins[k].contents.size()])
		return " ".join(parts)
	var last := {"esc": 0, "tick": net.tick}
	var line := func(label: String) -> void:
		var dt: float = (net.tick - last.tick) / 60.0
		var esc_rate: float = (esc.let_by - last.esc) / maxf(dt, 0.001)
		last.esc = esc.let_by
		last.tick = net.tick
		t.log_line("%s | A: src %d%s, A1 %d riders | tally %d, trap clocked %d last %.0f | escapement let by %d (%.2f/s; stated %.2f/s) | flip-flop L/R %s | sorter dropped %s passed %d | overflow primary %d overflowed %d | bins %s" % [
			label, src_a.emitted, " BLOCKED" if src_a.blocked else "", a1.track.count(), tally_a.count, trap.clocked, trap.last,
			esc.let_by, esc_rate, 1.0 / (0.6 / 0.74), str(rk.sent), str(fs.dropped), fs.passed, og.primary, og.overflowed, fill.call()])
		t.log_line("%s | B: src %d%s, B1 %d riders | check valve passed %d | tally %d fired %d | sluice opened %d let %d, holding %d | drum sorted on/drum %s pulled %d | tally %d | points sent %s" % [
			label, src_b.emitted, " BLOCKED" if src_b.blocked else "", b1.track.count(), cv.passed, tally_b.count, tally_b.fired,
			sl.opened, sl.released, sl.held(), str(dr.sorted), dr.pulled, tally_c.count, str(pt.sent)])

	# the escapement's beat, measured: time between riders it lets by while
	# the queue is waiting on it
	var gaps := []
	var prev_let: int = esc.let_by
	var prev_tick: int = net.tick
	var elapsed := 0.0
	var shot_full := false
	var before_full := -1
	while elapsed < 42.0:
		await t.wait(0.05)
		elapsed += 0.05
		if esc.let_by != prev_let:
			if a1.track.count() >= 3 and elapsed > 3.0:
				gaps.append((net.tick - prev_tick) / 60.0)
			prev_let = esc.let_by
			prev_tick = net.tick
		if int(elapsed * 20.0) % 60 == 0:
			line.call("t=%2ds" % int(round(elapsed)))
		if not shot_full and src_a.blocked and bin_p.contents.size() >= CAP and bin_q.contents.size() >= CAP and bin_l.contents.size() >= CAP:
			shot_full = true
			before_full = src_a.emitted
			t.log_line("line A all backed up at t=%.1fs: source blocked, emitted %d" % [elapsed, src_a.emitted])
			await t.shot("gates_backed_up")
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= maxf(1, gaps.size())
	t.log_line("escapement beat with a queue: %d gaps, mean %.3f s, min %.3f max %.3f (stated %.3f s unpowered)" % [
		gaps.size(), mean, gaps.min() if gaps.size() else 0.0, gaps.max() if gaps.size() else 0.0, 0.6 / 0.74])
	# wait for the whole line to settle: the source stopped for 3 s
	var e0: int = src_a.emitted
	var still := 0.0
	var waited := 0.0
	while still < 3.0 and waited < 25.0:
		await t.wait(0.25)
		waited += 0.25
		if src_a.emitted == e0:
			still += 0.25
		else:
			e0 = src_a.emitted
			still = 0.0
	line.call("settled")
	t.log_line("backpressure: source A %s for %.1f s (emitted %d, blocked %s) after %.1f s more" % [
		"PAUSED" if still >= 3.0 else "still emitting", still, src_a.emitted, src_a.blocked, waited])
	var qs := []
	for tr in net.tracks:
		if is_instance_valid(tr.piece) and tr.count() > 0 and tr.pts[0].x < 1420:
			qs.append("%s:%d" % [tr.piece.name, tr.count()])
	t.log_line("line A queues (piece:riders, source to bins): %s" % " ".join(qs))
	await t.shot("gates_full")
	# empty line A's bins: the queues drain into them, back up the line
	# through every piece, and the source starts again
	for b in [bin_l, bin_d, bin_p, bin_q]:
		b.empty()
	t.log_line("emptied bins L D P Q")
	for k in 4:
		await t.wait(1.5)
		line.call("drain %.1fs" % ((k + 1) * 1.5))
		if k == 1:
			await t.shot("gates_draining")
	t.log_line("after emptying: source A emitted %d -> %d, flip-flop %s, sorter dropped %s, overflow primary %d overflowed %d, bins %s" % [
		e0, src_a.emitted, str(rk.sent), str(fs.dropped), og.primary, og.overflowed, fill.call()])
	var zones2 := 0
	for tr in net.tracks:
		zones2 += tr.zones.size() / 2
	t.log_line("riders on net %d, released %d, caught %d, zones %d" % [net.rider_count(), net.released, net.caught, zones2])
