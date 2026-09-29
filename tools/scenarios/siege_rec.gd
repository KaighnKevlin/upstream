extends RefCounted
## Marble Siege, hands off: started the way the title does it
## (main.start_siege_works), then left alone at normal speed until the
## vault holds or breaks. Logs each wave (sent, down, leaked, fliers,
## stolen), each defence (re-armed / refilled, fired, kills), the machine's
## throughput, and any piece that sits still outside a pocket for over
## 10 s (a jam). Shots at ~30 s, mid-siege and the end.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await t.main.start_siege_works()
	var d: Node2D = t.main._siege
	var p: Dictionary = d.parts
	t.main.get_node("Player").global_position = Vector2(1200, 640)
	# where pieces are meant to sit: the pockets, hoppers, baskets, the bowl
	var rest: Array = d._keep.duplicate()
	rest += [p.gabion.global_position + Vector2(0, -52), p.flak.global_position + Vector2(-20, -20),
		p.balloon.global_position + Vector2(0, -8), p.bowl.global_position + Vector2(0, -24),
		p.portcullis.global_position + Vector2(-24, -12)]
	var still := {}
	var jammed := {}
	var clock := 0.0
	var shots := {30: "siege_30s", 150: "siege_mid", 190: "siege_wave5"}
	var last_wave := 0
	var ended_at := -1.0
	var lag := 0.0
	var trips := {"wire_wreck": 0, "wire_port": 0}
	while clock < 420.0:
		# who breaks the wires (checked every few frames)
		for f in 60:
			await t.physics_frame
			for wn in trips:
				var wire: Node2D = p[wn]
				if wire.tripped > trips[wn]:
					trips[wn] = wire.tripped
					var best = null
					var bd := 99999.0
					for e in t.get_nodes_in_group("enemies"):
						if is_instance_valid(e):
							var dd: float = e.global_position.distance_to(wire.global_position + wire.end_offset * 0.5)
							if dd < bd:
								bd = dd
								best = e
					var who := "?"
					if best:
						who = best.get_script().resource_path.get_file().get_basename()
						if "enemy_type" in best:
							who = ["titan", "scuttler", "soldier", "caster", "ornithopter", "shieldbearer"][best.enemy_type]
					t.log_line("%s tripped by a %s at %s" % [wn, who, best.global_position.round() if best else Vector2.ZERO])
		clock += 1.0
		if shots.has(int(clock)):
			await t.shot(shots[int(clock)])
		# jams: still, not held by a machine, not in a pocket, not on the lane floor (swept)
		var seen := {}
		for o in t.get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or o.gravity_scale == 0.0 or o.linear_velocity.length() > 6.0:
				continue
			if o.global_position.y > d.floor_y - 14:
				continue
			var ok := false
			for r in rest:
				if (r as Vector2).distance_to(o.global_position) < 24.0:
					ok = true
					break
			if ok:
				continue
			var id: int = o.get_instance_id()
			seen[id] = still.get(id, 0.0) + 1.0
			if seen[id] > 10.0 and not jammed.has(id):
				jammed[id] = true
				t.log_line("JAM: a %s still for 10 s at %s" % [o.kind, o.global_position.round()])
		still = seen
		if d.wave != last_wave:
			last_wave = d.wave
			t.log_line("-- wave %d starts at %ds  (output so far %d, ore loose %d)" % [d.wave, int(d.clock), d.output(), t.get_nodes_in_group("ore").size()])
		if int(clock) % 30 == 0:
			t.log_line("t=%ds  wave %d/%d  leaks %d  down %d  output %d  stolen %d  spilled %d  dispensed %d  ore %d  enemies %d" % [
				int(d.clock), d.wave, d.waves.size(), d.leaks, d.killed, d.output(), d.stolen, d.spilled,
				p.dispenser.dropped, t.get_nodes_in_group("ore").size(), t.get_nodes_in_group("enemies").size()])
		if d.over and ended_at < 0:
			ended_at = clock
			await t.wait(1.0)
			await t.shot("siege_end")
			break
	if ended_at < 0:
		await t.shot("siege_timeout")
	t.log_line("==== MARBLE SIEGE %s at %ds: leaks %d/%d, down %d, stolen %d, spilled %d ====" % [
		"WON" if d.won else ("LOST" if d.over else "UNFINISHED"), int(d.clock), d.leaks, d.max_leaks + 1, d.killed, d.stolen, d.spilled])
	for i in d.stats.size():
		var s: Dictionary = d.stats[i]
		t.log_line("wave %d: sent %d (fliers %d), down %d (fliers %d), leaked %d, stolen %d" % [
			i + 1, s.sent, s.fliers, s.down, s.fliers_down, s.leaked, s.stolen])
	for name in d.defences:
		var e: Dictionary = d.defences[name]
		t.log_line("%-10s re-armed %3d  refilled %3d  fired %3d  kills %2d" % [name, e.rearms, e.refills, e.fires, e.kills])
	# where things died, in 100 px bands of the lane, and to what
	var bands := {}
	for k in d.deaths:
		var b: int = int(k[0]) / 100 * 100
		if not bands.has(b):
			bands[b] = {}
		bands[b][k[1]] = bands[b].get(k[1], 0) + 1
	var keys := bands.keys()
	keys.sort()
	for b in keys:
		t.log_line("  down at x %d-%d: %s" % [b, b + 99, str(bands[b])])
	t.log_line("machine: dispensed %d, delivered to defences %d, stolen %d, spilled %d, jams %d" % [
		p.dispenser.dropped, d.output(), d.stolen, d.spilled, jammed.size()])
	t.log_line("spectacle: bowl %d, sling %d, balloon %d, sorter %d iron, plunge %d, loop %d (fell %d), jump %d (short %d), bumpers %s" % [
		p.bowl.fed, p.sling.thrown, p.balloon.lifted, p.magrail.carried, p.plunge.carried, p.loop.looped, p.loop.fell,
		p.jump.landed, p.jump.fell, str(p.bumpers.map(func(b): return b.kicks))])
	t.log_line("gates: port %s wreck %s gabion %s spring %s flak %s  |  wires: wreck %d port %d  |  flak shots %d downed %d" % [
		p.g_port.sent, p.g_wreck.sent, p.g_gabion.sent, p.g_spring.sent, p.g_flak.sent,
		p.wire_wreck.tripped, p.wire_port.tripped, p.flak.shots, p.flak.downed])
