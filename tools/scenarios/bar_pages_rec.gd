extends RefCounted
## Build bar paging: a tab given 15 pieces pages 12 at a time with an arrow.


static func run(t) -> void:
	await t.wait(0.3)
	var bar: Control = t.main.get_node("CanvasLayer").get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "build_bar.gd")[0]
	var logic: Array = bar.CATS[6][1]
	var extra := [1, 9, 12]
	for x in extra:
		logic.append(x)                 # (CATS is const, but its arrays can grow for the test)
	bar._cat = 6
	bar._page = 0
	bar._layout()
	await t.wait(0.2)
	await t.shot("bar_page1")
	t.log_line("page 1 shows %d, paged %s, pages %d" % [bar._shown().size(), bar._paged(), bar._pages()])
	bar._page = 1
	bar._layout()
	await t.wait(0.2)
	await t.shot("bar_page2")
	t.log_line("page 2 shows %s" % [bar._shown()])
	# selecting a piece on page 1 from page 2 flips back
	t.main.get_node("/root/BuildSystem")._set_build(logic[0])
	await t.wait(0.1)
	t.log_line("after selecting the first piece: page %d" % (bar._page + 1))
	t.main.get_node("/root/BuildSystem")._set_build(0)
