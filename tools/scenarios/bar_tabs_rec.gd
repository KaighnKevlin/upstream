extends RefCounted
## Build bar: a screenshot of every tab and page, to check icons fit their slots.


static func run(t) -> void:
	await t.wait(0.3)
	var bar: Control = t.main.get_node("CanvasLayer").get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "build_bar.gd")[0]
	for c in bar.CATS.size():
		bar._cat = c
		bar._page = 0
		bar._layout()
		for p in bar._pages():
			bar._page = p
			bar._layout()
			await t.wait(0.15)
			await t.shot("tab%d_%s_p%d" % [c, bar.CATS[c][0].to_lower(), p + 1])
	t.log_line("bar tabs: %d tabs shot" % bar.CATS.size())
