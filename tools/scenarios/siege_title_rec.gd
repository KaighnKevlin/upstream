extends RefCounted
## The title screen, then a key (TITLE_KEY: "=" by default, the Marble
## Siege; "8" etc. for the other worlds): does it start, and for the siege,
## is the bar curated, are the god tools off, is the camera framed?


static func run(t) -> void:
	var k: String = OS.get_environment("TITLE_KEY") if OS.has_environment("TITLE_KEY") else "="
	t.main._show_title()
	await t.wait(1.0)
	await t.shot("title")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_EQUAL if k == "=" else OS.find_keycode_from_string(k)
	t.main._on_title_input(ev)
	await t.wait(4.0)
	await t.shot("after_title_%s" % k)
	var bar = null
	for c in t.main.get_node("CanvasLayer").get_children():
		if c.get_script() == preload("res://scripts/build_bar.gd"):
			bar = c
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	t.log_line("key %s: siege=%s sandbox=%s god_label=%s showcase=%d cam top_level=%s zoom=%s tabs=%s" % [k,
		t.main._siege != null, t.main.sandbox, t.main._god_label != null,
		t.get_nodes_in_group("showcase").size(), cam.top_level, cam.zoom, bar.CATS.map(func(c): return "%s:%d" % [c[0], c[1].size()])])
	if t.main._siege:
		var bs = t.main.get_node("/root/BuildSystem")
		bs._set_build(7)          # spikes: not on the siege bar
		await t.wait(0.2)
		var refused: bool = bs.current_build == 0
		bs._set_build(114)        # the gabion: on it
		await t.wait(0.2)
		t.log_line("hotkey off the bar refused: %s; gabion allowed: %s" % [refused, bs.current_build == 114])
		bs._set_build(0)
		await t.wait(20.0)
		t.log_line("siege after 20 s: wave %d clock %.0f output %d" % [t.main._siege.wave, t.main._siege.clock, t.main._siege.output()])
