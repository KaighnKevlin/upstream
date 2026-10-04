extends RefCounted
## Factory mode (title key F): the build bar shows exactly Tech.START, a
## locked piece's hotkey is refused, a lab fed 5 red flasks researches a
## tier-1 tech (its pieces join the bar, an UNLOCKED banner), the research
## screen lays the tree out by tier, save -> load keeps it all (and a
## version-1 save still loads, as a sandbox one: set_allowed([]) gives the
## full bar back), and the siege still starts with its own bar.
## Logs "FAIL ..." per broken check and "factory mode: ALL OK" if none.

const Tech = preload("res://scripts/tech.gd")
const Lab = preload("res://scenes/lab.gd")
const Save = preload("res://scripts/sandbox_save.gd")
const TEST_SAVE := "user://factory_mode_rec_save.json"


static func _bar(t) -> Node:
	for c in t.main.get_node("CanvasLayer").get_children():
		if c.get_script() == preload("res://scripts/build_bar.gd"):
			return c
	return null


static func _shown(bar) -> Array:
	var out := []
	for c in bar.CATS:
		out.append_array(c[1])
	return out


static func _title_key(t, code: Key) -> void:
	t.main._show_title()
	await t.wait(0.6)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	t.main._on_title_input(ev)
	await t.wait(1.5)


