extends RefCounted
## Heat and the crucible. Ingots cool from white-hot to cold over
## Ingot.COOL s; a crucible fuses a hot copper bar and a hot iron bar into
## bronze, tipping out anything that lands cold (or goes cold waiting).
## Four setups, each fed the same jittered ore schedule (a copper and an
## iron ore every FEED_MEAN s, +-FEED_JIT, independently) for FEED s:
##
##   A  unsynced, unequal runs: copper smelts up top and comes down a
##      chute and a long brake rail (~7 s); iron on a short rail by the pot
##   B  unsynced, equal runs: a short rail each side of the pot
##   C  synced: the ore goes through a pair gate first (cold ore waits
##      happily), one copper with each iron, onto the long zig-zag line
##   D  reheat: a cold copper bar dropped in (tipped out); then a cold
##      copper and a cold iron bar rolled over a furnace rail into it
##
## Logs heat at arrival, bronze made, rejects by cause, bronze per minute.


const FEED := 36.0
const FEED_MEAN := 2.2
const FEED_JIT := 0.8
const DRAIN := 10.0
const POT := Vector2(1300, 576)
const CRUCIBLE := "res://scenes/crucible.tscn"
const RAIL := "res://scenes/furnace_rail.tscn"


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	t.log_line("heat: Ingot.COOL=%.1f s, crucible needs %s, melt %.1f s" % [preload("res://scenes/ingot.gd").COOL, {"copper": 1, "iron": 1}, preload("res://scenes/crucible.gd").MELT])
	for phase in ["A", "B", "C"]:
		await _phase(t, cam, phase)
	await _reheat(t, cam)
	await _dome(t)


static func _reset(t) -> void:
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	for g in ["ore", "ingots"]:
		for o in t.get_nodes_in_group(g):
			o.queue_free()
	await preload("res://scripts/marble_works.gd").carve(t.main, false)


static func _rail(t, a: Vector2, off: Vector2) -> Node2D:
	var fr: Node2D = load(RAIL).instantiate()
	fr.end_offset = off
	return preload("res://scripts/sandbox_showcase.gd")._add_node(t.main, fr, a)


## The long line: a furnace rail up top, a chute back under it, then a
## long brake rail (150 px/s, so it drops into the pot rather than over it)
## to the pot's left side: ~7 s from smelting to the pot. Returns the rail.
static func _long_line(t) -> Node2D:
	var MW = preload("res://scripts/marble_works.gd")
	var r := _rail(t, Vector2(960, 380), Vector2(180, 12))
	MW._chute(t.main, Vector2(1170, 408), Vector2(970, 448))
	var br: Node2D = load("res://scenes/brake.tscn").instantiate()
	br.end_offset = Vector2(340, 43)
	br.mode = 1
	preload("res://scripts/sandbox_showcase.gd")._add_node(t.main, br, Vector2(935, 462))
	return r


