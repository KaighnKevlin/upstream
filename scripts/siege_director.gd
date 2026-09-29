extends Node2D
## Runs Marble Siege (scripts/siege_works.gd): WAVES of walkers in from the
## right wall on a clock, with magpies raiding the machine, for the vault at
## the left. A walker past the vault door is a leak; more than MAX_LEAKS and
## the vault's broken. Hold through the last wave and it's won.
## Also keeps the tally the HUD line and the playtest read: per wave (sent,
## down, leaked), per defence (re-armed / refilled, kills) and the machine's
## output (pieces delivered into the defences).

signal finished(won: bool)
signal wave_started(n: int)

const Enemy = preload("res://scenes/enemy.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

## Each wave: when it starts (s from the siege start) and who, in order.
## MAGPIE is a flier that raids the machine for pieces; the rest walk.
var waves: Array = [
	{"at": 25.0, "who": ["SOLDIER", "SCUTTLER", "SOLDIER", "SOLDIER", "SCUTTLER", "SOLDIER"]},
	{"at": 60.0, "who": ["SCUTTLER", "SOLDIER", "SCUTTLER", "MAGPIE", "SOLDIER", "SHIELDBEARER", "SCUTTLER", "SOLDIER"]},
	{"at": 95.0, "who": ["SHIELDBEARER", "SOLDIER", "MAGPIE", "SCUTTLER", "SCUTTLER", "SOLDIER", "SHIELDBEARER", "SCUTTLER", "SOLDIER", "MAGPIE"]},
	{"at": 132.0, "who": ["TITAN", "SCUTTLER", "SCUTTLER", "SOLDIER", "MAGPIE", "SOLDIER", "SHIELDBEARER", "SCUTTLER", "SOLDIER", "SHIELDBEARER", "MAGPIE", "SCUTTLER"]},
	{"at": 170.0, "who": ["SOLDIER", "SHIELDBEARER", "MAGPIE", "SOLDIER", "SCUTTLER", "TITAN", "SCUTTLER", "MAGPIE", "SHIELDBEARER", "SOLDIER", "SCUTTLER", "TITAN", "SOLDIER"]},
	{"at": 210.0, "who": ["TITAN", "SCUTTLER", "SCUTTLER", "SCUTTLER", "SOLDIER", "TITAN", "SHIELDBEARER", "MAGPIE", "TITAN", "SOLDIER", "SHIELDBEARER", "MAGPIE", "SOLDIER", "SCUTTLER", "TITAN", "SCUTTLER", "MAGPIE", "SOLDIER"]},
	{"at": 250.0, "who": ["TITAN", "SHIELDBEARER", "TITAN", "SOLDIER", "MAGPIE", "TITAN", "SCUTTLER", "SCUTTLER", "SHIELDBEARER", "SOLDIER", "MAGPIE", "TITAN", "SOLDIER", "SCUTTLER", "SHIELDBEARER", "MAGPIE", "SCUTTLER", "SOLDIER", "TITAN", "SCUTTLER"]},
]
var every := 1.3                 # s between arrivals within a wave
## gilded elites (twice the health): from this wave, every Nth walker; later waves every 2nd
var gild_from := 3
var spawn_at := Vector2(2130, 560)
var flier_at := Vector2(2130, 230)
var vault_x := 1340.0
var floor_y := 576.0
var max_leaks := 4                # the vault breaks on the fifth
var parts := {}                  # siege_works.gd: the pieces, by role

var clock := 0.0
var wave := 0                    # waves started
var leaks := 0
var killed := 0
var stolen := 0                  # pieces magpies got away with
var spilled := 0                 # pieces swept off the lane floor
var deaths: Array = []           # [x, who killed it, type] for every walker and flier downed
var over := false
var won := false
var stats: Array = []            # per wave: {sent, down, leaked, fliers, fliers_down}
var defences := {}               # name -> {node, rearms, refills, kills}
var _queue: Array = []           # [time, type, wave index]
var _live := {}                  # instance id -> {node, wave, flier, hp, src, src_t, limp}
var _counters := {}              # name -> last seen counter values
var _still := {}                 # ore id -> seconds lying still on the floor
var _keep: Array = []            # points where pieces are meant to wait (pockets)
var _label: Label
var _sweep_t := 0.0


func _ready() -> void:
	z_index = 3
	for i in waves.size():
		stats.append({"sent": 0, "down": 0, "leaked": 0, "fliers": 0, "fliers_down": 0, "stolen": 0})
	# the HUD line, top left under the panel
	var hud := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if hud:
		_label = Label.new()
		_label.add_theme_font_override("font", PixelFont.get_font())
		_label.add_theme_font_size_override("font_size", 20)
		_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.66))
		_label.add_theme_color_override("font_shadow_color", Color(0.09, 0.07, 0.05, 0.9))
		_label.add_theme_constant_override("shadow_offset_x", 2)
		_label.add_theme_constant_override("shadow_offset_y", 2)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.08, 0.06, 0.05, 0.72)
		back.set_content_margin_all(6)
		_label.add_theme_stylebox_override("normal", back)
		_label.position = Vector2(400, 8)
		hud.add_child(_label)
	_update_label()


