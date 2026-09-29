extends RefCounted
## Panning box: a flume from (1250,520) running right 220 px with a panning
## box set in it mid-way; 9 grit and 2 iron dropped in at the head. The grit
## should be caught and washed into 3 copper nuggets that float over the
## weir; the iron should sink and wait at the weir as ever. A second box
## standing dry takes nothing from 3 grit dropped through it.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var f: Node2D = preload("res://scenes/flume.tscn").instantiate()
	f.global_position = Vector2(1250, 520)
	f.end_offset = Vector2(220, 0)
	t.main.add_child(f)
	var wet = MW._piece(t.main, "res://scenes/panning_box.tscn", Vector2(1360, 520))
	var dry = MW._piece(t.main, "res://scenes/panning_box.tscn", Vector2(1215, 470))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1350, 500)
	await t.wait(0.8)
	var grit := []
	var iron := []
	for k in 11:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.kind = "iron" if k == 3 or k == 7 else "grit"
		o.global_position = Vector2(1266 + (k % 3) * 6, 490)
		t.main.add_child(o)
		(iron if o.kind == "iron" else grit).append(o)
		await t.wait(0.25)
	# three more straight down through the dry one
	var dgrit := []
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.kind = "grit"
		o.global_position = Vector2(1211 + k * 4, 440)
		t.main.add_child(o)
		dgrit.append(o)
	await t.wait(0.5)
	await t.shot("panning_box_wash")
	var gone := grit.filter(func(o): return not is_instance_valid(o)).size()
	t.log_line("panning box mid-wash: caught %d, held %d, washed %d, nuggets %d | grit gone from the flume %d of 9 | dry box caught %d" % [wet.caught, wet.held, wet.washed, wet.nuggets, gone, dry.caught])
	await t.wait(7.0)
	var nug: Array = t.main.get_tree().get_nodes_in_group("ore").filter(func(o): return o.has_meta("nugget"))
	var nx: Array = nug.map(func(o): return "(%d,%d)" % [int(o.global_position.x), int(o.global_position.y)])
	var ix: Array = iron.map(func(o): return int(o.global_position.x) if is_instance_valid(o) else -1)
	var dleft := dgrit.filter(func(o): return is_instance_valid(o)).size()
	t.log_line("panning box: caught %d, washed %d, held %d, nuggets out %d (expect 3) | nuggets at %s (weir at x 1470) | flume floated over %d, flushed %d | iron at x %s (should wait behind the weir) | dry box caught %d, its grit still loose %d of 3" % [wet.caught, wet.washed, wet.held, wet.nuggets, nx, f.floated, f.flushed, ix, dry.caught, dleft])
	await t.shot("panning_box_done")