static func run(t) -> void:
	var fails := []
	Tech.levels.clear()
	Lab.tree_progress.clear()
	Lab.progress.clear()
	Save.path = TEST_SAVE
	var bs = t.main.get_node("/root/BuildSystem")
	var bar = _bar(t)
	var full: int = _shown(bar).size()

	# 1. title key F -> Factory, the bar is START
	await _title_key(t, KEY_F)
	var shown := _shown(bar)
	t.log_line("key F: factory=%s sandbox=%s god_label=%s waves_started=%s" % [t.main.factory, t.main.sandbox, t.main._god_label != null, t.main._waves_started])
	t.log_line("bar: %d pieces (full bar %d): %s" % [shown.size(), full, ", ".join(shown.map(func(id): return Tech.piece_name(id)))])
	t.log_line("tabs: %s" % [bar.CATS.map(func(c): return "%s:%d" % [c[0], c[1].size()])])
	if not t.main.factory or t.main.sandbox or t.main._god_label != null:
		fails.append("factory flags")
	var start_sorted: Array = Tech.START.duplicate()
	start_sorted.sort()
	var shown_sorted := shown.duplicate()
	shown_sorted.sort()
	if shown_sorted != start_sorted:
		fails.append("bar %s != START %s" % [shown_sorted, start_sorted])
	await t.shot("factory_start_bar")

	# 2. a locked hotkey (0: the physics splitter, cut) is refused; an unlocked one (2: tapper) works
	await t.tap(KEY_0)
	await t.wait(0.2)
	var refused: bool = bs.current_build == 0
	await t.tap(KEY_2)
	await t.wait(0.2)
	var tapper: bool = bs.current_build == 2
	bs._set_build(0)
	await t.wait(0.1)
	t.log_line("hotkey 0 (splitter, cut) refused: %s; hotkey 2 (vein tapper) allowed: %s" % [refused, tapper])
	if not refused or not tapper:
		fails.append("hotkeys")

	# 3. a lab and 5 red flasks -> Routing
	var lab: Node2D = preload("res://scenes/lab.tscn").instantiate()
	lab.global_position = Vector2(1500, 60)
	t.main.add_child(lab)
	bs._placed_buildings.append(lab)
	await t.wait(0.4)
	t.log_line("new lab picked: '%s', label '%s'" % [lab.tree_id, lab._label.text])
	lab.tree_id = "routing"
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = lab.global_position + Vector2(0, -40)
	# a copper ore and a gear first: not science, spat back
	for k in ["copper", "gear"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = lab.global_position + Vector2(-11, -70)
		t.main.add_child(o)
		await t.wait(0.5)
	for k in 6:   # one more than it needs: the sixth is refused
		var f: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		f.kind = "flask"
		f.global_position = lab.global_position + Vector2(-11, -70)
		t.main.add_child(f)
		await t.wait(0.5)
	t.log_line("lab holds %s, label '%s'" % [lab._held, lab._label.text])
	Engine.time_scale = 4.0
	var waited := 0.0
	while not Tech.researched("routing") and waited < 40.0:
		await t.wait(0.1)
		waited += 0.1
	Engine.time_scale = 1.0
	await t.wait(0.6)
	var after := _shown(bar)
	var gained := after.filter(func(id): return not Tech.START.has(id))
	t.log_line("routing researched: %s after %.1f game s; bar now %d: +%s" % [Tech.researched("routing"), waited, after.size(), ", ".join(gained.map(func(id): return Tech.piece_name(id)))])
	t.log_line("banner: '%s' / '%s'; lab now on '%s' label '%s'" % [t.main._banner_title.text, t.main._banner_sub.text, lab.tree_id, lab._label.text])
	await t.shot("unlock_banner")
	if not Tech.researched("routing"):
		fails.append("routing not researched")
	var routing: Array = Tech.tree_tech("routing").unlocks
	if gained.size() != routing.size() or not routing.all(func(id): return after.has(id)):
		fails.append("bar after routing: gained %s, want %s" % [gained, routing])
	if t.main._banner_title.text != "UNLOCKED" or not t.main._banner_sub.text.to_lower().contains("splitter"):
		fails.append("banner")
	# the old physics splitter (hotkey 0) is cut from Factory: Routing gives the track splitter
	await t.tap(KEY_0)
	await t.wait(0.2)
	t.log_line("hotkey 0 (cut physics splitter) after Routing: %s" % ["allowed" if bs.current_build == 10 else "refused"])
	if bs.current_build == 10:
		fails.append("cut splitter allowed")
	bs._set_build(0)
	await t.wait(0.1)

	# 4. the research screen, by tier (a little progress on Buffers to show)
	Lab.tree_progress["buffers"] = {"flask": 2}
	lab.tree_id = "buffers"
	lab._update_label()
	lab.open_panel()
	await t.wait(0.3)
	var panel = t.main.get_node("TechPanel")
	t.log_line("research screen: %d tech rows (TREE %d)" % [panel._rows.size(), Tech.TREE.size()])
	if panel._rows.size() != Tech.TREE.size():
		fails.append("tree rows")
	await t.shot("research_tree")
	# a greyed one (Forging: needs Processing and clockwork science) can't be picked; Sorting can
	panel._on_tree_input(t._click(), "forging")
	await t.wait(0.1)
	var forging_refused: bool = lab.tree_id == "buffers"
	lab.open_panel()
	await t.wait(0.1)
	panel._on_tree_input(t._click(), "sorting")
	await t.wait(0.1)
	t.log_line("pick greyed Forging refused: %s; pick Sorting: lab on '%s'" % [forging_refused, lab.tree_id])
	if not forging_refused or lab.tree_id != "sorting":
		fails.append("panel picks")
	lab.tree_id = "buffers"

	# 5. save -> wreck -> load: still Factory, Routing still unlocked, Buffers 2/5
	var n: int = Save.save(t.main)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	t.log_line("saved %d pieces: version %s mode %s tree_progress %s tech %s" % [n, saved.version, saved.mode, saved.tree_progress, saved.tech])
	Tech.levels.clear()
	Lab.tree_progress.clear()
	t.main.leave_factory()
	await t.wait(0.2)
	t.log_line("wrecked: factory=%s bar %d" % [t.main.factory, _shown(bar).size()])
	var m: int = await Save.load_into(t.main)
	await t.wait(0.3)
	var lab2 = null
	for b in bs._placed_buildings:
		if is_instance_valid(b) and b.get_script() == Lab:
			lab2 = b
	var loaded := _shown(bar)
	t.log_line("loaded %d pieces: factory=%s sandbox=%s routing=%s bar %d, buffers progress %s, lab on '%s' label '%s'" % [m,
		t.main.factory, t.main.sandbox, Tech.researched("routing"), loaded.size(), Lab.tree_progress.get("buffers"),
		lab2.tree_id if lab2 else "?", lab2._label.text if lab2 else "?"])
	if not t.main.factory or not Tech.researched("routing") or loaded.size() != after.size() or Lab.tree_progress.get("buffers", {}).get("flask", 0) != 2:
		fails.append("save/load")

	# 6. a version-1 save (lab_progress as ints, no mode) loads as a sandbox one: full bar back
	var old: Dictionary = saved.duplicate(true)
	old.version = 1
	old.erase("mode")
	old.erase("tree_progress")
	old.tech = {"barrels": 1}
	old.lab_progress = {"hook": 2}
	for p in old.pieces:
		p.props.erase("tree_id")
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var k: int = await Save.load_into(t.main)
	await t.wait(0.3)
	var full_again := _shown(bar).size()
	t.log_line("v1 save: loaded %d pieces, factory=%s sandbox=%s god_label=%s, barrels %d, hook progress %s, bar %d (full %d), allowed %d" % [k,
		t.main.factory, t.main.sandbox, t.main._god_label != null, Tech.level("barrels"), Lab.progress.get("hook"), full_again, full, bar.allowed.size()])
	if k < 0 or t.main.factory or not t.main.sandbox or Tech.level("barrels") != 1 or Lab.progress.get("hook") != 2 or full_again != full:
		fails.append("v1 load / full bar")

	# 7. the siege still starts with its own bar
	await _title_key(t, KEY_EQUAL)
	await t.wait(2.0)
	var siege := _shown(bar)
	siege.sort()
	var want: Array = t.main.SIEGE_BAR.duplicate()
	want.sort()
	t.log_line("key =: siege=%s factory=%s bar %d (SIEGE_BAR %d) same=%s" % [t.main._siege != null, t.main.factory, siege.size(), want.size(), siege == want])
	if siege != want:
		fails.append("siege bar")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Save.path = Save.PATH
	for x in fails:
		t.log_line("FAIL " + x)
	if fails.is_empty():
		t.log_line("factory mode: ALL OK")