## Registers a defence to be tallied. `kind` picks what counts as a re-arm.
func track(name: String, n: Node) -> void:
	defences[name] = {"node": n, "rearms": 0, "refills": 0, "kills": 0, "fires": 0}


## Pieces lying still near these points are stock, not spill.
func keep_point(p: Vector2) -> void:
	_keep.append(p)


func _exit_tree() -> void:
	if _label and is_instance_valid(_label):
		_label.queue_free()


func _physics_process(delta: float) -> void:
	if over:
		return
	clock += delta
	# waves on the clock
	while wave < waves.size() and clock >= waves[wave].at:
		var w: Dictionary = waves[wave]
		for i in w.who.size():
			_queue.append([w.at + i * every, w.who[i], wave])
		wave += 1
		wave_started.emit(wave)
	while not _queue.is_empty() and clock >= _queue[0][0]:
		var q: Array = _queue.pop_front()
		_spawn(q[1], q[2])
	var fired := _poll_defences()
	_watch_enemies(fired)
	_sweep(delta)
	if leaks > max_leaks:
		_end(false)
	elif wave >= waves.size() and _queue.is_empty() and _walkers_left() == 0:
		_end(true)
	_update_label()
	queue_redraw()


func _spawn(type: String, wi: int) -> void:
	var e: Node2D
	if type == "MAGPIE":
		e = preload("res://scenes/magpie.tscn").instantiate()
		e.global_position = flier_at + Vector2(0, randf_range(-30, 30))
		stats[wi].fliers += 1
		e.tree_exiting.connect(_magpie_gone.bind(e, wi))
	else:
		e = preload("res://scenes/enemy.tscn").instantiate()
		e.add_to_group("enemies")
		e.setup(Enemy.EnemyType[type])
		var nth: int = stats[wi].sent - stats[wi].fliers + 1   # this walker's place in its wave
		if wi + 1 >= gild_from and nth % (2 if wi + 1 >= 5 else 3) == 0:
			e.gilded = true
		e.global_position = spawn_at
		e.direction = -1.0
	e.add_to_group("siege")
	get_parent().add_child(e)
	stats[wi].sent += 1
	_live[e.get_instance_id()] = {"node": e, "wave": wi, "flier": type == "MAGPIE", "hp": e.hp,
		"src": "", "src_t": -99.0, "limp": 0, "type": type}


func _magpie_gone(m: Node, wi: int) -> void:
	if m.stolen > 0:
		stolen += m.stolen
		stats[wi].stolen += m.stolen


func _walkers_left() -> int:
	var n := 0
	for id in _live:
		if not _live[id].flier:
			n += 1
	return n


## Which defences acted this frame: [[name, position]].
func _poll_defences() -> Array:
	var fired := []
	for name in defences:
		var d: Dictionary = defences[name]
		var n = d.node
		if not is_instance_valid(n):
			continue
		var now := {}
		var hit_count := 0
		var rearmed := false
		var refill := 0
		var s: String = n.get_script().resource_path.get_file()
		match s:
			"spring_trap.gd":
				now.armed = n.armed
				hit_count = n.flung
			"wrecking_ball.gd":
				now.armed = n.armed
				hit_count = n.hits
			"portcullis.gd":
				now.armed = n.raised
				hit_count = n.crushed
			"gabion.gd":
				refill = n.took
				hit_count = n.knocked
			"caltrop_spreader.gd":
				refill = n.took
				hit_count = n.thrown
			"flak_cannon.gd":
				refill = n._took.size()
				hit_count = n.hits
			"igniter.gd":
				refill = n.lit
				hit_count = n.burst
		var last: Dictionary = _counters.get(name, {})
		if now.has("armed") and last.has("armed") and now.armed and not last.armed:
			d.rearms += 1
		if last.has("hits") and hit_count > last.hits:
			d.fires += hit_count - last.hits
			fired.append([name, n.global_position])
		if last.has("refill") and refill > last.refill:
			d.refills += refill - last.refill
		now.hits = hit_count
		now.refill = refill
		_counters[name] = now
	return fired


