extends RefCounted
## The field manual (F1): opens it the way a player does, then screenshots
## every tab and every page of it, to check nothing overflows or overlaps.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.5)
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)
	await t.wait(0.3)
	var m: CanvasLayer = t.main.get_node_or_null("Manual")
	if m == null or not m.visible:
		t.log_line("F1 didn't open the manual; opening it directly")
		t.main.open_manual()
		m = t.main.get_node("Manual")
	# every line must fit its label (they clip): names 200 px, text 500 px
	var font: Font = preload("res://scripts/pixel_font.gd").get_font()
	var too_wide := 0
	for tab in m.TABS:
		for e in tab[1]:
			var wn := font.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var wd := font.get_string_size(e[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			if wn > 200 or wd > 500:
				too_wide += 1
				t.log_line("TOO WIDE (%d/%d px): %s: %s" % [wn, wd, e[1], e[2]])
	t.log_line("%d lines too wide" % too_wide)
	# a tab too long for two columns spills onto further pages
	var long := [["#", "A", ""]]
	for k in 40:
		long.append(["", "piece %d" % k, "x"])
	var lc: Array = m._columns(long)
	t.log_line("41-row section -> %d columns of %s" % [lc.size(), str(lc.map(func(c): return c.size()))])
	for i in m.TABS.size():
		m._tab = i
		m._page = 0
		m._build()
		var pages: int = m._pages()
		for p in pages:
			m._page = p
			m._build()
			await t.wait(0.2)
			var name := "tab%d_page%d" % [i, p + 1]
			await t.shot(name)
			t.log_line("%s: %s, %d entries, page %d/%d" % [name, m.TABS[i][0], m.TABS[i][1].size(), p + 1, pages])