static func _ore(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	t.main.add_child(o)
	return o


static func _schedule(seed: int) -> Array:
	# [time, kind] for FEED s: copper and iron each on their own jittered clock
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	for k in ["copper", "iron"]:
		var at := rng.randf_range(0.0, FEED_MEAN)
		while at < FEED:
			out.append([at, k])
			at += FEED_MEAN + rng.randf_range(-FEED_JIT, FEED_JIT)
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


static func _phase(t, cam: Camera2D, phase: String) -> void:
	await _reset(t)
	var MW = preload("res://scripts/marble_works.gd")
	var pot: Node2D = MW._piece(t.main, CRUCIBLE, POT, {"side": -1.0})
	var rails := []
	var drop := {}          # kind -> where its ore is dropped
	var gate: Node2D = null
	match phase:
		"A":
			rails = [_long_line(t), _rail(t, Vector2(1470, 452), Vector2(-150, 10))]
			drop = {"copper": Vector2(968, 368), "iron": Vector2(1462, 440)}
			cam.zoom = Vector2(2.0, 2.0)
			cam.global_position = Vector2(1200, 440)
		"B":
			rails = [_rail(t, Vector2(1130, 452), Vector2(150, 10)), _rail(t, Vector2(1470, 452), Vector2(-150, 10))]
			drop = {"copper": Vector2(1138, 440), "iron": Vector2(1462, 440)}
			cam.zoom = Vector2(2.4, 2.4)
			cam.global_position = Vector2(1300, 500)
		"C":
			rails = [_long_line(t)]
			gate = MW._piece(t.main, "res://scenes/pair_gate.tscn", Vector2(985, 345))
			drop = {"copper": Vector2(963, 330), "iron": Vector2(1007, 330)}
			cam.zoom = Vector2(2.0, 2.0)
			cam.global_position = Vector2(1200, 440)
	await t.wait(0.3)
	var fed := {"copper": 0, "iron": 0}
	var sched := _schedule(11)
	var t0 := Time.get_ticks_msec() / 1000.0
	var shot_done := false
	for s in sched:
		var dt: float = s[0] - (Time.get_ticks_msec() / 1000.0 - t0)
		if dt > 0:
			await t.wait(dt)
		_ore(t, s[1], drop[s[1]])
		fed[s[1]] += 1
		if not shot_done and Time.get_ticks_msec() / 1000.0 - t0 > 14.0:
			shot_done = true
			await t.shot("heat_%s" % phase)
	var rest: float = FEED - (Time.get_ticks_msec() / 1000.0 - t0)
	if rest > 0:
		await t.wait(rest)
	await t.wait(DRAIN)
	if phase == "A":
		cam.zoom = Vector2(3.0, 3.0)
		cam.global_position = POT + Vector2(0, -40)
		await t.shot("heat_A_pot")
	# report
	var smelted := 0
	for r in rails:
		smelted += r.smelted
	var by := {}
	var heat := {"copper": [], "iron": []}
	for e in pot.events:
		by[e[2]] = by.get(e[2], 0) + 1
		if e[2] == "taken":
			heat[e[0]].append(e[1])
	var names := {"A": "unsynced, unequal runs (long copper line, short iron)", "B": "unsynced, equal short runs", "C": "pair gate on the ore, one shared long line"}
	t.log_line("heat %s: %s" % [phase, names[phase]])
	t.log_line("heat %s: fed copper %d iron %d ore | smelted %d | pot events %s" % [phase, fed.copper, fed.iron, smelted, by])
	for k in heat:
		var h: Array = heat[k]
		var mean := 0.0
		for v in h:
			mean += v
		mean = mean / maxf(1, h.size())
		var lo = h.min() if not h.is_empty() else 0.0
		t.log_line("heat %s: %s taken hot x%d, heat at arrival mean %.2f min %.2f (age %.1f s mean)" % [phase, k, h.size(), mean, lo, (1.0 - mean) * preload("res://scenes/ingot.gd").COOL])
	var cold_heat := []
	for e in pot.events:
		if e[2] != "taken":
			cold_heat.append("%s:%s:%.2f" % [e[0].substr(0, 2), e[2], e[1]])
	t.log_line("heat %s: rejects %s" % [phase, cold_heat])
	var ing: Array = t.get_nodes_in_group("ingots")
	var bronze := ing.filter(func(o): return o.kind == "bronze").size()
	t.log_line("heat %s: BRONZE %d (in world %d) | rejected %d (landed cold/surplus) + %d cooled waiting | bronze/min %.1f of a possible %.1f | gate pairs %s" % [phase, pot.made, bronze, pot.rejected, pot.cooled, pot.made * 60.0 / FEED, mini(fed.copper, fed.iron) * 60.0 / FEED, gate.pairs if gate else "-"])


static func _reheat(t, cam: Camera2D) -> void:
	await _reset(t)
	var MW = preload("res://scripts/marble_works.gd")
	var pot: Node2D = MW._piece(t.main, CRUCIBLE, POT, {"side": -1.0})
	var rail := _rail(t, Vector2(1470, 452), Vector2(-150, 10))
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1360, 500)
	await t.wait(0.3)
	var I := preload("res://scenes/ingot.tscn")
	# a cold bar dropped straight in: tipped out
	var cold: RigidBody2D = I.instantiate()
	cold.kind = "copper"
	cold.heat = 0.0
	cold.lifetime = 1.0e9
	cold.global_position = POT + Vector2(0, -80)
	t.main.add_child(cold)
	await t.wait(1.5)
	t.log_line("heat D: cold copper (heat %.2f) dropped in -> pot events %s, bronze %d" % [cold.heat, pot.events, pot.made])
	# a cold copper and a cold iron over the furnace rail, into the pot
	var bars := []
	for k in ["copper", "iron"]:
		var b: RigidBody2D = I.instantiate()
		b.kind = k
		b.heat = 0.0
		b.lifetime = 1.0e9
		b.global_position = rail.global_position + Vector2(-8, -12)
		t.main.add_child(b)
		bars.append(b)
		await t.wait(0.8)
	var peak := [0.0, 0.0]
	for i in 40:
		await t.physics_frame
		for j in 2:
			if is_instance_valid(bars[j]):
				peak[j] = maxf(peak[j], bars[j].heat)
		if i == 20:
			await t.shot("heat_D_reheat")
	await t.wait(2.5)
	await t.shot("heat_D_pot")
	t.log_line("heat D: cold copper + cold iron (heat 0.00) rolled over the furnace rail: peak heat %.2f / %.2f; pot events %s; BRONZE %d" % [peak[0], peak[1], pot.events.slice(1), pot.made])


static func _dome(t) -> void:
	# bronze into the dome: three repair stock for one bar
	var rc: Area2D = t.main.get_node("Receiver")
	var before: int = rc.buffer
	for k in ["copper", "bronze"]:
		var b: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		b.kind = k
		b.global_position = rc.global_position + Vector2(0, -30)
		t.main.add_child(b)
		await t.wait(1.2)
		t.log_line("heat dome: a %s ingot in -> buffer %d -> %d" % [k, before, rc.buffer])
		before = rc.buffer