## Delivered into the defences: every piece a defence has taken in.
func output() -> int:
	var total := 0
	for name in defences:
		var d: Dictionary = defences[name]
		var n = d.node
		if not is_instance_valid(n):
			continue
		match n.get_script().resource_path.get_file():
			"spring_trap.gd":
				total += d.rearms * 2
			"wrecking_ball.gd", "portcullis.gd":
				total += d.rearms * 4
			_:
				total += d.refills
	return total


func _watch_enemies(fired: Array) -> void:
	for id in _live.keys():
		var r: Dictionary = _live[id]
		var e = r.node
		var gone: bool = not is_instance_valid(e) or e.is_queued_for_deletion() or ("_dying" in e and e._dying)
		if not gone and not r.flier and e.global_position.x < vault_x:
			leaks += 1
			stats[r.wave].leaked += 1
			_live.erase(id)
			e.queue_free()
			continue
		if not gone:
			# who hurt it: a defence that acted near it this frame, or its caltrop limp
			r.x = e.global_position.x
			var hp: int = e.hp
			var limp: int = e.get_meta("caltrop_limp", 0) if e.has_meta("caltrop_limp") else 0
			if hp < r.hp:
				var src := ""
				if limp > r.limp:
					src = "caltrops"
				else:
					var best := 110.0
					for f in fired:
						var dd: float = (f[1] as Vector2).distance_to(e.global_position)
						if dd < best:
							best = dd
							src = f[0]
					# bombs and flak shells burst away from the piece that fired them
					if src == "":
						for f in fired:
							if f[0] in ["igniter", "flak"]:
								src = f[0]
								break
				if src != "":
					r.src = src
					r.src_t = clock
			r.hp = hp
			r.limp = limp
			continue
		# gone without leaking: down
		_live.erase(id)
		if r.flier:
			if is_instance_valid(e) and "stolen" in e and e.stolen > 0:
				continue
			stats[r.wave].fliers_down += 1
		killed += 1
		stats[r.wave].down += 1
		var who: String = r.src if clock - r.src_t < 4.0 and r.src != "" else "other"
		if r.flier and who == "other":
			who = "flak" if defences.has("flak") else "other"
		deaths.append([int(r.get("x", -1)), who, r.type])
		if defences.has(who):
			defences[who].kills += 1
		else:
			if not defences.has("other"):
				defences["other"] = {"node": null, "rearms": 0, "refills": 0, "kills": 0, "fires": 0}
			defences["other"].kills += 1


## Loose pieces that come to rest on the lane floor (knocked out of a
## gabion, spilt past a full hopper) are swept after a while: they'd pile
## up for ever otherwise. Stock waiting in a pocket is left alone.
func _sweep(delta: float) -> void:
	_sweep_t -= delta
	if _sweep_t > 0:
		return
	_sweep_t = 0.5
	var seen := {}
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.gravity_scale == 0.0:
			continue
		if o.global_position.y < floor_y - 14 or o.linear_velocity.length() > 8.0:
			continue
		var kept := false
		for p in _keep:
			if (p as Vector2).distance_to(o.global_position) < 22.0:
				kept = true
				break
		if kept:
			continue
		var id: int = o.get_instance_id()
		seen[id] = _still.get(id, 0.0) + 0.5
		if seen[id] >= 8.0:
			spilled += 1
			o.queue_free()
			seen.erase(id)
	_still = seen


func _end(w: bool) -> void:
	over = true
	won = w
	_update_label()
	finished.emit(w)


func _update_label() -> void:
	if _label == null:
		return
	var head := "WAVE %d/%d" % [wave, waves.size()]
	if wave < waves.size():
		head += "  next in %ds" % int(maxf(0.0, waves[wave].at - clock))
	if over:
		head = "VAULT HELD" if won else "VAULT BROKEN"
	_label.text = "%s   leaks %d/%d   machine output %d   stolen %d" % [head, leaks, max_leaks + 1, output(), stolen]


func _draw() -> void:
	# the vault door, at the left
	var v := Vector2(vault_x, floor_y) - global_position
	draw_rect(Rect2(v + Vector2(-26, -60), Vector2(22, 60)), Color(0.1, 0.08, 0.07))
	draw_rect(Rect2(v + Vector2(-24, -58), Vector2(18, 58)), Color(0.55, 0.42, 0.25))
	draw_circle(v + Vector2(-15, -30), 5.0, Color(0.85, 0.65, 0.35))
	var font := ThemeDB.fallback_font
	draw_string(font, v + Vector2(-40, -70), "VAULT %d/%d" % [leaks, max_leaks + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1.0, 0.4, 0.3) if leaks > 0 else Color(0.85, 0.75, 0.55))
