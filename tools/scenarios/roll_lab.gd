extends RefCounted
## Rolling lab: ore launched along a level chute (and along flat terrain) in
## side-by-side lanes far off the map, logging speed every 50 px, so the
## losses of each damping / friction setting can be compared directly.
## ROLL_LAB=variants runs the damping/friction matrix (root-cause hunt);
## otherwise it runs the stock physics only (before/after comparison).


static func _lane(t, i: int, cfg: Dictionary, lanes: Array) -> void:
	var origin := Vector2(-6000, -4000 + i * 70)
	var terrain: bool = cfg.get("terrain", false)
	var length := 200.0
	var drop: float = cfg.get("drop", 0.0)
	if terrain:
		var sb := StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = Vector2(-40, 0)
		seg.b = Vector2(length + 400, 0)
		cs.shape = seg
		sb.add_child(cs)
		sb.position = origin
		t.main.add_child(sb)
	else:
		# one long rail (no lip: a level rail puts its stop at the far end);
		# the first 200 px are measured, the rest is runway
		var c: Node2D = preload("res://scenes/chute.gd").new()
		c.has_lip = false
		c.on_track = false   # a physics lab: the chute stays physics (scenes/chute.gd is track now)
		c.end_offset = Vector2(length + 200.0, drop * 2.0)
		c.position = origin
		t.main.add_child(c)
		if cfg.has("fric") or cfg.has("absorb"):
			var m := PhysicsMaterial.new()
			m.bounce = 0.5
			m.absorbent = cfg.get("absorb", true)
			m.friction = cfg.get("fric", 1.0)
			c._body.physics_material_override = m
	var o: RigidBody2D
	var r := 8.0
	if cfg.get("ingot", false):
		o = preload("res://scenes/ingot.tscn").instantiate()
		o.kind = cfg.get("kind", "copper")
	else:
		o = preload("res://scenes/ore.tscn").instantiate()
		o.kind = cfg.get("kind", "copper")
		r = o.KINDS[o.kind].radius
	o.global_position = origin + Vector2(12, -r - 0.3)
	t.main.add_child(o)
	if cfg.has("adamp"):
		o.set_physics_process(false)   # its own on-track damping switch would override this
		o.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		o.angular_damp = cfg.adamp
	if cfg.has("ldamp"):
		o.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		o.linear_damp = cfg.ldamp
	var v0: float = cfg.v0
	o.linear_velocity = Vector2(v0, 0)
	o.angular_velocity = v0 / r   # already rolling, no skid on the first contact
	lanes.append({"o": o, "x0": origin.x, "cfg": cfg, "marks": [], "next": 50.0, "t0": 0.0, "slept": -1.0, "stop_x": 0.0})


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	t.log_line("defaults: linear_damp=%s angular_damp=%s gravity=%s tick=%s" % [
		ProjectSettings.get_setting("physics/2d/default_linear_damp"),
		ProjectSettings.get_setting("physics/2d/default_angular_damp"),
		ProjectSettings.get_setting("physics/2d/default_gravity"),
		Engine.physics_ticks_per_second])
	var cfgs: Array = []
	var variants := OS.get_environment("ROLL_LAB") == "variants"
	for v0 in [150.0, 400.0]:
		cfgs.append({"name": "stock copper", "v0": v0})
		cfgs.append({"name": "stock iron", "v0": v0, "kind": "iron"})
		cfgs.append({"name": "stock gear", "v0": v0, "kind": "gear"})
		cfgs.append({"name": "stock shot", "v0": v0, "kind": "shot"})
		cfgs.append({"name": "stock copper 2px drop", "v0": v0, "drop": 2.0})
		cfgs.append({"name": "stock copper TERRAIN", "v0": v0, "terrain": true})
		cfgs.append({"name": "stock iron TERRAIN", "v0": v0, "terrain": true, "kind": "iron"})
		cfgs.append({"name": "ingot copper", "v0": v0, "ingot": true})
		cfgs.append({"name": "ingot iron", "v0": v0, "ingot": true, "kind": "iron"})
		cfgs.append({"name": "ingot copper TERRAIN", "v0": v0, "ingot": true, "terrain": true})
		if variants:
			cfgs.append({"name": "adamp=0 (replace)", "v0": v0, "adamp": 0.0})
			cfgs.append({"name": "adamp=0 ldamp=0", "v0": v0, "adamp": 0.0, "ldamp": 0.0})
			cfgs.append({"name": "adamp=0.2", "v0": v0, "adamp": 0.2})
			cfgs.append({"name": "adamp=0.5", "v0": v0, "adamp": 0.5})
			cfgs.append({"name": "ldamp=0 only", "v0": v0, "ldamp": 0.0})
			cfgs.append({"name": "chute fric 0.3", "v0": v0, "fric": 0.3})
			cfgs.append({"name": "chute fric 0", "v0": v0, "fric": 0.0})
			cfgs.append({"name": "chute not absorbent", "v0": v0, "absorb": false})
			cfgs.append({"name": "adamp=0 ldamp=0 fric 0", "v0": v0, "adamp": 0.0, "ldamp": 0.0, "fric": 0.0})
			cfgs.append({"name": "adamp=0 iron", "v0": v0, "adamp": 0.0, "kind": "iron"})
			cfgs.append({"name": "adamp=0 TERRAIN", "v0": v0, "adamp": 0.0, "terrain": true})
	var lanes: Array = []
	for i in cfgs.size():
		_lane(t, i, cfgs[i], lanes)
	var clock := 0.0
	while clock < 6.0:
		await t.physics_frame
		clock += 1.0 / Engine.physics_ticks_per_second
		for L in lanes:
			if not is_instance_valid(L.o):
				if not L.has("gone"):
					L.gone = clock
				continue
			var o: RigidBody2D = L.o
			var dx: float = o.global_position.x - L.x0 - 12.0
			while L.next <= 200.0 and dx >= L.next:
				L.marks.append("%d@%.2fs=%d" % [int(L.next), clock, int(o.linear_velocity.length())])
				L.next += 50.0
			if L.slept < 0 and (o.sleeping or o.linear_velocity.length() < 2.0):
				L.slept = clock
				L.stop_x = dx
	for L in lanes:
		var cfg: Dictionary = L.cfg
		var tail := ""
		if L.slept >= 0:
			tail = "  stopped %.2fs at %d px" % [L.slept, int(L.stop_x)]
		var sleep_note := ""
		if is_instance_valid(L.o):
			sleep_note = " asleep=%s" % L.o.sleeping
		else:
			sleep_note = " GONE at %.2fs" % L.gone
		t.log_line("ROLL v0=%d %-26s %s%s%s" % [int(cfg.v0), cfg.name, " ".join(L.marks), tail, sleep_note])
